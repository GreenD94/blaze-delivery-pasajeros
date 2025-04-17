import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:taxibooking/main.dart';
import 'package:taxibooking/model/CurrentRequestModel.dart';
import 'package:taxibooking/model/LoginResponse.dart';
import 'package:taxibooking/network/RestApis.dart';
import 'package:taxibooking/screens/ChatScreen.dart';
import 'package:taxibooking/screens/ReviewScreen.dart';
import 'package:taxibooking/utils/Colors.dart';
import 'package:taxibooking/utils/Constants.dart';
import 'package:taxibooking/utils/Extensions/AppButtonWidget.dart';
import 'package:taxibooking/utils/Extensions/StringExtensions.dart';
import 'package:taxibooking/utils/Extensions/app_common.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blinking_text/blinking_text.dart';

import '../../utils/Common.dart';
import '../screens/AlertScreen.dart';

class RideAcceptWidget extends StatefulWidget {
  final Driver? driverData;
  final OnRideRequest? rideRequest;

  RideAcceptWidget({this.driverData, this.rideRequest});

  @override
  RideAcceptWidgetState createState() => RideAcceptWidgetState();
}

class RideAcceptWidgetState extends State<RideAcceptWidget> {
  UserModel? userData;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    await getUserDetail(userId: widget.rideRequest!.driverId).then((value) {
      sharedPref.remove(IS_TIME);
      appStore.setLoading(false);
      userData = value.data;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              alignment: Alignment.center,
              margin: EdgeInsets.only(bottom: 16, top: 8),
              height: 5,
              width: 70,
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.driverData!.driverService!.name.validate(), style: boldTextStyle()),
                    SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          children: [
                            Text(language.carModel, style: secondaryTextStyle()),
                            SizedBox(width: 8),
                            Text('(${widget.driverData!.userDetail!.carModel.validate()})', style: secondaryTextStyle()),
                          ],
                        ),
                        Row(
                          children: [
                            Text("Nro. de Placa", style: secondaryTextStyle()),
                            SizedBox(width: 8),
                            Text('(${widget.driverData!.userDetail!.carPlateNumber.validate()})', style: secondaryTextStyle()),
                          ],
                        ),
                        Row(
                          children: [
                            Text("Color", style: secondaryTextStyle()),
                            SizedBox(width: 8),
                            Text('(${widget.driverData!.userDetail!.carColor.validate()})', style: secondaryTextStyle()),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                // mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 160,
                    child: BlinkText(
                      'No olvides dar el OTP al conductor.',
                      textAlign: TextAlign.right,
                      duration: Duration(seconds: 3),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                    child: Text('${language.otp} ${widget.rideRequest!.otp ?? ''}', style: boldTextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                child: Text(statusName(status: widget.rideRequest!.status.validate()), style: boldTextStyle(color: Colors.white)),
              ),
              inkWellWidget(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        contentPadding: EdgeInsets.all(0),
                        content: AlertScreen(rideId: widget.rideRequest!.id, regionId: widget.rideRequest!.regionId),
                      );
                    },
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                  child: Text(language.sos, style: boldTextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          Divider(color: Colors.grey, height: 16),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: commonCachedNetworkImage(widget.driverData!.profileImage.validate(),
                    fit: BoxFit.cover, height: 50, width: 50),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.driverData!.firstName.validate()} ${widget.driverData!.lastName.validate()}',
                        style: boldTextStyle()),
                    SizedBox(height: 4),
                    Text('${widget.driverData!.email.validate()}', style: secondaryTextStyle()),
                  ],
                ),
              ),
              inkWellWidget(
                onTap: () {
                  launchScreen(context, ChatScreen(userData: userData), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  child: Icon(Icons.chat, color: Colors.white),
                ),
              ),
              SizedBox(width: 16),
              inkWellWidget(
                onTap: () {
                  launchUrl(Uri.parse('tel:${widget.driverData!.contactNumber}'), mode: LaunchMode.externalApplication);
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  child: Icon(Icons.call, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Visibility(
            visible: widget.rideRequest!.status == COMPLETED,
            child: AppButtonWidget(
              text: language.driverReview,
              width: MediaQuery.of(context).size.width,
              textStyle: boldTextStyle(color: Colors.white),
              color: primaryColor,
              onTap: () {
                launchScreen(context, ReviewScreen(driverData: widget.driverData, rideRequest: widget.rideRequest!),
                    pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
              },
            ),
          ),
          Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Icon(Icons.near_me, color: Colors.green),
                    SizedBox(height: 4),
                    SizedBox(
                      height: 30,
                      child: DottedLine(
                        direction: Axis.vertical,
                        lineLength: double.infinity,
                        lineThickness: 2,
                        dashColor: primaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Icon(Icons.location_on, color: Colors.red),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 0, top: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.rideRequest!.startAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                      SizedBox(height: 8),
                      Text(widget.rideRequest!.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
          if (widget.rideRequest!.paymentType == 'mobile-payment' && widget.rideRequest!.status == IN_PROGRESS)
            Container(
              width: MediaQuery.of(context).size.width,
              child: Card(
                // margin: EdgeInsets.all(20),
                child: Column(children: [
                  // Text(widget.driverData!.userBankAccount.toString(), style: primaryTextStyle(size: 14), maxLines: 2),

                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                    child: Text('Datos de Pago Móvil', style: boldTextStyle(color: Colors.white)),
                  ),

                  // Text(widget.rideRequest!.paymentType ?? '-', style: primaryTextStyle(size: 14), maxLines: 2),
                  Text(widget.driverData!.userBankAccount['bank_name'] ?? '-', style: primaryTextStyle(size: 14), maxLines: 2),
                  Text(widget.driverData!.userBankAccount['bank_code'] ?? '-', style: primaryTextStyle(size: 14), maxLines: 2),
                  Text(widget.driverData!.userBankAccount['account_holder_name'] ?? '-',
                      style: primaryTextStyle(size: 14), maxLines: 2),
                  Text(widget.driverData!.userBankAccount['account_number'] ?? '-',
                      style: primaryTextStyle(size: 14), maxLines: 2),
                ]),
              ),
            )
        ],
      ),
    );
  }
}
