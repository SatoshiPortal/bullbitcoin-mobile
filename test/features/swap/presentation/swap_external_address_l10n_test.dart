import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _translateInFrench(
  WidgetTester tester,
  SwapFailure failure,
) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: appLocalizationsDelegates,
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
  testWidgets('external address failures read in the app language', (
    tester,
  ) async {
    expect(
      await _translateInFrench(tester, const SwapSourceWalletMissingFailure()),
      'Veuillez sélectionner un portefeuille source',
    );
    expect(
      await _translateInFrench(
        tester,
        const SwapInvalidExternalAddressFailure(expectsBitcoin: true),
      ),
      'Veuillez entrer une adresse Bitcoin valide',
    );
    expect(
      await _translateInFrench(
        tester,
        const SwapInvalidExternalAddressFailure(expectsBitcoin: false),
      ),
      'Veuillez entrer une adresse Liquid valide',
    );
  });
}
