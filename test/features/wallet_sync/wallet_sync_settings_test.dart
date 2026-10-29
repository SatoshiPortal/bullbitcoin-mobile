import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:bb_mobile/features/wallet_sync/presentation/wallet_sync_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_options_sheet.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_settings_section.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, WalletBirthday;
import 'package:transaction_sync/transaction_sync.dart'
    show
        BitcoinSyncCheckpoint,
        BitcoinSyncSource,
        BitcoinSyncScriptType,
        ResolveBitcoinSyncCheckpointUsecase,
        WalletTransactionSyncFailure;

class _Repository extends Fake implements WalletSyncSettingsRepository {
  WalletSyncSettings settings;
  final List<({WalletSyncSelection selection, bool earlierOnly})> writes = [];
  bool failReadAfterWrite = false;

  _Repository({
    BitcoinSyncSource source = BitcoinSyncSource.electrum,
    bool liquid = false,
  }) : settings = WalletSyncSettings(
         walletId: 'public-wallet',
         isLiquid: liquid,
         network: BitcoinNetwork.mainnet,
         source: source,
         birthday: DateTime.utc(2021, 3),
       );

  @override
  Future<Result<WalletSyncSettings, WalletFailure>> getSyncSettings(
    String walletId,
  ) async => failReadAfterWrite && writes.isNotEmpty
      ? const Err(WalletStorageFailure())
      : Ok(settings);

  @override
  Future<Result<void, WalletFailure>> updateBitcoinSyncSettings({
    required String walletId,
    required BitcoinSyncSource source,
    required WalletBirthday? birthday,
    bool earlierOnly = false,
  }) async {
    writes.add((
      selection: WalletSyncSelection(source: source, birthday: birthday),
      earlierOnly: earlierOnly,
    ));
    settings = WalletSyncSettings(
      walletId: walletId,
      isLiquid: false,
      network: settings.network,
      source: source,
      birthday: birthday?.dateTime,
    );
    return const Ok(null);
  }
}

Widget _app(
  _Repository repository, {
  String locale = 'en',
  AppThemeType theme = AppThemeType.light,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.themeData(theme),
  home: Scaffold(
    body: SingleChildScrollView(
      child: WalletSyncSettingsSection(
        walletId: repository.settings.walletId,
        load: LoadWalletSyncSettingsUsecase(repository: repository),
        save: SaveWalletSyncSettingsUsecase(
          start: _StartSync(),
          repository: repository,
        ),
        choose:
            (
              context, {
              network,
              askScriptType = false,
              initial = const WalletSyncSelection(),
              changingSource = false,
            }) => BullBottomSheet.show<WalletSyncSelection>(
              context: context,
              child: WalletSyncOptionsSheet(
                network: network ?? BitcoinNetwork.mainnet,
                initial: initial,
                changingSource: changingSource,
              ),
            ),
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  // Review B reproductions: the seven-day/monthly policy can reach the
  // script floor even when the birthday month is later than activation.
  for (final (type, network, birthday) in [
    (
      BitcoinSyncScriptType.segwitV0,
      BitcoinNetwork.mainnet,
      DateTime.utc(2017, 9),
    ),
    (
      BitcoinSyncScriptType.preSegwit,
      BitcoinNetwork.mainnet,
      DateTime.utc(2012, 3),
    ),
    (
      BitcoinSyncScriptType.taproot,
      BitcoinNetwork.mainnet,
      DateTime.utc(2021, 12),
    ),
    (
      BitcoinSyncScriptType.segwitV0,
      BitcoinNetwork.testnet,
      DateTime.utc(2021, 3),
    ),
    (
      BitcoinSyncScriptType.preSegwit,
      BitcoinNetwork.signet,
      DateTime.utc(2021, 3),
    ),
    (
      BitcoinSyncScriptType.taproot,
      BitcoinNetwork.regtest,
      DateTime.utc(2021, 3),
    ),
  ]) {
    for (final locale in ['en', 'fr']) {
      testWidgets('resolved floor disables earlier action $type $network/$locale', (
        tester,
      ) async {
        final checkpoint = const ResolveBitcoinSyncCheckpointUsecase().execute(
          network: network,
          scriptType: type,
          birthday: birthday,
          now: DateTime.utc(2026, 10, 29),
        );
        final floor = network.isMainnet
            ? type.floor
            : BitcoinSyncCheckpoint.genesis(network);
        expect(
          checkpoint,
          isA<Ok<BitcoinSyncCheckpoint, WalletTransactionSyncFailure>>(),
        );
        if (checkpoint case Ok(:final value)) {
          expect(value, floor);
        }
        final repository = _Repository();
        repository.settings = WalletSyncSettings(
          walletId: 'public-wallet',
          isLiquid: false,
          network: network,
          source: BitcoinSyncSource.compactBlockFilters,
          birthday: birthday,
          scanScriptType: type,
        );
        await tester.pumpWidget(_app(repository, locale: locale));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(WalletSyncSettingsSection));
        final loc = AppLocalizations.of(context);
        final action = find.widgetWithText(BullButton, loc.syncEarlierDate);
        expect(
          tester.widget<BullButton>(action).disabled,
          isTrue,
          reason:
              'Already at effective floor: no earlier month can extend history',
        );
        expect(
          find.text(
            locale == 'en'
                ? network.isMainnet
                      ? 'History already starts at the earliest supported point for this wallet type.'
                      : 'History already starts at this network’s genesis block.'
                : network.isMainnet
                ? 'L’historique commence déjà au premier point pris en charge pour ce type de portefeuille.'
                : 'L’historique commence déjà au bloc de genèse de ce réseau.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(WalletBirthdayForm), findsNothing);
        expect(repository.writes, isEmpty);
      });
    }
  }

  for (final (type, birthday, earlierLabel) in [
    (
      BitcoinSyncScriptType.segwitV0,
      DateTime.utc(2017, 9, 8),
      'Use August 2017',
    ),
    (
      BitcoinSyncScriptType.preSegwit,
      DateTime.utc(2012, 3, 8),
      'Use February 2012',
    ),
    (
      BitcoinSyncScriptType.taproot,
      DateTime.utc(2021, 12, 8),
      'Use November 2021',
    ),
  ]) {
    testWidgets(
      'checkpoint above $type floor enables an effective earlier month',
      (tester) async {
        const resolver = ResolveBitcoinSyncCheckpointUsecase();
        final current = resolver.execute(
          network: BitcoinNetwork.mainnet,
          scriptType: type,
          birthday: birthday,
          now: DateTime.utc(2026, 10, 29),
        );
        final repository = _Repository();
        repository.settings = WalletSyncSettings(
          walletId: 'public-wallet',
          isLiquid: false,
          network: BitcoinNetwork.mainnet,
          source: BitcoinSyncSource.compactBlockFilters,
          birthday: birthday,
          scanScriptType: type,
        );
        await tester.pumpWidget(_app(repository));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BullButton>(
                find.widgetWithText(BullButton, 'Scan from an earlier date'),
              )
              .disabled,
          isFalse,
        );
        expect(find.textContaining('History already starts'), findsNothing);
        await _tap(tester, 'Scan from an earlier date');
        await _tap(tester, earlierLabel);
        expect(repository.writes.single.earlierOnly, isTrue);
        final earlier = resolver.execute(
          network: BitcoinNetwork.mainnet,
          scriptType: type,
          birthday: repository.writes.single.selection.birthday?.dateTime,
          now: DateTime.utc(2026, 10, 29),
        );
        expect(
          (current, earlier),
          isA<
            (
              Ok<BitcoinSyncCheckpoint, WalletTransactionSyncFailure>,
              Ok<BitcoinSyncCheckpoint, WalletTransactionSyncFailure>,
            )
          >(),
        );
        if ((current, earlier) case (
          Ok(value: final current),
          Ok(value: final earlier),
        )) {
          expect(current.height, greaterThan(type.floor.height));
          expect(earlier.height, lessThan(current.height));
        }
      },
    );
  }

  for (final (type, history) in [
    (BitcoinSyncScriptType.taproot, 'November 2021'),
    (BitcoinSyncScriptType.segwitV0, 'August 2017'),
    (BitcoinSyncScriptType.preSegwit, 'February 2012'),
  ]) {
    testWidgets('unknown $type history and source changes retain script kind', (
      tester,
    ) async {
      final repository = _Repository();
      repository.settings = WalletSyncSettings(
        walletId: 'public-wallet',
        isLiquid: false,
        network: BitcoinNetwork.mainnet,
        source: BitcoinSyncSource.electrum,
        birthday: null,
        scanScriptType: type,
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.textContaining(history), findsOneWidget);
      expect(
        tester
            .widget<BullButton>(
              find.widgetWithText(BullButton, 'Scan from an earlier date'),
            )
            .disabled,
        isTrue,
      );
      await _tap(tester, 'Fast server sync');
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      expect(
        tester
            .widget<WalletBirthdayForm>(find.byType(WalletBirthdayForm))
            .scriptType,
        type,
      );
    });
  }

  testWidgets('clock rollback does not strand the source chooser', (
    tester,
  ) async {
    final repository = _Repository();
    repository.settings = WalletSyncSettings(
      walletId: 'public-wallet',
      isLiquid: false,
      network: BitcoinNetwork.mainnet,
      source: BitcoinSyncSource.electrum,
      birthday: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _tap(tester, 'Fast server sync');
    expect(find.text('Private peer-to-peer sync'), findsOneWidget);
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final locale in ['en', 'fr', 'ar']) {
      for (final liquid in [false, true]) {
        testWidgets(
          'sync rows match wallet details in $theme/$locale liquid=$liquid',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(393, 851));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final repository = _Repository(
              source: BitcoinSyncSource.compactBlockFilters,
              liquid: liquid,
            );
            await tester.pumpWidget(
              _app(repository, theme: theme, locale: locale),
            );
            await tester.pumpAndSettle();
            final context = tester.element(
              find.byType(WalletSyncSettingsSection),
            );
            final loc = AppLocalizations.of(context);
            final header = tester.widget<BullText>(
              find.widgetWithText(BullText, loc.syncSectionTitle),
            );
            expect(header.style, context.bullText.titleSmall);
            expect(header.color, context.bull.secondary);
            final label = tester.widget<BullText>(
              find.widgetWithText(BullText, loc.syncMethod),
            );
            expect(label.style, context.bullText.bodyLarge);
            expect(label.color, context.bull.textMuted);
            final value = liquid ? loc.syncServerOnly : loc.syncPrivateTitle;
            final valueText = tester.widget<BullText>(
              find.widgetWithText(BullText, value),
            );
            expect(valueText.style, context.bullText.bodyMedium);
            expect(valueText.color, context.bull.onSurface);
            expect(
              find.byWidgetPredicate(
                (w) => w is BullButton && w.size == BullButtonSize.large,
              ),
              findsNothing,
            );
            if (liquid) {
              expect(find.byType(BullIcon), findsNothing);
              expect(find.text(loc.syncHistoryStarts), findsNothing);
              expect(find.text(loc.syncEarlierDate), findsNothing);
              expect(
                find.byWidgetPredicate(
                  (w) => w is Semantics && w.properties.button == true,
                ),
                findsNothing,
              );
            } else {
              final chevron = find.byWidgetPredicate(
                (w) => w is BullIcon && w.icon == BullIcons.chevronRight,
              );
              expect(chevron, findsOneWidget);
              final valueRect = tester.getRect(
                find.widgetWithText(BullText, value),
              );
              final chevronX = tester.getCenter(chevron).dx;
              expect(
                chevronX,
                locale == 'ar'
                    ? lessThan(valueRect.left)
                    : greaterThan(valueRect.right),
              );
              final earlier = tester.widget<BullButton>(
                find.widgetWithText(BullButton, loc.syncEarlierDate),
              );
              expect(earlier.size, BullButtonSize.small);
              expect(earlier.bgColor, context.bull.transparent);
              expect(earlier.outlined, isFalse);
              await _tap(tester, value);
              expect(find.byType(WalletSyncOptionsSheet), findsOneWidget);
            }
            expect(repository.writes, isEmpty);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('earlier-date sheet has a heading and spaced reassurance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_Repository(source: BitcoinSyncSource.compactBlockFilters)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'Scan from an earlier date');
    final title = find
        .widgetWithText(BullText, 'Scan from an earlier date')
        .last;
    final context = tester.element(title);
    expect(
      tester.widget<BullText>(title).style,
      context.bullText.headlineMedium,
    );
    final reassurance = find.text(
      'Your existing history stays available while earlier transactions are added.',
    );
    expect(reassurance, findsOneWidget);
    expect(
      tester.getTopLeft(reassurance).dy - tester.getBottomLeft(title).dy,
      greaterThanOrEqualTo(BullSpacing.md),
    );
    expect(
      tester.getTopLeft(find.byType(WalletBirthdayForm)).dy -
          tester.getBottomLeft(reassurance).dy,
      greaterThanOrEqualTo(BullSpacing.md),
    );
    expect(find.text('When did you start using this wallet?'), findsNothing);
  });

  testWidgets('switching wallets loads the new wallet settings', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Fast server sync'), findsOneWidget);
    repository.settings = WalletSyncSettings(
      walletId: 'another-public-wallet',
      isLiquid: false,
      network: BitcoinNetwork.mainnet,
      source: BitcoinSyncSource.compactBlockFilters,
      birthday: DateTime.utc(2020, 1),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Private peer-to-peer sync'), findsOneWidget);
    expect(find.text('January 2020'), findsOneWidget);
    expect(repository.writes, isEmpty);
  });

  testWidgets(
    'server to private warns and waits for birthday before saving both',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _tap(tester, 'Fast server sync');
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      expect(
        find.textContaining('switching protects future activity only.'),
        findsOneWidget,
      );
      expect(repository.writes, isEmpty);
      await _tap(tester, 'Continue');
      expect(
        repository.writes.single.selection.source,
        BitcoinSyncSource.compactBlockFilters,
      );
      expect(
        repository.writes.single.selection.birthday?.dateTime,
        DateTime.utc(2021, 3),
      );
    },
  );

  testWidgets(
    'private to server discloses past addresses; cancel never writes',
    (tester) async {
      final repository = _Repository(
        source: BitcoinSyncSource.compactBlockFilters,
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Fast server sync');
      await _tap(tester, 'Continue');
      expect(
        find.textContaining('including past ones. Switch?'),
        findsOneWidget,
      );
      await _tap(tester, 'Cancel');
      expect(repository.writes, isEmpty);
      await _tap(tester, 'Continue');
      await _tap(tester, 'Continue');
      expect(
        repository.writes.single.selection.source,
        BitcoinSyncSource.electrum,
      );
      expect(
        repository.writes.single.selection.birthday?.dateTime,
        DateTime.utc(2021, 3),
      );
    },
  );

  testWidgets(
    'keeping private source preserves birthday and does not reopen its picker',
    (tester) async {
      final repository = _Repository(
        source: BitcoinSyncSource.compactBlockFilters,
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _tap(tester, 'Private peer-to-peer sync');
      await _tap(tester, 'Continue');
      expect(find.byType(WalletBirthdayForm), findsNothing);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'rescan offers only earlier months and saves an earlier-only request',
    (tester) async {
      final repository = _Repository(
        source: BitcoinSyncSource.compactBlockFilters,
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _tap(tester, 'Scan from an earlier date');
      final monthField = tester
          .widgetList<BullDropdown<int>>(find.byType(BullDropdown<int>))
          .last;
      expect(monthField.items.map((item) => item.value), [2, 1]);
      await _tap(tester, 'Use February 2021');
      expect(repository.writes.single.earlierOnly, isTrue);
      expect(
        repository.writes.single.selection.birthday?.dateTime,
        DateTime.utc(2021, 2),
      );
    },
  );

  testWidgets('Liquid has read-only server sync', (tester) async {
    final repository = _Repository(liquid: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Server sync'), findsOneWidget);
    expect(find.byType(BullButton), findsNothing);
    expect(repository.writes, isEmpty);
  });

  testWidgets('earliest supported month cannot open an empty rescan picker', (
    tester,
  ) async {
    final repository = _Repository();
    repository.settings = WalletSyncSettings(
      walletId: repository.settings.walletId,
      isLiquid: false,
      network: BitcoinNetwork.mainnet,
      source: BitcoinSyncSource.compactBlockFilters,
      birthday: DateTime.utc(2009, 1),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final action = tester.widget<BullButton>(
      find.ancestor(
        of: find.text('Scan from an earlier date'),
        matching: find.byType(BullButton),
      ),
    );
    expect(action.disabled, isTrue);
    expect(repository.writes, isEmpty);
  });

  testWidgets('cancelling an earlier rescan preserves stored history', (
    tester,
  ) async {
    final repository = _Repository(
      source: BitcoinSyncSource.compactBlockFilters,
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _tap(tester, 'Scan from an earlier date');
    await _tap(tester, 'Cancel');
    expect(find.byType(WalletBirthdayForm), findsNothing);
    expect(find.text('March 2021'), findsOneWidget);
    expect(repository.writes, isEmpty);
  });

  test(
    'failed post-save read never presents the previous private source as current',
    () async {
      final repository = _Repository(
        source: BitcoinSyncSource.compactBlockFilters,
      )..failReadAfterWrite = true;
      final cubit = WalletSyncSettingsCubit(
        walletId: 'public-wallet',
        load: LoadWalletSyncSettingsUsecase(repository: repository),
        save: SaveWalletSyncSettingsUsecase(
          start: _StartSync(),
          repository: repository,
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.save(const WalletSyncSelection());
      expect(repository.settings.source, BitcoinSyncSource.electrum);
      expect(cubit.state, isA<WalletSyncSettingsUnavailable>());
    },
  );
}

class _StartSync extends Fake implements StartWalletSyncUsecase {
  @override
  void execute(String walletId, {bool policyChanged = false}) {}
}
