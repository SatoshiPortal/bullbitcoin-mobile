import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_failure_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provisioning/provisioning.dart';

void main() {
  testWidgets(
    'seed-only reuse explains that the wallet has no recovery phrase',
    (tester) async {
      const failure = NetworkWalletSetupSecretFailure(
        DefaultWalletSecretRefusal.nonMnemonic,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(failure.toTranslated(context)),
          ),
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.networkWalletReuseNoRecoveryPhrase),
        findsOneWidget,
      );
      expect(find.text(l10n.oopsSomethingWentWrong), findsNothing);
    },
  );
}
