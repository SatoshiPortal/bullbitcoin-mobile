import 'dart:async';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Barcode {
  Future<(String?, Err?)> scan() async {
    final completer = Completer<(String?, Err?)>();
    final scanner = MobileScannerController();
    runApp(MaterialApp(
      home: Scaffold(
        body: MobileScanner(
          controller: scanner,
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode != null && barcode.rawValue != null) {
              scanner.dispose();
              completer.complete((barcode.rawValue, null));
            }
          },
        ),
      ),
    ));
    return completer.future;
  }
}
