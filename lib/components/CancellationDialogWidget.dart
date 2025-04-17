import 'package:flutter/material.dart';
import 'package:taxibooking/main.dart';
import 'package:taxibooking/utils/Colors.dart';
import 'package:taxibooking/utils/Extensions/AppButtonWidget.dart';
import 'package:taxibooking/utils/Extensions/app_common.dart';

class CancellationDialog extends StatefulWidget {
  final List<dynamic> reasons;
  final void Function(int?) onConfirm;

  CancellationDialog({required this.reasons, required this.onConfirm});

  @override
  _CancellationDialogState createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<CancellationDialog> {
  int? _selectedReasonId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.all(0),
      content: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20,),
            SizedBox(
              width: double.maxFinite,
              height: 340,
              child: ListView.builder(
                itemCount: widget.reasons.length,
                itemBuilder: (context, index) {
                  final reason = widget.reasons[index];
                  return RadioListTile<int>(
                    title: Text(reason['name'], style: secondaryTextStyle(),),
                    value: reason['id'],
                    groupValue: _selectedReasonId,
                    onChanged: (value) {
                      setState(() {
                        _selectedReasonId = value;
                      });
                    },
                    // contentPadding: EdgeInsets.all(4),
                    visualDensity: VisualDensity(vertical: -4), // Reduce el espacio vertical
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: AppButtonWidget(
                width: MediaQuery.of(context).size.width,
                color: primaryColor,
                text: language.cancel,
                textStyle: boldTextStyle(color: Colors.white),
                onTap: () {
                  if (_selectedReasonId != null || _selectedReasonId != 0) {  
                    print('Confirmed reason ID: $_selectedReasonId');
                    widget.onConfirm(_selectedReasonId);
                    Navigator.pop(context);
                  } else {
                    toast("Seleccione una opción");
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
