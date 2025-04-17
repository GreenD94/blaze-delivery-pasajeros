import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:taxibooking/network/RestApis.dart';
import 'package:taxibooking/utils/Colors.dart';
import 'package:taxibooking/utils/Constants.dart';
import 'package:taxibooking/utils/Extensions/AppButtonWidget.dart';

import '../../utils/Extensions/app_common.dart';
import '../model/SettingModel.dart';

class ReferralScreen extends StatefulWidget {
  final SettingModel settingModel;

  ReferralScreen({required this.settingModel});

  @override
  ReferralScreenState createState() => ReferralScreenState();
}

class ReferralScreenState extends State<ReferralScreen> {
  String? refCode;
  String? title;
  String? subTitle;
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //
    getRefCode().then((value) => {
          refCode = value['ref_code'].toString(),
          title = value['title'].toString(),
          subTitle = value['sub_title'].toString(),
          setState(() {})
        });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Referidos', style: boldTextStyle(color: Colors.white)),
      ),
      body: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/referrals.png', height: 150, width: 150, fit: BoxFit.cover),
            if (refCode != null)
              Column(
                children: [
                  SizedBox(height: 16),
                  if (title != null && title != '') Text(title.toString(), style: primaryTextStyle(size: 20)),
                  SizedBox(height: 8),
                  if (title != null && title != '') Text(subTitle.toString(), style: primaryTextStyle(size: 14)),
                  // Text('Gana con referidos', style: primaryTextStyle(size: 14)),
                  SizedBox(height: 16),
                ],
              ),
            if (refCode != null)
              DottedBorder(
                color: Theme.of(context).primaryColor,
                strokeWidth: 1,
                strokeCap: StrokeCap.butt,
                dashPattern: [8, 5],
                padding: EdgeInsets.all(0),
                borderType: BorderType.RRect,
                radius: Radius.circular(10),
                child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    height: 50,
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          refCode!,
                          style: boldTextStyle(),
                        ),
                      ),
                      InkWell(
                          onTap: () {
                            // if(Get.find<UserController>().userInfoModel.refCode.isNotEmpty){
                            Clipboard.setData(ClipboardData(text: refCode.toString()));
                            //   showCustomSnackBar('referral_code_copied'.tr, isError: false);
                            toast('Código de referido copiado');
                            // }
                          },
                          child: Text('Toque para copiar', style: boldTextStyle())),
                    ])
                    // : CircularProgressIndicator(),
                    ),
              ),
            if (refCode == null) CircularProgressIndicator(),
            SizedBox(height: 16),
            if (refCode != null)
              AppButtonWidget(
                onTap: () {
                  Share.share("Este es mi código de referido: $refCode en la aplicación $mAppName");
                },
                // text: 'Compartir',
                color: primaryColor,
                textStyle: boldTextStyle(color: Colors.white),
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.share,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Compartir',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
      // bottomNavigationBar: Padding(
      //   padding: EdgeInsets.all(16),
      //   child: Container(
      //     height: 120,
      //     child: Column(
      //       children: [
      //         Text(language.lblFollowUs, style: boldTextStyle()),
      //         SizedBox(height: 8),
      //         Row(
      //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //           crossAxisAlignment: CrossAxisAlignment.center,
      //           children: <Widget>[
      //             inkWellWidget(
      //               onTap: () {
      //                 if (widget.settingModel.instagramUrl != null && widget.settingModel.instagramUrl!.isNotEmpty) {
      //                   launchUrl(Uri.parse(widget.settingModel.instagramUrl.validate()), mode: LaunchMode.externalApplication);
      //                 } else {
      //                   toast(language.txtURLEmpty);
      //                 }
      //               },
      //               child: Container(
      //                 padding: EdgeInsets.all(10),
      //                 child: Image.asset("images/ic_insta.png", height: 35, width: 35),
      //               ),
      //             ),
      //             inkWellWidget(
      //               onTap: () {
      //                 if (widget.settingModel.twitterUrl != null && widget.settingModel.twitterUrl!.isNotEmpty) {
      //                   launchUrl(Uri.parse(widget.settingModel.twitterUrl.validate()), mode: LaunchMode.externalApplication);
      //                 } else {
      //                   toast(language.txtURLEmpty);
      //                 }
      //               },
      //               child: Container(
      //                 padding: EdgeInsets.all(10),
      //                 child: Image.asset('images/ic_twitter.png', height: 35, width: 35),
      //               ),
      //             ),
      //             inkWellWidget(
      //               onTap: () {
      //                 if (widget.settingModel.linkedinUrl != null && widget.settingModel.linkedinUrl!.isNotEmpty) {
      //                   launchUrl(Uri.parse(widget.settingModel.linkedinUrl.validate()), mode: LaunchMode.externalApplication);
      //                 } else {
      //                   toast(language.txtURLEmpty);
      //                 }
      //               },
      //               child: Container(
      //                 padding: EdgeInsets.all(10),
      //                 child: Image.asset('images/ic_linked.png', height: 35, width: 35),
      //               ),
      //             ),
      //             inkWellWidget(
      //               onTap: () {
      //                 if (widget.settingModel.facebookUrl != null && widget.settingModel.facebookUrl!.isNotEmpty) {
      //                   launchUrl(Uri.parse(widget.settingModel.facebookUrl.validate()), mode: LaunchMode.externalApplication);
      //                 } else {
      //                   toast(language.txtURLEmpty);
      //                 }
      //               },
      //               child: Container(
      //                 padding: EdgeInsets.all(10),
      //                 child: Image.asset('images/ic_facebook.png', height: 35, width: 35),
      //               ),
      //             ),
      //             inkWellWidget(
      //               onTap: () {
      //                 if (widget.settingModel.contactNumber != null && widget.settingModel.contactNumber!.isNotEmpty) {
      //                   launchUrl(Uri.parse('tel:${widget.settingModel.contactNumber.validate()}'),
      //                       mode: LaunchMode.externalApplication);
      //                 } else {
      //                   toast(language.txtURLEmpty);
      //                 }
      //               },
      //               child: Container(
      //                 margin: EdgeInsets.only(right: 16),
      //                 padding: EdgeInsets.all(10),
      //                 child: Icon(
      //                   Icons.call,
      //                   color: appStore.isDarkMode ? Colors.white : primaryColor,
      //                   size: 36,
      //                 ),
      //               ),
      //             )
      //           ],
      //         ),
      //         SizedBox(height: 8),
      //         widget.settingModel.siteCopyright != null && widget.settingModel.siteCopyright!.isNotEmpty
      //             ? Text(widget.settingModel.siteCopyright.validate(), style: secondaryTextStyle(), maxLines: 1)
      //             : Text('Copyright' + " @${DateTime.now().year} meetmighty", style: secondaryTextStyle(size: 12)),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}
