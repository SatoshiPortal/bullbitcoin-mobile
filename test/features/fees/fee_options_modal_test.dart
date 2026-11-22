import 'package:bb_mobile/features/fees/public/app_fee_ui.dart';

import 'dart:async';

import 'package:fees/fees.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullBottomSheet, BullSelectableList;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Actions extends Mock implements FeeModalActionsPort {}

class _State extends Mock implements FeeModalStatePort {}

const _feePresets = FeeOptions(
  fastest: NetworkFee.relativeSatPerKwu(1000),
  economic: NetworkFee.relativeSatPerKwu(500),
  slow: NetworkFee.relativeSatPerKwu(250),
  minRelay: RelativeFee(25),
);

void main() {
  testWidgets('formats preset previews through the host FeeUi', (tester) async {
    final state = _State();
    when(() => state.snapshot).thenReturn(
      const FeeModalSnapshot(
        feePresets: _feePresets,
        customFee: null,
        selectedFeeOption: FeeSelection.fastest,
        feePreviewCache: BitcoinFeePreviewCache(
          fastest: BitcoinFeePreviewSlot(feeSat: 863),
        ),
        exchangeRate: 3,
        fiatCurrencyCode: 'CAD',
        txSize: 200,
      ),
    );
    when(() => state.snapshots).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FeeOptionsModal(
              ui: FeeUi(
                label: appFeeUi.label,
                formatSats: appFeeUi.formatSats,
                formatApproximateSats: (sats) => 'custom format [$sats]',
                satsToFiat: (sats, rate) => sats + rate,
              ),
              viewState: state,
              actions: _Actions(),
              defaultAbsoluteCustomFee: false,
              customFeeColors: FeeModalCustomFeeColors(
                tile: context.appColors.surface,
                shadow: context.appColors.border,
                unselectedIcon: context.appColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
    final list = tester.widget<BullSelectableList>(
      find.byType(BullSelectableList),
    );
    expect(
      list.items.first.subtitle2,
      allOf(contains('custom format [863]'), contains('866.0 CAD')),
    );
  });

  for (final height in [844.0, 430.0]) {
    testWidgets('requests previews and selects a preset at height $height', (
      tester,
    ) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = _Actions();
      final state = _State();
      final snapshots = StreamController<FeeModalSnapshot>();
      addTearDown(snapshots.close);
      const initial = FeeModalSnapshot(
        feePresets: _feePresets,
        customFee: null,
        selectedFeeOption: FeeSelection.economic,
        feePreviewCache: BitcoinFeePreviewCache(),
        exchangeRate: null,
        fiatCurrencyCode: 'CAD',
        txSize: 200,
      );
      when(() => state.snapshot).thenReturn(initial);
      when(() => state.snapshots).thenAnswer((_) => snapshots.stream);

      String? selection;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selection = await BullBottomSheet.show<String>(
                    context: context,
                    child: FeeOptionsModal(
                      ui: appFeeUi,
                      viewState: state,
                      actions: actions,
                      defaultAbsoluteCustomFee: false,
                      customFeeColors: FeeModalCustomFeeColors(
                        tile: context.appColors.surface,
                        shadow: context.appColors.border,
                        unselectedIcon: context.appColors.textMuted,
                      ),
                    ),
                  );
                },
                child: Text(context.loc.sendSelectNetworkFee),
              ),
            ),
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.sendSelectNetworkFee));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (height == 844) {
        expect(tester.getTopLeft(find.byType(FeeOptionsModal)).dy, 0);
      }
      verify(() => actions.requestPresetPreviews()).called(1);
      final list = find.byType(BullSelectableList);
      expect(
        tester.widget<BullSelectableList>(list).selectedValue,
        FeeSelection.economic.title(),
      );

      snapshots.add(
        initial.copyWith(
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(feeSat: 863),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BullSelectableList>(list).items.first.subtitle2,
        contains('863'),
      );
      if (height < 500) {
        final custom = find.text(l10n.sendCustomFee);
        await tester.ensureVisible(custom);
        await tester.pumpAndSettle();
        expect(tester.getRect(custom).bottom, lessThanOrEqualTo(height));
      }
      await tester.ensureVisible(find.text(l10n.sendFastFee));
      await tester.tap(find.text(l10n.sendFastFee));
      await tester.pumpAndSettle();

      expect(selection, FeeSelection.fastest.title());
    });
  }
}
