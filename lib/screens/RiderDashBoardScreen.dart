import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:taxibooking/model/NearByDriverListModel.dart';
import 'package:taxibooking/screens/ReviewScreen.dart';
import 'package:taxibooking/utils/Extensions/StringExtensions.dart';

import '../components/DrawerWidget.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/TextModel.dart';
import '../network/RestApis.dart';
import '../screens/EmergencyContactScreen.dart';
import '../screens/MyRidesScreen.dart';
import '../screens/MyWalletScreen.dart';
import '../screens/OrderDetailScreen.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/DataProvider.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/LiveStream.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import '../utils/images.dart';
import 'EditProfileScreen.dart';
import 'LocationPermissionScreen.dart';
import 'NewEstimateRideListWidget.dart';
import 'NotificationScreen.dart';
import 'RiderWidget.dart';
import 'SettingScreen.dart';

class RiderDashBoardScreen extends StatefulWidget {
  @override
  RiderDashBoardScreenState createState() => RiderDashBoardScreenState();
}

class RiderDashBoardScreenState extends State<RiderDashBoardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  LatLng? sourceLocation;

  List<TexIModel> list = getBookList();

  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  late PolylinePoints polylinePoints;
  OnRideRequest? servicesListData;

  double cameraZoom = 14;
  double cameraTilt = 0;
  double cameraBearing = 30;
  int onTapIndex = 0;

  int selectIndex = 0;
  String sourceLocationTitle = '';

  late StreamSubscription<ServiceStatus> serviceStatusStream;
  late BitmapDescriptor driverIcon;
  List<NearByDriverListModel>? nearDriverModel;

  LocationPermission? permissionData;

  late BitmapDescriptor riderIcon;

  Completer<GoogleMapController> _controller = Completer();
  String _darkMapStyle = '';

  double? usdRate;
  String bottomBannerUrl = '';

  @override
  void initState() {
    super.initState();
    locationPermission();
    afterBuildCreated(() {
      init();
      getCurrentRequest();
    });
  }

  void init() async {
    getCurrentUserLocation();
    riderIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    driverIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), MultipleDriver);

    await getAppSetting().then((value) {
      if (value.walletSetting!.isNotEmpty) {
        appStore.setWalletPresetTopUpAmount(value.walletSetting!
                .firstWhere((element) => element.key == PRESENT_TOPUP_AMOUNT)
                .value ??
            '10|20|30');
        if (value.walletSetting!
                .firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD)
                .value !=
            null)
          appStore.setMinAmountToAdd(int.parse(value.walletSetting!
              .firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD)
              .value!));
        if (value.walletSetting!
                .firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD)
                .value !=
            null)
          appStore.setMaxAmountToAdd(int.parse(value.walletSetting!
              .firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD)
              .value!));
      }
      if (value.rideSetting!.isNotEmpty) {
        appStore.setWalletTipAmount(value.rideSetting!
                .firstWhere((element) => element.key == PRESENT_TIP_AMOUNT)
                .value ??
            '10|20|30');
        appStore.setRiderMinutes(value.rideSetting!
                .firstWhere(
                    (element) => element.key == MAX_TIME_FOR_RIDER_MINUTE)
                .value ??
            '4');

        appStore.setAuctionEnabled(false);
        appStore.setExpressEnabled(value.rideSetting!
                .firstWhere(
                    (element) => element.key == 'RIDE_MODALITY_EXPRESS')
                .value == '1');
      }
      if (value.currencySetting != null) {
        appStore
            .setCurrencyCode(value.currencySetting!.symbol ?? currencySymbol);
        appStore
            .setCurrencyName(value.currencySetting!.code ?? currencyNameConst);
        appStore.setCurrencyPosition(value.currencySetting!.position ?? LEFT);
      }
      appStore.setEnabledReferrals(value.referralsEnabled ?? false);
      appStore.setExchangeRate(value.usdRate ?? 0.0);
      appStore.setCancellationReasons(value.cancellationReasons!);
      
      setState(() {
        usdRate = appStore.exchangeRate?.toDouble();
      });

    }).catchError((error) {
      log('${error.toString()}');
    });
    // getCurrentUserLocation();
    loadBanners();
    polylinePoints = PolylinePoints();
  }

  Future<void> getCurrentUserLocation() async {
    if (permissionData != LocationPermission.denied) {
      final geoPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .catchError((error) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LocationPermissionScreen()));
      });
      sourceLocation = LatLng(geoPosition.latitude, geoPosition.longitude);
      List<Placemark>? placemarks = await placemarkFromCoordinates(
          geoPosition.latitude, geoPosition.longitude);
      sharedPref.setString(COUNTRY,
          placemarks[0].isoCountryCode.validate(value: defaultCountry));

      Placemark place = placemarks[0];
      sourceLocationTitle =
          "${place.name != null ? place.name : place.subThoroughfare}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}, ${place.country}";
      polylineSource = LatLng(geoPosition.latitude, geoPosition.longitude);
          markers.add(
        Marker(
          markerId: MarkerId('Order Detail'),
          position: sourceLocation!,
          draggable: true,
          infoWindow: InfoWindow(title: sourceLocationTitle, snippet: ''),
          icon: riderIcon,
        ),
      );
      startLocationTracking();
      getNearByDriverList(latLng: sourceLocation).then((value) async {
        value.data!.forEach((element) {
          log('[NEARDRIVER] ${element.id} lat: ${element.latitude} lng ${element.longitude}');
          markers.add(
            Marker(
              markerId: MarkerId('Driver${element.id}'),
              position: LatLng(double.parse(element.latitude!.toString()),
                  double.parse(element.longitude!.toString())),
              infoWindow: InfoWindow(
                  title: '${element.firstName} ${element.lastName}',
                  snippet: ''),
              icon: driverIcon,
            ),
          );
        });
        setState(() {});
      });
      setState(() {});
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => LocationPermissionScreen()));
    }
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) {
      servicesListData = value.rideRequest ?? value.onRideRequest;
      if (servicesListData != null) {
        if (servicesListData!.status != COMPLETED &&
            servicesListData!.status != 'drivers_offering') {
          launchScreen(
            context,
            isNewTask: true,
            NewEstimateRideListWidget(
              sourceLatLog: LatLng(
                  double.parse(servicesListData!.startLatitude!),
                  double.parse(servicesListData!.startLongitude!)),
              destinationLatLog: LatLng(
                  double.parse(servicesListData!.endLatitude!),
                  double.parse(servicesListData!.endLongitude!)),
              sourceTitle: servicesListData!.startAddress!,
              destinationTitle: servicesListData!.endAddress!,
              isCurrentRequest: true,
              servicesId: servicesListData!.serviceId,
              id: servicesListData!.id,
            ),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
          );
        } else if (servicesListData!.status == COMPLETED &&
            servicesListData!.isRiderRated == 0) {
          launchScreen(
              context,
              ReviewScreen(
                  rideRequest: servicesListData!, driverData: value.driver),
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
              isNewTask: true);
        }
      } else if (value.payment != null &&
          value.payment!.paymentStatus != COMPLETED) {
        launchScreen(
            context, OrderDetailScreen(rideId: value.payment!.rideRequestId),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            isNewTask: true);
      }
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> locationPermission() async {
    serviceStatusStream =
        Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        launchScreen(navigatorKey.currentState!.overlay!.context,
            LocationPermissionScreen());
      } else if (status == ServiceStatus.enabled) {
        getCurrentUserLocation();

        if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
          Navigator.pop(navigatorKey.currentState!.overlay!.context);
        }
      }
    }, onError: (error) {
      //
    });
  }

  Future<void> startLocationTracking() async {
    Map req = {
      "status": "active",
      "latitude": sourceLocation!.latitude.toString(),
      "longitude": sourceLocation!.longitude.toString(),
    };

    await updateStatus(req).then((value) {
      //
    }).catchError((error) {
      log(error);
    });
  }

  void loadBanners() {

    List<dynamic> banners = [];
    List<dynamic> popupBanners = [];
    dynamic bottomBanner = [];

    getBanners().then((value) => {
          banners = value['data'],
          bottomBanner = banners.firstWhere(
              (element) => element['type'] == 'bottom',
              orElse: () => null),
          if (bottomBanner != null) {bottomBannerUrl = bottomBanner['image']},

          popupBanners =
              banners.where((element) => element['type'] == 'popup').toList(),

          Future.delayed(
              Duration(seconds: 3),
              (() => {
                    popupBanners.forEach((banner) => {
                          log('[banners] ${banner['image']}'),
                          showPopupBanner(banner['image'])
                        })
                  }))
        });
  }

  void showPopupBanner(String imgUrl) {
    BuildContext dialogContext;
    showDialog(
        context: context,
        barrierDismissible: true,
        // barrierColor: Colors.transparent,
        builder: (context) {
          dialogContext = context;
          return AlertDialog(
            contentPadding: EdgeInsets.all(0),
            backgroundColor: Colors.transparent,
            content: Container(
              child: commonCachedNetworkImage(imgUrl.toString()),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => {Navigator.pop(dialogContext)},
                      child: Text('Cerrar')),
                  // MaterialButton(
                  //   child: Text('Cerrar'),
                  //   onPressed: () => {},
                  // )
                ],
              )
            ],
          );
        });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: primaryColor,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, top: 40, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                ),
                Container(
                  padding: EdgeInsets.only(top: 16, bottom: 16, right: 8),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(defaultRadius)),
                  child: Row(
                    children: [
                      Observer(builder: (context) {
                        return Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: commonCachedNetworkImage(
                                    appStore.userProfile.validate().validate(),
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            sharedPref.getString(LOGIN_TYPE) != 'mobile' &&
                                    sharedPref.getString(LOGIN_TYPE) != null
                                ? Text(sharedPref.getString(USER_NAME).validate(),
                                    style: boldTextStyle(color: Colors.white))
                                : Text(
                                    sharedPref.getString(FIRST_NAME).validate(),
                                    style: boldTextStyle(color: Colors.white)),
                            SizedBox(height: 4),
                            Text(appStore.userEmail,
                                style: secondaryTextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                DrawerWidget(
                  title: language.myProfile,
                  iconData: 'images/ic_my_profile.png',
                  onTap: () {
                    Navigator.pop(context);
                    launchScreen(context, EditProfileScreen(),
                        pageRouteAnimation: PageRouteAnimation.Slide);
                  },
                ),
                DrawerWidget(
                    title: language.myRides,
                    iconData: 'images/ic_my_rides.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyRidesScreen(),
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.myWallet,
                    iconData: 'images/my_wallet.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyWalletScreen(),
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.emergencyContacts,
                    iconData: 'images/ic_emergency_contact.png',
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EmergencyContactScreen(),
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.setting,
                    iconData: 'images/ic_setting.png',
                    onTap: () {
                      launchScreen(context, SettingScreen(),
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                SizedBox(height: 16),
                Center(
                  child: AppButtonWidget(
                    text: language.logOut,
                    textStyle: boldTextStyle(color: primaryColor),
                    onTap: () async {
                      await showConfirmDialogCustom(
                          _scaffoldKey.currentState!.context,
                          primaryColor: primaryColor,
                          dialogType: DialogType.CONFIRMATION,
                          title: language.areYouSureYouWantToLogoutThisApp,
                          positiveText: language.yes,
                          negativeText: language.no, onAccept: (v) async {
                        await appStore.setLoggedIn(true);
                        await Future.delayed(Duration(milliseconds: 500));
                        await logout();
                      });
                    },
                  ),
                )
              ],
            ),
          ),
        ),
        body: sourceLocation != null
            ? Stack(
                children: [
                  GoogleMap(
                    zoomControlsEnabled: true,
                    markers: markers,
                    polylines: _polyLines,
                    padding: EdgeInsets.all(0),
                    initialCameraPosition: CameraPosition(
                      target: sourceLocation!,
                      zoom: cameraZoom,
                      tilt: cameraTilt,
                      bearing: cameraBearing,
                    ),
                    onMapCreated: (controller) async => {
                      _darkMapStyle = await rootBundle
                          .loadString('assets/json/dark_mode_style.json'),
                      // _controller.complete(controller),
                      controller.setMapStyle(_darkMapStyle)
                    },
                  ),
                  Positioned(
                    top: height * 0.03,
                    left: width * 0.03,
                    right: width * 0.03,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.menu, size: width * 0.08),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: height * 0.055,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: language.enterYourDestination,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: height * 0.012,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.search, size: width * 0.08),
                          onPressed: () async {
                            if (await checkPermission()) {
                              showModalBottomSheet(
                                isScrollControlled: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(defaultRadius),
                                      topRight:
                                          Radius.circular(defaultRadius)),
                                ),
                                context: context,
                                builder: (_) {
                                  return RiderWidget(
                                      title: sourceLocationTitle,
                                      coordinates: sourceLocation);
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: height * 0.03,
                    left: width * 0.03,
                    right: width * 0.03,
                    child: Row(
                      children: [
                        FloatingActionButton(
                          mini: true,
                          onPressed: () async {
                            if (await checkPermission()) {
                              showModalBottomSheet(
                                isScrollControlled: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(defaultRadius),
                                      topRight:
                                          Radius.circular(defaultRadius)),
                                ),
                                context: context,
                                builder: (_) {
                                  return RiderWidget(
                                      title: sourceLocationTitle,
                                      coordinates: sourceLocation);
                                },
                              );
                            }
                          },
                          child: Icon(Icons.my_location),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: height * 0.018,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () async {
                              // go to wallet screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MyWalletScreen(),
                                ),
                              );
                            },
                            child: Text(
                              language.recargar,
                              style: TextStyle(
                                fontSize: width * 0.045,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (usdRate != null)
                    Positioned(
                      bottom: height * 0.12,
                      right: width * 0.03,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: height * 0.012,
                            horizontal: width * 0.04,
                          ),
                          child: Column(
                            children: [
                              Text(
                                language.tasaDeCambio,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: width * 0.035,
                                ),
                              ),
                              Text(
                                '\$1.00 → Bs.$usdRate',
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : loaderWidget(),
      ),
    );
  }
}
