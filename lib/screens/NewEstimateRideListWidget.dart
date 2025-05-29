import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:taxibooking/components/ModalitySelector.dart';
import 'package:taxibooking/screens/ReviewScreen.dart';
import 'package:taxibooking/utils/Extensions/StringExtensions.dart';

import '../../components/RideAcceptWidget.dart';
import '../../components/CancellationDialogWidget.dart';
import '../../main.dart';
import '../../network/RestApis.dart';
import '../../utils/Colors.dart';
import '../../utils/Common.dart';
import '../../utils/Constants.dart';
import '../../utils/Extensions/AppButtonWidget.dart';
import '../../utils/Extensions/app_common.dart';
import '../../utils/Extensions/app_textfield.dart';
import '../components/BookingWidget.dart';
import '../components/CarDetailWidget.dart';
import '../model/CurrentRequestModel.dart';
import '../model/EstimatePriceModel.dart';
import '../utils/images.dart';
import 'RiderDashBoardScreen.dart';

class NewEstimateRideListWidget extends StatefulWidget {
  final LatLng sourceLatLog;
  final LatLng destinationLatLog;
  final String sourceTitle;
  final String destinationTitle;
  bool isCurrentRequest;
  final int? servicesId;
  final int? id;

  NewEstimateRideListWidget({
    required this.sourceLatLog,
    required this.destinationLatLog,
    required this.sourceTitle,
    required this.destinationTitle,
    this.isCurrentRequest = false,
    this.servicesId,
    this.id,
  });

  @override
  NewEstimateRideListWidgetState createState() => NewEstimateRideListWidgetState();
}

class NewEstimateRideListWidgetState extends State<NewEstimateRideListWidget> {
  Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  late PolylinePoints polylinePoints;
  late Marker sourceMarker;
  late Marker destinationMarker;

  late LatLng userLatLong;

  TextEditingController promoCode = TextEditingController();
  bool isBooking = false;
  late DateTime scheduleData;
  List<ServicesListData> serviceList = [];

  int selectedIndex = 0;
  int rideRequestId = 0;

  List<String> cashList = ['wallet'];
  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor driverIcon;

  LatLng? driverLatitudeLocation;

  String paymentMethodType = 'wallet';
  String modality = '';

  ServicesListData? servicesListData;
  OnRideRequest? rideRequest;
  Driver? driverData;
  Timer? timer;

  TextEditingController proposedFeeController = TextEditingController();
  TextEditingController cashInHandController = TextEditingController();

  List rideRequests = [];
  bool isBottomSheetOpen = false;

  bool serviceTypeConfirmed = false;
  bool isPaymentTypeConfirmed = false;

  List<Map<String, String>> paymentMethods = [
    {'key': 'wallet', 'name': 'Billetera'},
    // {'key': 'cash', 'name': 'Efectivo'},
    // {'key': 'mobile-payment', 'name': 'Pago Móvil al Conductor'}
  ];

  int _currentStep = 0;

  List<String> _stepTitles = [
    "Tipo de Servicio",
    "Modalidad",
    language.paymentMethod,
  ];

  List<dynamic> _cancellationReasons = [];
  int? _selectedReasonId = 0;

  double? driverMarkerRotation;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    getServiceList();
    getCurrentRequest();
    mqttForUser();
    if (!widget.isCurrentRequest) getNewService();
    isBooking = widget.isCurrentRequest;
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) {
      rideRequest = value.rideRequest ?? value.onRideRequest;
      driverData = value.driver!;
      if (rideRequest != null) {
        //getUserDetailLocation();
        setState(() {});
        if (driverData != null) {
          timer = Timer.periodic(Duration(seconds: 10), (Timer t) => getUserDetailLocation());
        }
      }
      if (rideRequest!.status == COMPLETED && rideRequest != null && driverData != null) {
        launchScreen(context, ReviewScreen(rideRequest: rideRequest!, driverData: driverData),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
      }
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> getServiceList() async {
    markers.clear();
    polylinePoints = PolylinePoints();
    // setPolyLines(
    //   sourceLocation: LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
    //   destinationLocation: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
    //   driverLocation: driverLatitudeLocation,
    // );
    MarkerId id = MarkerId('Source');
    markers.add(
      Marker(
        markerId: id,
        position: LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
        infoWindow: InfoWindow(title: widget.sourceTitle),
        icon: sourceIcon,
      ),
    );
    MarkerId id2 = MarkerId('DriverLocation');
    markers.remove(id2);

    MarkerId id3 = MarkerId('Destination');
    markers.remove(id3);
    rideRequest != null && (rideRequest!.status == ACCEPTED || rideRequest!.status == ARRIVING || rideRequest!.status == ARRIVED)
        ? markers.add(
            Marker(
              markerId: id2,
              position: driverLatitudeLocation!,
              icon: driverIcon,
            ),
          )
        : markers.add(
            Marker(
              markerId: id3,
              position: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
              infoWindow: InfoWindow(title: widget.destinationTitle),
              icon: destinationIcon,
            ),
          );
    setState(() {});
  }

  Future<void> getNewService({bool coupon = false}) async {
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      if (coupon) "coupon_code": promoCode.text.trim(),
    };
    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();

      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) servicesListData = serviceList[0];
      if (serviceList.isNotEmpty) paymentMethodType = serviceList[0].paymentMethod!;
      if (serviceList.isNotEmpty)
        cashList =
            paymentMethodType == 'cash_wallet' ? cashList = ['cash', 'wallet', 'mobile-payment'] : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) proposedFeeController.text = serviceList[0].totalAmount!.toStringAsFixed(2);

      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> getCouponNewService() async {
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      "coupon_code": promoCode.text.trim(),
      "service_id": servicesListData!.id.toString(),
    };
    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) servicesListData = serviceList[selectedIndex];
      if (serviceList.isNotEmpty)
        cashList =
            paymentMethodType == 'cash_wallet' ? cashList = ['cash', 'wallet', 'mobile-payment'] : cashList = [paymentMethodType];
      setState(() {});
      Navigator.pop(context);
    }).catchError((error) {
      promoCode.clear();
      Navigator.pop(context);

      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> setPolyLines({required LatLng sourceLocation, required LatLng destinationLocation, LatLng? driverLocation}) async {
    _polyLines.clear();
    polylineCoordinates.clear();
    var result = await polylinePoints.getRouteBetweenCoordinates(
      googleMapAPIKey,
      PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
      rideRequest != null &&
              (rideRequest!.status == ACCEPTED || rideRequest!.status == ARRIVING || rideRequest!.status == ARRIVED)
          ? PointLatLng(driverLocation!.latitude, driverLocation.longitude)
          : PointLatLng(destinationLocation.latitude, destinationLocation.longitude),
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((element) {
        polylineCoordinates.add(LatLng(element.latitude, element.longitude));
      });
      _polyLines.add(Polyline(
        visible: true,
        width: 5,
        polylineId: PolylineId('poly'),
        color: Color.fromARGB(255, 40, 122, 198),
        points: polylineCoordinates,
      ));
      setState(() {});
    }
  }

  onMapCreated(GoogleMapController controller) async {
    String _darkMapStyle =
        await rootBundle.loadString('assets/json/dark_mode_style.json');
    controller.setMapStyle(_darkMapStyle);
    _controller.complete(controller);
    // _googleMapController = controller;
  }

  Future<void> saveBookingData() async {
    appStore.setLoading(true);
    Map req = {
      "rider_id": sharedPref.getInt(USER_ID).toString(),
      "service_id": servicesListData!.id.toString(),
      "datetime": DateTime.now().toString(),
      "start_latitude": widget.sourceLatLog.latitude.toString(),
      "start_longitude": widget.sourceLatLog.longitude.toString(),
      "start_address": widget.sourceTitle,
      "end_latitude": widget.destinationLatLog.latitude.toString(),
      "end_longitude": widget.destinationLatLog.longitude.toString(),
      "end_address": widget.destinationTitle,
      "seat_count": servicesListData!.capacity.toString(),
      "status": NEW_RIDE_REQUESTED,
      "payment_type": paymentMethodType = paymentMethodType == 'cash_wallet' ? 'cash' : paymentMethodType,
      if (promoCode.text.isNotEmpty) "coupon_code": promoCode.text,
      "is_schedule": 0,
      "proposed_fee": proposedFeeController.text,
      "cash_in_hand": cashInHandController.text,
      "modality": appStore.selectedRideModality,
    };

    log('$req');
    await saveRideRequest(req).then((value) async {
      rideRequestId = value.rideRequestId!;
      widget.isCurrentRequest = true;
      isBooking = true;
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  mqttForUser() async {
    client.setProtocolV311();
    client.logging(on: true);
    client.keepAlivePeriod = 120;
    client.autoReconnect = true;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint(e.toString());
      client.connect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.onSubscribed = onSubscribed;

      debugPrint('connected');
    } else {
      client.connect();
    }

    void onconnected() {
      debugPrint('connected');
    }

    client.subscribe('ride_request_status_' + sharedPref.getInt(USER_ID).toString(), MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;

      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      if (jsonDecode(pt)['success_type'] == ACCEPTED ||
          jsonDecode(pt)['success_type'] == ARRIVING ||
          jsonDecode(pt)['success_type'] == ARRIVED ||
          jsonDecode(pt)['success_type'] == IN_PROGRESS) {
        isBooking = true;
        getCurrentRequest();
      } else if (jsonDecode(pt)['success_type'] == CANCELED) {
        launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
      } else if (jsonDecode(pt)['success_type'] == COMPLETED) {
        getCurrentRequest();
      } else if (jsonDecode(pt)['success_type'] == 'driver_offer') {
        setState(() {
          rideRequests.add(jsonDecode(pt)['result']);
        });
        playNotificationSound();
      } else if (jsonDecode(pt)['success_type'] == 'proposal_canceled') {
        setState(() {
          int requestIndex = rideRequests.indexWhere((element) => element['id'] == jsonDecode(pt)['result']['id']);
          rideRequests.removeAt(requestIndex);
        });
      }
    });

    client.onConnected = onconnected;
  }

  void onConnected() {
    log('Connected');
  }

  void onSubscribed(String topic) {
    log('Subscription confirmed for topic $topic');
  }

  Future<void> getUserDetailLocation() async {
    // getUserDetail(userId: driverData!.id).then((value) {
    //   driverLatitudeLocation = LatLng(double.parse(value.data!.latitude!), double.parse(value.data!.longitude!));
    //   getServiceList();
    // }).catchError((error) {
    //   log(error.toString());
    // });

    getUserDetail(userId: driverData!.id).then((value) async {
      LatLng newDriverLocation = LatLng(
        double.parse(value.data!.latitude!),
        double.parse(value.data!.longitude!),
      );

      if (driverLatitudeLocation != null) {
        await animateMarkerSmoothly(driverLatitudeLocation!, newDriverLocation, Duration(seconds: 10));
      } else {
        driverLatitudeLocation = newDriverLocation;
      }

      if (rideRequest!.status == ACCEPTED || rideRequest!.status == ARRIVING || rideRequest!.status == ARRIVED) {
        _centerMap(newDriverLocation, widget.sourceLatLog);
      } else {
        _centerMap(newDriverLocation, widget.destinationLatLog);
      }

      // centerMapBetweenDriverAndDestination(
      //     mapController: _googleMapController,
      //     driverLocation: driverLatitudeLocation!,
      //     destinationLocation: LatLng(
      //       widget.destinationLatLog.latitude,
      //       widget.destinationLatLog.longitude,
      //     ),
      //   );

      getServiceList();
    }).catchError((error) {
      log(error.toString());
    });

  }

  Future<void> cancelRequest({bool goToRiderDashboardScreen = true, int rejectedDriverId = 0}) async {
    Map req = {
      "id": rideRequestId == 0 ? widget.id : rideRequestId,
      "cancel_by": 'rider',
      "status": CANCELED,
    };

    if (rejectedDriverId != 0) {
      req['driver_id'] = rejectedDriverId;
      req['status'] = 'rejected-by-rider';
    }

    if (_selectedReasonId != null) {
      req['cancellation_reason_id'] = _selectedReasonId;
    }

    await rideRequestUpdate(request: req, rideId: rideRequestId == 0 ? widget.id : rideRequestId).then((value) async {
      if (goToRiderDashboardScreen) {
        launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
      }

      toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> acceptRequest(num requestId, num driverId) async {
    Map req = {
      "id": requestId,
      "driver_id": driverId,
      // "cancel_by": 'rider',
      "status": ACCEPTED,
    };
    await rideRequestUpdate(request: req, rideId: rideRequestId == 0 ? widget.id : rideRequestId).then((value) async {
      // toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  @override
  void dispose() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) {
      polylineSource = LatLng(value.latitude, value.longitude);
    });
    if (timer != null) timer!.cancel();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: rideRequest?.status != 'in_progress' ? AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 50,
        leading: inkWellWidget(
          onTap: () {
            if (isBooking) {
              setState(() { 
              _cancellationReasons = appStore.cancellationReasons;
              });
              showDialog(
                    context: context,
                    builder: (_) {
                      return CancellationDialog(
                        reasons: _cancellationReasons,
                        onConfirm: (selectedReasonId) {
                          _selectedReasonId = selectedReasonId;
                          sharedPref.remove(REMAINING_TIME);
                          sharedPref.remove(IS_TIME);
                          cancelRequest();
                        },
                      );
                    },
                  );
              // showConfirmDialogCustom(context,
              //     primaryColor: primaryColor,
              //     title: language.areYouSureYouWantToCancelThisRide,
              //     dialogType: DialogType.CONFIRMATION, onAccept: (_) {
              //   sharedPref.remove(REMAINING_TIME);
              //   sharedPref.remove(IS_TIME);
              //   cancelRequest();
              // });
            } else {
              launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: 8),
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            child: Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ),
      ) : null,
      body: Column(
        // alignment: Alignment.bottomCenter,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: GoogleMap(
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: onMapCreated,
                initialCameraPosition: CameraPosition(target: widget.sourceLatLog, zoom: 11.0),
                markers: markers,
                mapType: MapType.normal,
                polylines: _polyLines,
              ),
            ),
          ),
          !isBooking
              ? Stack(
                  children: [
                    Visibility(
                      visible: serviceList.isNotEmpty,
                      child: Container(
                        //color: Colors.white,
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Center(
                                child: Container(
                                  alignment: Alignment.center,
                                  margin: EdgeInsets.only(bottom: 16, top: 16),
                                  height: 5,
                                  width: 70,
                                  decoration:
                                      BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                ),
                              ),


                              Stepper(
                                margin: EdgeInsets.all(10),

                                connectorThickness: 0,

                                controlsBuilder: (context, details) {
                                  return Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Row(
                                      children: <Widget>[
                                        if(_currentStep!=2)
                                        AppButtonWidget(text: language.continueD, onTap: details.onStepContinue, color: primaryColor, textStyle: boldTextStyle(color: Colors.white)),
                                        if(_currentStep>0)
                                        TextButton(
                                          onPressed: details.onStepCancel,
                                          child: Text("Regresar"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                
                                steps: [

                                Step(
                                    isActive: _currentStep == 0,
                                    title: Text(_stepTitles[0], style: TextStyle(color: primaryColor),),
                                    content:
                                        Column(
                                    children: serviceList
                                      .where((e) => e.name != 'Moto Taxi Bqto')
                                      .map((e) {
                                      return GestureDetector(
                                        onTap: () {
                                          selectedIndex = serviceList.indexOf(e);
                                          servicesListData = e;
                                          paymentMethodType = e.paymentMethod!;
                                          cashList = paymentMethodType == 'cash_wallet'
                                              ? cashList = ['cash', 'wallet', 'mobile-payment']
                                              : cashList = [paymentMethodType];
                                          proposedFeeController.text = e.totalAmount!.toStringAsFixed(2);
                                          setState(() {});
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          margin: EdgeInsets.only(top: 16, left: 8, right: 8),
                                          decoration: BoxDecoration(
                                            color: selectedIndex == serviceList.indexOf(e) ? primaryColor : Colors.white,
                                            border: Border.all(color: primaryColor.withOpacity(0.5)),
                                            borderRadius: BorderRadius.circular(defaultRadius),
                                          ),
                                          child: Row(
                                            children: [
                                              commonCachedNetworkImage(e.serviceImage.validate(),
                                                      height: 50, width: 100, fit: BoxFit.cover, alignment: Alignment.center),
                                              SizedBox(width: 10),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(height: 8),
                                                  Text(e.name.validate(),
                                                      style: boldTextStyle(
                                                          color:
                                                              selectedIndex == serviceList.indexOf(e) ? Colors.white : primaryColor)),
                                                  Divider(color: Colors.grey, height: 8),
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(language.capacity,
                                                          style: secondaryTextStyle(
                                                              color: selectedIndex == serviceList.indexOf(e)
                                                                  ? Colors.white
                                                                  : primaryColor)),
                                                      SizedBox(width: 8),
                                                      Text(e.capacity.toString(),
                                                          style: primaryTextStyle(
                                                              color: selectedIndex == serviceList.indexOf(e)
                                                                  ? Colors.white
                                                                  : primaryColor)),
                                                    ],
                                                  ),
                                                  SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        toCurrency(e.totalAmount!),
                                                        style: boldTextStyle(
                                                          color: selectedIndex == serviceList.indexOf(e) ? Colors.white : primaryColor,
                                                          textDecoration: e.discountAmount != 0 ? TextDecoration.lineThrough : null,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      inkWellWidget(
                                                        onTap: () {
                                                          showModalBottomSheet(
                                                            backgroundColor: primaryColor,
                                                            context: context,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.only(
                                                                    topRight: Radius.circular(defaultRadius),
                                                                    topLeft: Radius.circular(defaultRadius))),
                                                            builder: (_) {
                                                              return CarDetailWidget(service: e);
                                                            },
                                                          );
                                                        },
                                                        child: Icon(Icons.info_outline_rounded,
                                                            size: 20,
                                                            color:
                                                                selectedIndex == serviceList.indexOf(e) ? Colors.white : primaryColor),
                                                      ),
                                                    ],
                                                  ),
                                                  if (e.discountAmount != 0) SizedBox(height: 8),
                                                  if (e.discountAmount != 0)
                                                    Text(
                                                      toCurrency(e.discountAmount!),
                                                      style: boldTextStyle(
                                                        color: selectedIndex == serviceList.indexOf(e) ? Colors.white : primaryColor,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                  ),
                                
                                Step(
                                    isActive: _currentStep == 1,
                                    title: Text(_stepTitles[1], style: TextStyle(color: primaryColor)),
                                    content: Padding(
                                      padding: EdgeInsets.only(
                                          left: 0,
                                          right: 0,
                                          bottom: MediaQuery.of(context)
                                              .viewInsets
                                              .bottom),
                                      child: Row(
                                        children: [
                                          // Expanded(
                                          //   flex: 3,
                                          //   child: AppButtonWidget(
                                          //     color: primaryColor,
                                          //     onTap: () {
                                          //       serviceTypeConfirmed = true;
                                          //       setState(() {});
                                          //     },
                                          //     text: language.continueD,
                                          //     textStyle: boldTextStyle(
                                          //         color: Colors.white),
                                          //     width: MediaQuery.of(context)
                                          //         .size
                                          //         .width,
                                          //   ),
                                          // ),

                                          Expanded(
                                            child: ModalitySelectorWidget(
                                              onSelectParam: (value) => {
                                                modality = value,
                                                setState(() {})
                                              },
                                            ),
                                          ),

                                          ],
                                      ),
                                    )),
                                
                                Step(
                                    isActive: _currentStep == 2,
                                    title: Text(_stepTitles[2], style: TextStyle(color: primaryColor)),
                                    content: inkWellWidget(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) {
                                        return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                                          return Observer(builder: (context) {
                                            return Stack(
                                              children: [
                                                AlertDialog(
                                                  contentPadding: EdgeInsets.all(16),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(language.paymentMethod, style: boldTextStyle()),
                                                          inkWellWidget(
                                                            onTap: () {
                                                              Navigator.pop(context);
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets.all(8),
                                                              decoration:
                                                                  BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                                              child: Icon(Icons.close, color: Colors.white, size: 20),
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(language.chooseYouPaymentLate, style: secondaryTextStyle()),
                                                      SizedBox(height: 16),
                                                      Column(
                                                        children: paymentMethods.map((method) {
                                                          return RadioListTile<String>(
                                                            value: method['key']!,
                                                            groupValue: paymentMethodType,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                paymentMethodType = val!;
                                                              });
                                                            },
                                                            title: Text(method['name']!, style: boldTextStyle(size: 18)),
                                                            activeColor: primaryColor,
                                                          );
                                                        }).toList(),
                                                      ),
                                                      SizedBox(height: 16),
                                                      AppButtonWidget(
                                                        width: MediaQuery.of(context).size.width,
                                                        text: language.confirm,
                                                        textStyle: boldTextStyle(color: Colors.white),
                                                        color: primaryColor,
                                                        onTap: () {
                                                          Navigator.pop(context);
                                                        },
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Visibility(
                                                  visible: appStore.isLoading,
                                                  child: Observer(builder: (context) {
                                                    return loaderWidget();
                                                  }),
                                                ),
                                              ],
                                            );
                                          });
                                        });
                                      },
                                    ).then((value) {
                                      setState(() {});
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.all(16),
                                        decoration:
                                            BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(defaultRadius), color: Colors.white),
                                        padding: EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(language.paymentVia, style: secondaryTextStyle()),
                                                SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                          color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                                      child: Icon(Icons.wallet_outlined, size: 20, color: Colors.white),
                                                    ),
                                                    SizedBox(width: 16),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                            getPaymentMethodNameByKey(paymentMethodType),
                                                            style: boldTextStyle()),
                                                        SizedBox(height: 4),
                                                        Text(language.forInstantPayment, style: secondaryTextStyle(size: 12)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            // SizedBox(width: 16),
                                          ],
                                        ),
                                      ),


                                      Container(
                                        margin: EdgeInsets.all(16),
                                        decoration:
                                              BoxDecoration(borderRadius: BorderRadius.circular(defaultRadius), color: Colors.white),
                                        child: Column(
                                          children: [

                                                                                // cash
                                  // if (paymentMethodType == 'cash_wallet' || paymentMethodType == 'cash')
                                  //   Padding(
                                  //     padding: EdgeInsets.only(left: 16, right: 16, top: 16),
                                  //     child: Column(
                                  //       children: [
                                  //         AppTextField(
                                  //           controller: cashInHandController,
                                  //           autoFocus: false,
                                  //           textFieldType: TextFieldType.PHONE,
                                  //           keyboardType: TextInputType.number,
                                  //           errorThisFieldRequired: errorThisFieldRequired,
                                  //           decoration: inputDecoration(context, label: 'Efectivo en mano*'),
                                  //         )
                                  //       ],
                                  //     ),
                                  //   ),

                                  //
                                  SizedBox(height: 16),

                                  // proposal fee
                                  Observer(builder: (_) =>
                                  Visibility( 
                                    visible: appStore.selectedRideModality == 'auction',
                                    child:
                                    Padding(
                                      padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                      child: Column(
                                        children: [
                                          Text("Propón tu tarifa", style: secondaryTextStyle()),
                                          SizedBox(height: 2),
                                          if (servicesListData != null && servicesListData!.totalAmount != null)
                                            Text("Sugerido: " + toCurrency(double.parse(servicesListData!.totalAmount.toString())),
                                                style: secondaryTextStyle()),
                                          SizedBox(height: 16),
                                          AppTextField(
                                            controller: proposedFeeController,
                                            // focus: emailFocus,
                                            // nextFocus: phoneFocus,
                                            autoFocus: false,
                                            textFieldType: TextFieldType.PHONE,
                                            keyboardType: TextInputType.number,
                                            errorThisFieldRequired: errorThisFieldRequired,
                                            decoration: inputDecoration(context, label: 'Tarifa propuesta*'),
                                          )
                                        ],
                                      ),
                                    ),
                                  )),
                                  //

                                        ]),
                                      ),


                              
                                  SizedBox(height: 16),

                                  Observer(builder: (_) =>


                                  Padding(
                                    padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom),
                                    child: AppButtonWidget(
                                      color: primaryColor,
                                      onTap: () {
                                        bool isCash = ['cash_wallet', 'cash'].contains(paymentMethodType);
                                  
                                        if (proposedFeeController.text.isNotEmpty &&
                                            ((isCash && cashInHandController.text.isNotEmpty) || !isCash)) {
                                          saveBookingData();
                                        } else {
                                          toast('Rellena todos los campos requeridos');
                                        }
                                      },
                                      text: language.bookNow,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      width: MediaQuery.of(context).size.width,
                                    ),
                                  )),
                                    ],
                                  ),
                                )),
                              ],
                              type: StepperType.vertical,
                              onStepContinue: () {
                                if (_currentStep != 2) {
                                  setState(() {

                                    switch (_currentStep) {
                                        case 0:
                                          _stepTitles[0] = servicesListData!.name!;
                                          break;
                                        case 1:
                                         _stepTitles[1] = "Express";
                                          break;
                                        default:
                                      }
                                    // if (_currentStep == 0) {
                                    //   _stepTitles[0] = servicesListData!.name!;
                                    // }
                                    _currentStep += 1;
                                  });
                                }
                              },
                              onStepCancel: () {
                                if (_currentStep != 0) {
                                  setState(() {
                                    _currentStep -= 1;
                                  });
                                }
                              },
                              // onStepTapped: (value) => {

                              // },
                              currentStep: _currentStep,
                              ),

                              // Observer(builder: (_) =>
                              // Padding(
                              // padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom),
                              // child: Row(
                              //   children: [
                              //     Expanded(
                              //       flex: 3,
                              //       child: AppButtonWidget(
                              //         color: primaryColor,
                              //         onTap: () {
                              //           bool isCash = ['cash_wallet', 'cash'].contains(paymentMethodType);

                              //           if (proposedFeeController.text.isNotEmpty &&
                              //               ((isCash && cashInHandController.text.isNotEmpty) || !isCash)) {
                              //             saveBookingData();
                              //           } else {
                              //             toast('Rellena todos los campos requeridos');
                              //           }
                              //         },
                              //         text: language.bookNow,
                              //         textStyle: boldTextStyle(color: Colors.white),
                              //         width: MediaQuery.of(context).size.width,
                              //       ),
                              //     ),
                              //   ],
                              // ),
                              // )                          

                              // ),

                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: appStore.isLoading,
                      child: Observer(builder: (context) {
                        return loaderWidget();
                      }),
                    ),
                    if (!appStore.isLoading && serviceList.isEmpty) emptyWidget()
                  ],
                )
              : Container(
                  color: Colors.white,
                  child: rideRequest != null
                      ? (rideRequest!.status == NEW_RIDE_REQUESTED || rideRequest!.status == 'drivers_offering')
                          ? BookingWidget(id: widget.id)
                          : RideAcceptWidget(rideRequest: rideRequest, driverData: driverData)
                      : BookingWidget(id: rideRequestId == 0 ? widget.id : rideRequestId, isLast: true),
                ),
          if (rideRequests.length > 0)
            SlidingUpPanel(
              padding: EdgeInsets.all(8),
              panel: Column(children: [
                SizedBox(
                  height: 60,
                ),
                for (var request in rideRequests.asMap().entries)
                  Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(defaultRadius),
                                child: commonCachedNetworkImage(request.value['driver_profile_image'],
                                    height: 35, width: 35, fit: BoxFit.cover),
                              ),

                              SizedBox(
                                width: 4,
                              ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(request.value['driver_name']),
                                  Text(
                                    toCurrency(request.value['counteroffer']),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // ListTile(
                              //   leading: commonCachedNetworkImage(request['driver_profile_image']),
                              //   title: Text(request['driver_name']),
                              //   subtitle: Text(toCurrency(request['counteroffer'])),
                              // ),
                              ButtonBar(
                                children: <Widget>[
                                  TextButton(
                                    child: Text(
                                      'RECHAZAR',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    // style: ButtonStyle(colo),
                                    onPressed: () {
                                      if (isBooking) {
                                        // rideRequestId = request.value['id'];

                                        setState(() {
                                          rideRequests.removeAt(request.key);
                                          rideRequestId = request.value['id'];
                                          // rideRequests.removeWhere((element) => element['id'] == request.value['id']);
                                        });

                                        cancelRequest(
                                            goToRiderDashboardScreen: false, rejectedDriverId: request.value['driver_id']);
                                      }
                                    },
                                  ),
                                  TextButton(
                                    child: Text(
                                      'ACEPTAR',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    onPressed: () async {
                                      if (isBooking) {
                                        rideRequests.removeAt(request.key);
                                        // await rejectAllExcept(request.value['id']);
                                        acceptRequest(request.value['id'], request.value['driver_id']);
                                        setState(() {
                                          rideRequests.clear();
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // LinearProgressIndicator(
                        //   value: 0.5,
                        //   backgroundColor: Colors.grey,
                        //   valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        // ),
                      ],
                    ),
                  )
              ]),
              color: Colors.transparent,
              minHeight: 700,
              maxHeight: 700,

              boxShadow: [],
              slideDirection: SlideDirection.DOWN,

              // backdropColor: Colors.transparent,
              // backdropEnabled: true,
            )
        ],
      ),
    );
  }

  // String toCurrency(num amount) {
  //   return appStore.currencyPosition == LEFT
  //       ? '${appStore.currencyCode} ${amount.toStringAsFixed(fixedDecimal)}'
  //       : '${amount.toStringAsFixed(fixedDecimal)} ${appStore.currencyCode}';
  // }

  Future<void> rejectAllExcept(int requestId) async {
    // rideRequests.removeWhere((element) => element['id'] == requestId);

    rideRequests.forEach((element) async {
      await cancelRequest(goToRiderDashboardScreen: false, rejectedDriverId: element['driver_id']);
    });
  }

  _renderShowModal(List newData) {
    setState(() {
      isBottomSheetOpen = true;
    });

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          setState(() => {});
          return Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var request in rideRequests)
                  Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: commonCachedNetworkImage(request['driver_profile_image']),
                          title: Text(request['driver_name']),
                          subtitle: Text(toCurrency(request['counteroffer'])),
                        ),
                        ButtonBar(
                          children: <Widget>[
                            TextButton(
                              child: Text(
                                'RECHAZAR',
                                style: TextStyle(color: Colors.red),
                              ),
                              // style: ButtonStyle(colo),
                              onPressed: () {
                                if (isBooking) {
                                  rideRequestId = request['id'];
                                  cancelRequest(goToRiderDashboardScreen: false);

                                  setState(() {
                                    rideRequests.removeWhere((element) => element['id'] == request['id']);
                                  });

                                  if (rideRequests.length == 0) {
                                    Navigator.pop(context);
                                  }
                                }
                              },
                            ),
                            TextButton(
                              child: Text(
                                'ACEPTAR',
                                style: TextStyle(color: Colors.green),
                              ),
                              onPressed: () {
                                if (isBooking) {
                                  acceptRequest(request['id'], request['driver_id']);
                                  setState(() {
                                    rideRequests.clear();
                                  });
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  String getPaymentMethodNameByKey(String key) {
    Map paymentMethod = paymentMethods.firstWhere(
      (payment) => payment['key'] == key,
      orElse: () => {'key': ''},
    );
    String name = '';

    if (paymentMethod['key'] != '') {
      name = paymentMethod['name'];
    }

    return name;
  }

  void _updateFeeProposalTimer() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      
    });
  }

  LatLng interpolate(LatLng start, LatLng end, double fraction) {
    double lat = start.latitude + (end.latitude - start.latitude) * fraction;
    double lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  Future<void> animateMarkerTo(LatLng start, LatLng end, Duration duration) async {
    int steps = 20; // Número de pasos para interpolar
    Duration stepDuration = duration ~/ steps;

    for (int i = 0; i <= steps; i++) {
      double fraction = i / steps;
      LatLng interpolatedPosition = interpolate(start, end, fraction);

      // Actualiza la posición del marcador en el mapa
      setState(() {
        driverLatitudeLocation = interpolatedPosition;
        MarkerId id2 = MarkerId('DriverLocation');
        markers.remove(id2);
        markers.add(
          Marker(
            markerId: id2,
            position: interpolatedPosition,
            icon: driverIcon,
          ),
        );
      });

      await Future.delayed(stepDuration);
    }
  }

  double calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * pi / 180;
    double startLng = start.longitude * pi / 180;
    double endLat = end.latitude * pi / 180;
    double endLng = end.longitude * pi / 180;

    double dLng = endLng - startLng;

    double x = sin(dLng) * cos(endLat);
    double y = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);

    double bearing = atan2(x, y) * 180 / pi;
    return (bearing + 360) % 360; // Asegura un ángulo entre 0 y 360
  }

  double easeOut(double t) {
    return t * t; // La velocidad aumenta conforme avanza la fracción
  }

  double shortestAngle(double start, double end) {
    double delta = (end - start + 360) % 360;
    return delta > 180 ? delta - 360 : delta;
  }

  Future<void> animateMarkerSmoothly(LatLng start, LatLng end, Duration duration) async {
    final int frameRate = 60; // 60 FPS
    final int totalFrames = (duration.inMilliseconds / (1000 / frameRate)).round();
    final Duration frameDuration = Duration(milliseconds: (300 / frameRate).round());

    double startBearing = driverMarkerRotation ?? 0; // Usa la última rotación, o 0 si no existe
    double endBearing = calculateBearing(start, end);

    for (int frame = 0; frame <= totalFrames; frame++) {
      double linearFraction = frame / totalFrames;
      double easedFraction = easeOut(linearFraction); // Aplica la función de interpolación

      LatLng interpolatedPosition = interpolate(start, end, easedFraction);

      // Calcula la rotación usando la fracción interpolada
      double deltaBearing = shortestAngle(startBearing, endBearing);
      double interpolatedRotation = startBearing + deltaBearing * easedFraction;

      // Actualiza la posición y rotación del marcador
      setState(() {
        driverLatitudeLocation = interpolatedPosition;
        driverMarkerRotation = interpolatedRotation;
        MarkerId id2 = MarkerId('DriverLocation');
        markers.remove(id2);
        markers.add(
          Marker(
            markerId: id2,
            position: interpolatedPosition,
            rotation: interpolatedRotation, // Aplica la rotación acelerada
            icon: driverIcon,
          ),
        );
      });

      await Future.delayed(frameDuration);
    }
  }

  // Future<void> centerMapBetweenDriverAndDestination({
  //   required GoogleMapController mapController,
  //   required LatLng driverLocation,
  //   required LatLng destinationLocation,
  //   }) async {
  //     // Calcula los límites (bounds) para incluir ambos puntos
  //     LatLngBounds bounds = LatLngBounds(
  //       southwest: LatLng(
  //         min(driverLocation.latitude, destinationLocation.latitude),
  //         min(driverLocation.longitude, destinationLocation.longitude),
  //       ),
  //       northeast: LatLng(
  //         max(driverLocation.latitude, destinationLocation.latitude),
  //         max(driverLocation.longitude, destinationLocation.longitude),
  //       ),
  //     );

  //     // Ajusta la cámara para centrar el mapa en los límites con un padding adicional
  //     CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100); // Padding de 100px
  //     await mapController.animateCamera(cameraUpdate);
  //   }

    Future<void> _centerMap(LatLng driverLocation, LatLng destinationLocation) async {
      final GoogleMapController controller = await _controller.future;
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(driverLocation.latitude, destinationLocation.latitude),
          min(driverLocation.longitude, destinationLocation.longitude),
        ),
        northeast: LatLng(
          max(driverLocation.latitude, destinationLocation.latitude),
          max(driverLocation.longitude, destinationLocation.longitude),
        ),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
    
}
