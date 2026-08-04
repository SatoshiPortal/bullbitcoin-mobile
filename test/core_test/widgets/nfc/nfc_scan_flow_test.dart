import 'dart:async';

import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/nfc/nfc_scan_flow.dart';
import 'package:bb_mobile/core/widgets/nfc/nfc_scan_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNfcSession implements NfcSession {
  _FakeNfcSession({this.results = const [], this.hangUntilCancelled = false});

  final List<Result<String, NfcFailure>> results;
  final bool hangUntilCancelled;

  int runs = 0;
  int cancels = 0;
  Completer<Result<String, NfcFailure>>? _pending;

  Future<Result<String, NfcFailure>> _run() {
    runs++;

    if (hangUntilCancelled) {
      final pending = Completer<Result<String, NfcFailure>>();
      _pending = pending;
      return pending.future;
    }

    final index = runs - 1 < results.length ? runs - 1 : results.length - 1;
    return Future.value(results[index]);
  }

  @override
  Future<Result<String, NfcFailure>> readPayload({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  }) => _run();

  @override
  Future<Result<String, NfcFailure>> readPushTxUri({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  }) => _run();

  @override
  Future<Result<void, NfcFailure>> writeText({
    required String data,
    required String iosAlertMessage,
    required String iosErrorMessage,
  }) async => const Ok<void, NfcFailure>(null);

  @override
  Future<void> cancel() async {
    cancels++;

    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const Err<String, NfcFailure>(NfcCancelledFailure()));
    }
  }
}

void main() {
  const timeoutMessage =
      'No NFC tag detected. Hold your phone still against the NFC symbol on '
      'your device and try again.';

  Future<void> pumpFlow(
    WidgetTester tester,
    _FakeNfcSession session, {
    void Function(String payload)? onPayload,
    VoidCallback? onCancelled,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NfcScanFlow(
            session: session,
            run: (session) => session.readPayload(
              iosAlertMessage: 'hold',
              iosTagLostMessage: 'lost',
            ),
            onPayload: onPayload ?? (_) {},
            onCancelled: onCancelled,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
  }

  testWidgets('a timeout offers a retry that starts a new scan', (
    tester,
  ) async {
    final session = _FakeNfcSession(
      results: const [
        Err<String, NfcFailure>(NfcTimeoutFailure()),
        Ok<String, NfcFailure>('payload'),
      ],
    );

    await pumpFlow(tester, session);

    expect(find.text(timeoutMessage), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(session.runs, 1);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump();

    expect(session.runs, 2);
    expect(find.text(timeoutMessage), findsNothing);
  });

  testWidgets('a payload is handed to the caller', (tester) async {
    final session = _FakeNfcSession(
      results: const [Ok<String, NfcFailure>('cHNidP8B')],
    );

    String? received;
    await pumpFlow(tester, session, onPayload: (payload) => received = payload);

    expect(received, 'cHNidP8B');
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('a cancelled scan shows no error and notifies the caller', (
    tester,
  ) async {
    final session = _FakeNfcSession(
      results: const [Err<String, NfcFailure>(NfcCancelledFailure())],
    );

    var cancelledCalls = 0;
    await pumpFlow(tester, session, onCancelled: () => cancelledCalls++);

    expect(cancelledCalls, 1);
    expect(find.text(timeoutMessage), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('backgrounding the app cancels the running scan', (tester) async {
    final session = _FakeNfcSession(hangUntilCancelled: true);

    await pumpFlow(tester, session);
    tester.takeException();

    expect(session.cancels, 0);
    expect(
      tester.widget<NfcScanView>(find.byType(NfcScanView)).isScanning,
      isTrue,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    tester.takeException();

    expect(session.cancels, 1);
    expect(session.runs, 1);
  });
}
