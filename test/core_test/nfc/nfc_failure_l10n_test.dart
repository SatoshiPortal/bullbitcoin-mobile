import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/nfc/presentation/nfc_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const logMessage = 'PlatformException(408, Polling tag timeout, null, null)';

  const translatedFailures = <NfcFailure>[
    NfcUnsupportedFailure(logMessage),
    NfcDisabledFailure(logMessage),
    NfcTimeoutFailure(logMessage),
    NfcBusyFailure(logMessage),
    NfcTagLostFailure(logMessage),
    NfcUnsupportedTagFailure(logMessage),
    NfcInvalidPayloadFailure(logMessage),
    NfcWriteFailure(logMessage),
    NfcUnexpectedFailure(logMessage),
  ];

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    return capturedContext;
  }

  testWidgets('every failure has a non empty user facing message', (
    tester,
  ) async {
    final context = await pumpContext(tester);

    for (final failure in translatedFailures) {
      final message = failure.toTranslated(context);

      expect(message, isNotNull, reason: '${failure.runtimeType}');
      expect(message, isNotEmpty, reason: '${failure.runtimeType}');
    }
  });

  testWidgets('no user facing message leaks the log message', (tester) async {
    final context = await pumpContext(tester);

    for (final failure in translatedFailures) {
      expect(
        failure.toTranslated(context),
        isNot(contains(logMessage)),
        reason: '${failure.runtimeType}',
      );
    }
  });

  testWidgets('a cancelled session shows nothing', (tester) async {
    final context = await pumpContext(tester);

    expect(const NfcCancelledFailure(logMessage).toTranslated(context), isNull);
  });

  testWidgets('a timeout explains what to do next', (tester) async {
    final context = await pumpContext(tester);

    expect(
      const NfcTimeoutFailure().toTranslated(context),
      'No NFC tag detected. Hold your phone still against the NFC symbol on '
      'your device and try again.',
    );
  });
}
