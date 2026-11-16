import 'dart:io';

import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_sdk/bull_sdk.dart';

Future<void> initFlutterRustBridgeDependencies() async {
  await BullSdk.init();
  if (Platform.isAndroid) await BitBoxApi.initialize();
}
