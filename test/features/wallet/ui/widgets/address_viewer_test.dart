import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Urls extends Mock implements MempoolUrlBuilder {}

void main() {
  testWidgets(
    'dialog retains the injected explorer builder across navigation',
    (tester) async {
      const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
      const url = 'https://explorer.example/address/$address';
      final urls = _Urls();
      when(() => urls.bitcoinAddress(address, isTestnet: false))
          .thenAnswer((_) async => url);
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
        RepositoryProvider<MempoolUrlBuilder>.value(
          value: urls,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AddressViewer(address)),
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
      verify(() => urls.bitcoinAddress(address, isTestnet: false)).called(1);
    },
  );

  testWidgets('regtest has no explorer actions or builder requests', (
    tester,
  ) async {
    final urls = _Urls();
    await tester.pumpWidget(
      RepositoryProvider<MempoolUrlBuilder>.value(
        value: urls,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AddressViewer('bcrt1qexample')),
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
