import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class Barcode {
  Future<(String?, Err?)> scan(BuildContext context) async {
    try {
      String? result;

      await showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: QRView(
            key: GlobalKey(debugLabel: 'QR'),
            onQRViewCreated: (QRViewController controller) {
              controller.scannedDataStream.listen((scanData) {
                if (scanData.code != null) {
                  result = scanData.code;
                  Navigator.pop(context);
                }
              });
            },
          ),
        ),
      );

      if (result == null)
        return (
          null,
          Err('No QR code scanned'),
        );
      else
        return (result, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
