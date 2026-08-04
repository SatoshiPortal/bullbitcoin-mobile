import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract interface class NfcSession {
  @useResult
  Future<Result<String, NfcFailure>> readPayload({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  });

  @useResult
  Future<Result<String, NfcFailure>> readPushTxUri({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  });

  @useResult
  Future<Result<void, NfcFailure>> writeText({
    required String data,
    required String iosAlertMessage,
    required String iosErrorMessage,
  });

  Future<void> cancel();
}
