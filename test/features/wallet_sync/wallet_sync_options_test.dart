import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_options_sheet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:bb_mobile/features/wallet_sync/domain/bitcoin_recovery_estimate.dart';

Widget _app(
  Widget child, {
  String locale = 'en',
  AppThemeType theme = AppThemeType.light,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.themeData(theme),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final type in BitcoinSyncScriptType.values) {
    for (final locale in ['en', 'fr']) {
      testWidgets('$type unknown cost and preactivation clamp in $locale', (
        tester,
      ) async {
        var called = false;
        WalletBirthday? result;
        final now = DateTime.utc(2026, 10, 28);
        await tester.pumpWidget(
          _app(
            WalletBirthdayForm(
              network: BitcoinNetwork.mainnet,
              scriptType: type,
              now: now,
              initialBirthday: DateTime.utc(2010, 1),
              onConfirmed: (value) {
                called = true;
                result = value;
              },
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final loc = AppLocalizations.of(
          tester.element(find.byType(WalletBirthdayForm)),
        );
        final date = DateFormat.yMMMM(locale).format(type.earliestDate);
        final months = BitcoinRecoveryEstimate.monthsFrom(
          type.earliestDate,
          now,
        );
        expect(find.text(loc.syncBirthdayClamped(date)), findsOneWidget);
        expect(find.text(loc.syncMonthsToCheck(months)), findsOneWidget);
        await _tap(tester, loc.syncUnknown);
        expect(called, isFalse);
        expect(
          find.text(
            type == BitcoinSyncScriptType.preSegwit
                ? loc.syncUnknownHdStart(date)
                : loc.syncUnknownScriptStart(date),
          ),
          findsOneWidget,
        );
        expect(find.text(loc.syncMonthsToCheck(months)), findsNWidgets(2));
        final estimate = BitcoinRecoveryEstimate(type);
        expect(
          find.text(
            type == BitcoinSyncScriptType.segwitV0
                ? loc.syncUnknownSegwitCost
                : loc.syncUnknownEstimatedCost(
                    estimate.minutes,
                    estimate.gigabytes,
                  ),
          ),
          findsOneWidget,
        );
        expect(find.text(loc.syncRecoveryPreparation), findsOneWidget);
        await _tap(tester, loc.syncScanFromDate(date));
        expect(called, isTrue);
        expect(result, isNull);
      });
    }
  }

  testWidgets('test networks describe genesis without mainnet cost estimates', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WalletBirthdayForm(
          network: BitcoinNetwork.signet,
          scriptType: BitcoinSyncScriptType.taproot,
          now: DateTime.utc(2026, 10, 28),
          onConfirmed: (_) {},
        ),
      ),
    );
    await _tap(tester, 'I don’t know');
    expect(find.textContaining('genesis block'), findsOneWidget);
    expect(find.textContaining('12 GB'), findsNothing);
    expect(find.textContaining('Estimated from block counts'), findsNothing);
  });

  for (final (label, expected) in [
    ('Legacy', BitcoinSyncScriptType.preSegwit),
    ('Nested SegWit', BitcoinSyncScriptType.segwitV0),
    ('Native SegWit', BitcoinSyncScriptType.segwitV0),
  ]) {
    testWidgets('mnemonic $label choice reaches the birthday resolver', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const WalletSyncOptionsSheet(
            network: BitcoinNetwork.mainnet,
            askScriptType: true,
          ),
        ),
      );
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      await _tap(tester, label);
      await _tap(tester, 'Continue');
      expect(
        tester
            .widget<WalletBirthdayForm>(find.byType(WalletBirthdayForm))
            .scriptType,
        expected,
      );
    });
  }

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final locale in ['en', 'fr', 'ar']) {
      testWidgets('source and birthday use sheet headings in $theme/$locale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(393, 851));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            const WalletSyncOptionsSheet(network: BitcoinNetwork.mainnet),
            locale: locale,
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        var context = tester.element(find.byType(WalletSyncOptionsSheet));
        final loc = AppLocalizations.of(context);
        final sourceTitle = switch (locale) {
          'fr' => 'Comment ce portefeuille doit-il se synchroniser ?',
          _ => 'How should this wallet sync?',
        };
        final source = find.widgetWithText(BullText, sourceTitle);
        expect(source, findsOneWidget);
        expect(
          tester.widget<BullText>(source).style,
          context.bullText.headlineMedium,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.header == true,
          ),
          findsOneWidget,
        );
        await _tap(tester, loc.syncPrivateTitle);
        await _tap(tester, loc.importMnemonicContinue);
        context = tester.element(find.byType(WalletBirthdayForm));
        final birthday = find.widgetWithText(BullText, loc.syncBirthdayTitle);
        expect(
          tester.widget<BullText>(birthday).style,
          context.bullText.headlineMedium,
        );
        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.byTooltip(loc.syncBack), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(tester, loc.syncUnknown);
        expect(
          find.text(
            loc.syncUnknownScriptStart(
              DateFormat.yMMMM(loc.localeName).format(DateTime.utc(2017, 8)),
            ),
          ),
          findsOneWidget,
        );
        await _tap(tester, loc.syncPickDate);
        expect(
          tester
              .widget<BullButton>(
                find.widgetWithText(BullButton, loc.importMnemonicContinue),
              )
              .disabled,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'birthday has a text action, header back and two full-width actions',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const WalletSyncOptionsSheet(
            network: BitcoinNetwork.mainnet,
            askScriptType: true,
          ),
        ),
      );
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      await _tap(tester, 'Continue');
      final unknown = tester.widget<BullButton>(
        find.widgetWithText(BullButton, 'I don’t know'),
      );
      expect(unknown.size, BullButtonSize.small);
      expect(unknown.outlined, isFalse);
      final context = tester.element(find.byType(WalletBirthdayForm));
      expect(unknown.bgColor, context.bull.transparent);
      expect(find.text('Back'), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      final fullWidth = tester
          .widgetList<BullButton>(find.byType(BullButton))
          .where((b) => b.size == BullButtonSize.large);
      expect(fullWidth.map((b) => b.label), ['Continue', 'Cancel']);
      await tester.ensureVisible(find.byTooltip('Back'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('bc1q…'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(BullSelectableList), findsOneWidget);
      expect(
        tester
            .widget<BullSelectableList>(find.byType(BullSelectableList))
            .selectedValue,
        BitcoinSyncSource.compactBlockFilters.name,
      );
    },
  );

  testWidgets(
    'birthday starts without a month and continues only after selection',
    (tester) async {
      WalletBirthday? confirmed;
      await tester.pumpWidget(
        _app(
          WalletBirthdayForm(
            network: BitcoinNetwork.mainnet,
            now: DateTime.utc(2026, 10, 28),
            onConfirmed: (value) => confirmed = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      var fields = tester
          .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
          .toList();
      expect(fields.first.value, 2026);
      expect(fields.last.value, isNull);
      expect(find.text('Scan from August 2017'), findsNothing);
      expect(find.textContaining('Scanning from'), findsNothing);
      final primary = find.widgetWithText(BullButton, 'Continue');
      expect(tester.widget<BullButton>(primary).disabled, isTrue);
      fields.first.onChanged?.call(2021);
      await tester.pumpAndSettle();
      fields = tester
          .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
          .toList();
      expect(fields.first.value, 2021);
      expect(fields.last.value, isNull);
      expect(tester.widget<BullButton>(primary).disabled, isTrue);
      fields.last.onChanged?.call(3);
      await tester.pumpAndSettle();
      expect(tester.widget<BullButton>(primary).disabled, isFalse);
      await _tap(tester, 'Continue');
      expect(confirmed?.dateTime, DateTime.utc(2021, 3));
    },
  );

  testWidgets(
    'server source is preselected; private path defaults to Native SegWit with no previews',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const WalletSyncOptionsSheet(
            network: BitcoinNetwork.mainnet,
            askScriptType: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BullSelectableList>(find.byType(BullSelectableList))
            .selectedValue,
        BitcoinSyncSource.electrum.name,
      );
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      expect(
        tester
            .widget<BullSelectableList>(find.byType(BullSelectableList))
            .selectedValue,
        ScriptType.bip84.name,
      );
      expect(find.text('bc1q…'), findsOneWidget);
      expect(find.byType(BullShimmerLine), findsNothing);
      await _tap(tester, 'Continue');
      expect(find.byType(WalletBirthdayForm), findsOneWidget);
      expect(find.textContaining('months of blocks to check.'), findsNothing);
    },
  );

  testWidgets(
    'unknown birthday requires confirmation and previews the SegWit checkpoint',
    (tester) async {
      var confirmed = false;
      WalletBirthday? result = WalletBirthday(DateTime.utc(2020));
      await tester.pumpWidget(
        _app(
          WalletBirthdayForm(
            network: BitcoinNetwork.mainnet,
            now: DateTime.utc(2026, 10, 28),
            onConfirmed: (birthday) {
              confirmed = true;
              result = birthday;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'I don’t know');
      expect(find.textContaining('about an hour and 12 GB'), findsOneWidget);
      expect(confirmed, isFalse);
      await _tap(tester, 'Scan from August 2017');
      expect(find.text('Scan from August 2017'), findsNothing);
      expect(confirmed, isTrue);
      expect(result, isNull);
      expect(find.textContaining('Scanning from'), findsNothing);
      final unknown = const ResolveBitcoinSyncCheckpointUsecase().execute(
        network: BitcoinNetwork.mainnet,
        now: DateTime.utc(2026, 10, 28),
      );
      expect(unknown, isA<Ok>());
      switch (unknown) {
        case Ok(:final value):
          expect(value, BitcoinSyncCheckpoint.segwit);
        case Err():
          fail('Unknown birthday must resolve offline');
      }
    },
  );

  for (final locale in ['en', 'fr', 'ar']) {
    testWidgets(
      'month names use $locale and earlier-only picker excludes the stored month',
      (tester) async {
        await tester.pumpWidget(
          _app(
            WalletBirthdayForm(
              network: BitcoinNetwork.mainnet,
              initialBirthday: DateTime.utc(2021, 3),
              latest: DateTime.utc(2021, 2),
              now: DateTime.utc(2026, 10, 28),
              onConfirmed: (_) {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final picker = tester.widget<BullMonthPicker>(
          find.byType(BullMonthPicker),
        );
        if (locale == 'en') {
          expect(picker.monthName(DateTime.utc(2021, 3)), 'March');
        }
        if (locale == 'fr') {
          expect(picker.monthName(DateTime.utc(2021, 3)), 'mars');
        }
        if (locale == 'ar') {
          expect(
            Directionality.of(tester.element(find.byType(BullMonthPicker))),
            TextDirection.rtl,
          );
        }
        final dropdowns = tester
            .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
            .toList();
        expect(dropdowns.first.items.first.value, 2021);
        expect(dropdowns.last.items.map((item) => item.value), [2, 1]);
        expect(find.text('I don’t know'), findsNothing);
      },
    );
  }
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final locale in ['en', 'ar']) {
      testWidgets(
        'unselected month and selected year share their reading edge ($theme, $locale)',
        (tester) async {
          await tester.pumpWidget(
            _app(
              WalletBirthdayForm(
                network: BitcoinNetwork.mainnet,
                now: DateTime.utc(2026, 10, 28),
                onConfirmed: (_) {},
              ),
              theme: theme,
              locale: locale,
            ),
          );
          final dropdowns = find.byType(BullDropdown<int>);
          final picker = tester.widget<BullMonthPicker>(
            find.byType(BullMonthPicker),
          );
          final month = tester.getRect(
            find.descendant(
              of: dropdowns.last,
              matching: find.text(picker.monthLabel),
            ),
          );
          final year = tester.getRect(
            find.descendant(of: dropdowns.first, matching: find.text('2026')),
          );
          expect(
            locale == 'ar' ? month.right : month.left,
            closeTo(locale == 'ar' ? year.right : year.left, 0.5),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
