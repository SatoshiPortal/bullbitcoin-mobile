import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show BitcoinSpendStatus;
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _translate(WidgetTester tester, SwapFailure failure) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  testWidgets('a busy wallet asks to retry, not to wait for a sync', (
    tester,
  ) async {
    final busy = await _translate(
      tester,
      const SwapSpendBlockedFailure(BitcoinSpendStatus.busy),
    );
    final pending = await _translate(
      tester,
      const SwapSpendBlockedFailure(BitcoinSpendStatus.pending),
    );
    final english = lookupAppLocalizations(const Locale('en'));

    expect(busy, english.walletSpendBusy);
    expect(pending, english.walletSpendAwaitingObservation);
  });
}
