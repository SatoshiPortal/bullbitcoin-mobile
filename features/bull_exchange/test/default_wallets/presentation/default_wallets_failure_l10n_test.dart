import 'package:bull_exchange/src/default_wallets/domain/default_wallets_failure.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_failure_l10n.dart';
import 'package:bull_exchange/bull_exchange.dart';
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
        localizationsDelegates: const [
          ExchangeLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: ExchangeLocalizations.supportedLocales,
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
