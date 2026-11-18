import 'package:bb_mobile/features/default_wallets/domain/default_wallets_failure.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_failure_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('default wallet failures read in the app language', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      const DefaultWalletsLoadFailure().toTranslated(context),
      'Impossible de charger les portefeuilles par défaut',
    );
    expect(
      const DefaultWalletsEmptyAddressFailure().toTranslated(context),
      "L'adresse ne peut pas être vide",
    );
    expect(
      const DefaultWalletsSaveFailure().toTranslated(context),
      "Impossible d'enregistrer l'adresse du portefeuille",
    );
    expect(
      const DefaultWalletsDeleteFailure().toTranslated(context),
      "Impossible de supprimer l'adresse du portefeuille",
    );
  });
}
