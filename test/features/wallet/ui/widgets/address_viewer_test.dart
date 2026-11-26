import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:mempool/mempool.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Urls extends Mock implements MempoolLinks {}

void main() {
  late String unconfidential;
  setUpAll(() async {
    await BullSdk.init();
    unconfidential = (await lwk.Address.addressFromScript(
      network: lwk.LiquidNetwork.regtest,
      script: '00141111111111111111111111111111111111111111',
    )).standard;
    expect(unconfidential, startsWith('ert1'));
  });
  tearDownAll(BullSdk.dispose);
  for (final (network, address) in [
    (BitcoinNetwork.mainnet, '1BoatSLRHtKNngkdXEeobR76b53LETtpyT'),
    (BitcoinNetwork.testnet, 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
  ]) {
    testWidgets(
      'dialog resolves the injected $network explorer link across navigation',
      (tester) async {
        final url = 'https://explorer.example/address/$address';
        final urls = _Urls();
        when(() => urls.address(address, network: network))
            .thenAnswer((_) async => Ok(Uri.parse(url)));
        Object? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') copied = call.arguments;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          RepositoryProvider<MempoolLinks>.value(
            value: urls,
            child: MaterialApp(
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: AddressViewer(address)),
            ),
          ),
        );
        await tester.tap(find.byType(AddressViewer));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.link));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(copied, {'text': url});
        verify(() => urls.address(address, network: network)).called(1);
      },
    );
  }

  testWidgets('URI view observes a failing local explorer lookup', (
    tester,
  ) async {
    const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
    final urls = _Urls();
    final lookup = Completer<Result<Uri, MempoolFailure>>();
    when(() => urls.address(address, network: BitcoinNetwork.mainnet))
        .thenAnswer((_) => lookup.future);
    await tester.pumpWidget(
      RepositoryProvider<MempoolLinks>.value(
        value: urls,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: AddressViewer(
              address,
              clipboardText: 'bitcoin:$address?amount=1',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AddressViewer));
    await tester.pumpAndSettle();
    lookup.complete(const Err(MempoolLoadFailure(MempoolServerKind.custom)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.link), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (label, address) in [
    (
      'confidential Liquid',
      () => 'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q',
    ),
    ('unconfidential Liquid', () => unconfidential),
    ('invalid Bitcoin', () => 'bcrt1qexample'),
  ]) {
    testWidgets('regtest $label has no explorer actions or builder requests', (
      tester,
    ) async {
      final urls = _Urls();
      await tester.pumpWidget(
        RepositoryProvider<MempoolLinks>.value(
          value: urls,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AddressViewer(address())),
          ),
        ),
      );
      await tester.tap(find.byType(AddressViewer));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.link), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
      verifyZeroInteractions(urls);
    });
  }
}
