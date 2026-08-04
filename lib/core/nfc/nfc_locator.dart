import 'dart:io' show Platform;

import 'package:bb_mobile/core/nfc/data/nfc_kit_datasource.dart';
import 'package:bb_mobile/core/nfc/data/nfc_session_impl.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:get_it/get_it.dart';

class NfcLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<NfcKitDatasource>(
      () => const FlutterNfcKitDatasource(),
    );

    locator.registerLazySingleton<NfcSession>(
      () => NfcSessionImpl(
        kit: locator<NfcKitDatasource>(),
        isIOS: Platform.isIOS,
      ),
    );
  }
}
