import 'package:flutter/material.dart';
import 'package:taxibooking/main.dart';
import 'package:taxibooking/utils/Colors.dart';
import 'package:taxibooking/utils/Constants.dart';

import '../utils/Extensions/app_common.dart';

class ModalitySelectorWidget extends StatefulWidget {
  final String? title;
  final String? iconData;
  final Function(String)? onSelectParam;

  ModalitySelectorWidget({this.title, this.iconData, this.onSelectParam});

  @override
  DrawerWidgetState createState() => DrawerWidgetState();
}

class DrawerWidgetState extends State<ModalitySelectorWidget> {
  List modalityList = [];
  int selectedIndex = 0;
  bool isAuctionEnabled = false;
  bool isExpressEnabled = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {

    updateAvailableModalities();

    setState(() {});

  }

  void initModality() {
    modalityList.clear();

    if (appStore.expressEnabled) {
      modalityList.add({
        'title': 'Express', 
        'name': 'express', 
        'description': 'Pago Rápido.'
      });
    }

    if (modalityList.isNotEmpty) {
      selectedIndex = 0;
      appStore.setRideModality(modalityList[0]['name'].toString());
    }

    setState(() {});
  }

  void updateAvailableModalities() async {
    initModality();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Stack(children: [
      Visibility(
          visible: modalityList.isNotEmpty,
          child: Container(
              // color: Colors.white,
              child: SingleChildScrollView(
                  reverse: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Center(
                    //   child: Container(
                    //     alignment: Alignment.center,
                    //     margin: EdgeInsets.only(bottom: 16, top: 16),
                    //     height: 5,
                    //     width: 70,
                    //     decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                    //   ),
                    // ),
                    SingleChildScrollView(
                      padding: EdgeInsets.only(left: 8, right: 8),
                      reverse: true,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: modalityList.map((e) {
                          return GestureDetector(
                            onTap: () {
                              selectedIndex = modalityList.indexOf(e);
                              if (widget.onSelectParam != null) {
                                widget.onSelectParam!(e['name'].toString());
                                appStore.setRideModality(e['name'].toString());
                              }
                              setState(() {});
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.all(8),
                              margin: EdgeInsets.only(top: 16, left: 8, right: 8),
                              decoration: BoxDecoration(
                                color: selectedIndex == modalityList.indexOf(e) ? primaryColor : Colors.white,
                                border: Border.all(color: primaryColor.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(defaultRadius),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        e['name'] == 'express' ? Icons.fast_forward : Icons.group,
                                        color: selectedIndex == modalityList.indexOf(e) ? Colors.white : primaryColor,
                                      ),
                                      // SizedBox(height: 8),
                                      // commonCachedNetworkImage(e.serviceImage.validate(),
                                      //     height: 50, width: 100, fit: BoxFit.cover, alignment: Alignment.center),
                                      SizedBox(width: 8),
                                      Text(e['title'],
                                          style: boldTextStyle(
                                              color: selectedIndex == modalityList.indexOf(e) ? Colors.white : primaryColor)),

                                    ],
                                  ),
                                  Text(e['description'],
                                          style: boldTextStyle(
                                              color: selectedIndex == modalityList.indexOf(e) ? Colors.white : primaryColor)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 8),
                  ]))))
    ]));
  }

}
