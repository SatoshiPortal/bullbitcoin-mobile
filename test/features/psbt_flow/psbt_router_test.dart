import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/routes.dart';

void main() {
  const destinations = {
    'show': '/show-psbt',
    'importLedger': '/ledger-import',
    'ledgerSignTransaction': '/ledger-sign-transaction',
    'ledgerVerifyAddress': '/ledger-verify-address',
    'importBitBox': '/bitbox-import',
    'bitboxSignTransaction': '/bitbox-sign-transaction',
    'bitboxVerifyAddress': '/bitbox-verify-address',
  };

  for (final (description, extra) in [
    ('restored without extras', null),
    ('opened with malformed extras', Object()),
  ]) {
    for (final MapEntry(:key, :value) in destinations.entries) {
      testWidgets('$value $description renders a localized error', (
        tester,
      ) async {
        final services = GetIt.asNewInstance();
        addTearDown(services.reset);
        final feature = SignersFeature.mount(
          services: services,
          writeNfc: (_, _, _, _) async => fail('Unexpected NFC write'),
        );
        final router = GoRouter(
          initialLocation: value,
          initialExtra: extra,
          routes: feature.routes,
        );
        addTearDown(router.dispose);
        expect(router.namedLocation(key), value);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(Scaffold));
        final error = find.text(
          AppLocalizations.of(context).oopsSomethingWentWrong,
        );
        expect(error, findsOneWidget);
        if (key == 'show' && extra == null) {
          router.go(value, extra: (psbt: '', signerDevice: null));
          await tester.pumpAndSettle();
          expect(error, findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
