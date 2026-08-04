import 'dart:async';

import 'package:bb_mobile/core/nfc/data/nfc_error_mapper.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nfcFailureFromError', () {
    final codeCases = <String, Matcher>{
      '400': isA<NfcInvalidPayloadFailure>(),
      '404': isA<NfcDisabledFailure>(),
      '405': isA<NfcUnsupportedTagFailure>(),
      '406': isA<NfcBusyFailure>(),
      '408': isA<NfcTimeoutFailure>(),
      '409': isA<NfcCancelledFailure>(),
      '503': isA<NfcTagLostFailure>(),
    };

    codeCases.forEach((code, matcher) {
      test('maps platform code $code', () {
        final failure = nfcFailureFromError(
          PlatformException(code: code, message: 'boom'),
          isWrite: false,
        );

        expect(failure, matcher);
      });
    });

    test('maps the android polling timeout message', () {
      final failure = nfcFailureFromError(
        PlatformException(code: '408', message: 'Polling tag timeout'),
        isWrite: false,
      );

      expect(failure, isA<NfcTimeoutFailure>());
      expect(failure.logMessage, contains('Polling tag timeout'));
    });

    test('maps a user cancelled session regardless of code', () {
      final failure = nfcFailureFromError(
        PlatformException(code: '500', message: 'Session invalidated by user'),
        isWrite: true,
      );

      expect(failure, isA<NfcCancelledFailure>());
    });

    test('maps a dart side timeout', () {
      final failure = nfcFailureFromError(
        TimeoutException('watchdog'),
        isWrite: false,
      );

      expect(failure, isA<NfcTimeoutFailure>());
    });

    final tagLostMessages = [
      'Tag connection lost',
      'Read NDEF error',
      'Error connecting to card',
      'Tag already removed',
    ];

    for (final message in tagLostMessages) {
      test('maps "$message" to a lost tag', () {
        final failure = nfcFailureFromError(
          PlatformException(code: '500', message: message),
          isWrite: false,
        );

        expect(failure, isA<NfcTagLostFailure>());
      });
    }

    test('maps an unmapped write error to a write failure', () {
      final failure = nfcFailureFromError(
        PlatformException(code: '500', message: 'Write NDEF error'),
        isWrite: true,
      );

      expect(failure, isA<NfcWriteFailure>());
    });

    test('maps an unmapped read error to an unexpected failure', () {
      final failure = nfcFailureFromError(
        StateError('something else'),
        isWrite: false,
      );

      expect(failure, isA<NfcUnexpectedFailure>());
      expect(failure.logMessage, contains('something else'));
    });
  });
}
