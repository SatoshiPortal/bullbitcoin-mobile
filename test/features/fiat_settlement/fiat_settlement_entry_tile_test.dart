import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_entry_tile.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements FiatSettlementFacade {}

class _FakeGetSettings implements GetSettingsUsecase {
  @override
  Future<SettingsEntity> execute() async => const SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );
}

Future<void> _pumpTile(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const Scaffold(
        body: FiatSettlementEntryTile(product: FiatSettlementProduct.invoice),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => locator.reset());

  testWidgets('shows an honest unavailable state on a read failure', (
    tester,
  ) async {
    final facade = _MockFacade();
    when(
      () => facade.configuration(),
    ).thenAnswer((_) async => const Err(FiatSettlementFailure.unexpected()));
    locator
      ..registerSingleton<GetSettingsUsecase>(_FakeGetSettings())
      ..registerSingleton<FiatSettlementFacade>(facade);

    await _pumpTile(tester);

    // The tile is visible and honest: it shows the unavailable status and NEVER
    // fabricates a Bitcoin-only summary from the failure.
    expect(find.byKey(const ValueKey('fiat-settlement-entry-tile')), findsOne);
    expect(find.text('Fiat settlement — status unavailable'), findsOneWidget);
    expect(find.text('Bitcoin only'), findsNothing);
  });

  testWidgets('shows the confirmed summary when configuration loads', (
    tester,
  ) async {
    final facade = _MockFacade();
    when(() => facade.configuration()).thenAnswer(
      (_) async => const Ok(
        FiatSettlementConfigurationView(products: [], credentialActive: false),
      ),
    );
    locator
      ..registerSingleton<GetSettingsUsecase>(_FakeGetSettings())
      ..registerSingleton<FiatSettlementFacade>(facade);

    await _pumpTile(tester);

    // An absent product config is Bitcoin-only — a real confirmed summary,
    // distinct from the failure state above.
    expect(find.text('Bitcoin only'), findsOneWidget);
    expect(find.text('Fiat settlement — status unavailable'), findsNothing);
  });
}
