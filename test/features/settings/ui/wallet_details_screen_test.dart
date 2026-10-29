import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/watch_wallet_sync_status_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok, Result;

class _MockWalletBloc extends Mock implements WalletBloc {}

class _SyncNetwork extends Fake implements GetWalletSyncNetworkUsecase {}

class _SaveSyncSettings extends Fake implements SaveWalletSyncSettingsUsecase {}

class _LoadSyncSettings extends Fake implements LoadWalletSyncSettingsUsecase {
  @override
  Future<Result<WalletSyncSettings, WalletSyncOptionsFailure>> execute(
    String walletId,
  ) async => Ok(
    WalletSyncSettings(
      walletId: walletId,
      isLiquid: false,
      network: BitcoinNetwork.mainnet,
      source: BitcoinSyncSource.electrum,
      birthday: DateTime.utc(2021, 3),
    ),
  );
}

Wallet _wallet({required bool isDefault}) => Wallet(
  origin: 'wallet-id',
  label: 'Savings',
  network: Network.bitcoinMainnet,
  isDefault: isDefault,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub-test',
  externalPublicDescriptor: 'wpkh(xpub-test/0/*)',
  internalPublicDescriptor: 'wpkh(xpub-test/1/*)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

Future<void> _pumpScreen(WidgetTester tester, {required bool isDefault}) async {
  final walletBloc = _MockWalletBloc();
  final state = WalletState(
    status: WalletStatus.success,
    wallets: [_wallet(isDefault: isDefault)],
  );
  when(() => walletBloc.state).thenReturn(state);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());

  await tester.pumpWidget(
    BlocProvider<WalletBloc>.value(
      value: walletBloc,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WalletDetailsScreen(walletId: 'wallet-id'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await locator.reset();
    locator.registerSingleton<WalletSyncFacade>(
      WalletSyncFacade(
        watch: _WatchSync(),
        start: _StartSync(),
        network: _SyncNetwork(),
        load: _LoadSyncSettings(),
        save: _SaveSyncSettings(),
      ),
    );
  });
  tearDown(locator.reset);

  testWidgets('shows wallet information directly and ends with Addresses', (
    tester,
  ) async {
    await _pumpScreen(tester, isDefault: false);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('abcd1234'), findsOneWidget);
    expect(find.text('xpub-test'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sync'), 200);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Fast server sync'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Addresses'), 200);
    expect(find.text('Addresses'), findsOneWidget);
  });

  testWidgets('only offers wallet deletion for a non-default wallet', (
    tester,
  ) async {
    await _pumpScreen(tester, isDefault: true);
    final deletionIcon = find.byWidgetPredicate(
      (widget) => widget is BullIcon && widget.icon == BullIcons.deleteOutline,
    );
    expect(deletionIcon, findsNothing);

    await _pumpScreen(tester, isDefault: false);
    expect(deletionIcon, findsOneWidget);
  });
}

class _StartSync extends Fake implements StartWalletSyncUsecase {
  @override
  void execute(String walletId, {bool policyChanged = false}) {}
}

class _WatchSync extends Fake implements WatchWalletSyncStatusUsecase {
  @override
  Stream<WalletSyncStatus> execute(String walletId) => Stream.value(
    const WalletSyncStatus(
      source: BitcoinSyncSource.electrum,
      recoveryRequired: false,
    ),
  );
}
