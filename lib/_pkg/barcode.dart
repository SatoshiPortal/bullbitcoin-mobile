import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class Barcode {
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<(String?, Err?)> scan() async {
    if (!await hasCameraPermission()) {
      return (null, Err('Camera permission denied'));
    }

    try {
      final res = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.QR,
      );
      if (res == '-1') {
        return (
          null,
          Err(
            'Did not scan anything',
          )
        );
      } else {
        return (res, null);
      }
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
