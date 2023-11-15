import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class BarcodeScanner extends StatelessWidget {
  const BarcodeScanner({super.key, required this.onScan});

  final Function((String?, Err?)) onScan;

  static Future openPopUp(BuildContext context, Function((String?, Err?)) onScan) async {
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PopUpBorder(
        child: BarcodeScanner(onScan: onScan),
      ),
    );
  }

//U74120MH2016PTC271620
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: BBHeader.popUpCenteredText(
            isLeft: true,
            text: 'Scan QR Code',
            onBack: () {
              context.pop();
            },
          ),
        ),
        // const Gap(24),
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            child: ReaderWidget(
              onScan: (result) {
                if (result.text == null)
                  onScan((null, Err('Error scanning barcode')));
                else
                  onScan((result.text, null));
                context.pop();
              },
            ),
          ),
        ),
      ],
    );
  }
}
