import 'dart:io';

import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:rust_bindings/rust_bindings.dart';

Future<void> initFlutterRustBridgeDependencies() async {
  await BullSdk.init();
  if (Platform.isAndroid) await BitBoxApi.initialize();
}
