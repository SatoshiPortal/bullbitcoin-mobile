import 'dart:async';

import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:flutter/services.dart';

const _userCancelledMarker = 'Session invalidated by user';

const _tagLostMarkers = [
  'Tag connection lost',
  'Read NDEF error',
  'Error connecting to card',
  'Tag already removed',
];

NfcFailure nfcFailureFromError(Object error, {required bool isWrite}) {
  final details = error.toString();

  if (details.contains(_userCancelledMarker)) {
    return NfcCancelledFailure(details);
  }

  if (error is TimeoutException) return NfcTimeoutFailure(details);

  if (error is PlatformException) {
    switch (error.code) {
      case '400':
        return NfcInvalidPayloadFailure(details);
      case '404':
        return NfcDisabledFailure(details);
      case '405':
        return NfcUnsupportedTagFailure(details);
      case '406':
        return NfcBusyFailure(details);
      case '408':
        return NfcTimeoutFailure(details);
      case '409':
        return NfcCancelledFailure(details);
      case '503':
        return NfcTagLostFailure(details);
    }
  }

  if (_tagLostMarkers.any(details.contains)) return NfcTagLostFailure(details);

  return isWrite ? NfcWriteFailure(details) : NfcUnexpectedFailure(details);
}
