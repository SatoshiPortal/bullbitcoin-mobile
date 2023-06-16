import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class Barcode {
  Future<(String?, Err?)> scan() async {
    try {
      final res = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.QR,
      );

      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
