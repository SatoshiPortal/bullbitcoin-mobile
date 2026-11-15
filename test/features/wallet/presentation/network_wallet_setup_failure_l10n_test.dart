import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_failure_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seed-only reuse explains the supported recovery phrase', (
    tester,
  ) async {
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
    expect(find.text(l10n.mnemonicDefaultEnglishOnly), findsOneWidget);
    expect(find.text(l10n.oopsSomethingWentWrong), findsNothing);
  });
}
