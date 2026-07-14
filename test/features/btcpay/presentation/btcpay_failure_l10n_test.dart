import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('never renders diagnostic or server text', (tester) async {
    const diagnostic = 'sensitive-server-or-exception-detail';
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(context);
    final cases = <(BtcpayFailure, String)>[
      (
        const InvalidBtcpayPairingRequestFailure(diagnostic),
        loc.btcpayPairingInvalidRequestError,
      ),
      (
        const BtcpayPairingRejectedFailure(diagnostic),
        loc.btcpayPairingRejectedError,
      ),
      (
        const BtcpayPairingUncertainFailure(diagnostic),
        loc.btcpayPairingUncertainError,
      ),
      (
        const BtcpayWalletPreparationFailure(diagnostic),
        loc.btcpayPairingGenericError,
      ),
      (const BtcpayPayloadFailure(diagnostic), loc.btcpayPairingGenericError),
      (const BtcpayStorageFailure(diagnostic), loc.btcpayPairingGenericError),
      (const BtcpayRollbackFailure(diagnostic), loc.btcpayPairingGenericError),
      (
        const BtcpayUnexpectedFailure(diagnostic),
        loc.btcpayPairingGenericError,
      ),
    ];

    for (final (failure, expected) in cases) {
      final translated = failure.toTranslated(context);
      expect(translated, expected);
      expect(translated, isNot(contains(diagnostic)));
    }
  });
}
