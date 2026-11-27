import 'package:exchange/exchange.dart';
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
      const ExchangeDefaultWalletAddressEmptyFailure().toTranslated(context),
      "L'adresse ne peut pas être vide",
    );
    expect(
      const ExchangeDefaultWalletSaveFailure().toTranslated(context),
      "Impossible d'enregistrer l'adresse du portefeuille",
    );
    expect(
      const ExchangeDefaultWalletDeleteFailure().toTranslated(context),
      "Impossible de supprimer l'adresse du portefeuille",
    );
  });
}
