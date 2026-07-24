import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetBitcoinSyncBackendUsecase extends Mock
    implements GetBitcoinSyncBackendUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

Wallet _wallet({String id = 'w1'}) => Wallet(
  origin: id,
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

/// Focused tests for `WalletRouter`'s post-wallet-ready navigation
/// decision, shared by every onboarding/recovery/import flow that lands a
/// newly ready wallet: a compact-block-filter (CBF) wallet is diverted to
/// the dedicated `walletInitialSync` route; every other case (Electrum, or
/// a lookup failure) preserves the pre-existing straight-to-`walletHome`
/// navigation.
void main() {
  late _MockGetBitcoinSyncBackendUsecase getBackendUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  String? landedRouteName;
  Map<String, String> landedPathParameters = const {};

  setUp(() {
    getBackendUsecase = _MockGetBitcoinSyncBackendUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    landedRouteName = null;
    landedPathParameters = const {};
    locator.registerFactory<GetBitcoinSyncBackendUsecase>(
      () => getBackendUsecase,
    );
    locator.registerFactory<GetWalletsUsecase>(() => getWalletsUsecase);
  });

  tearDown(() async {
    await locator.reset();
  });

  Widget wrap(Future<void> Function(BuildContext) action) {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => action(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          name: WalletRoute.walletHome.name,
          path: WalletRoute.walletHome.path,
          builder: (context, state) {
            landedRouteName = WalletRoute.walletHome.name;
            return const Scaffold(body: Text('wallet home'));
          },
        ),
        GoRoute(
          name: WalletRoute.walletInitialSync.name,
          path: WalletRoute.walletInitialSync.path,
          builder: (context, state) {
            landedRouteName = WalletRoute.walletInitialSync.name;
            landedPathParameters = state.pathParameters;
            return const Scaffold(body: Text('initial sync'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('goToWalletHomeOrInitialSync', () {
    testWidgets('routes to the dedicated initial sync screen for a CBF '
        'wallet', (tester) async {
      when(() => getBackendUsecase.execute(walletId: 'w1')).thenAnswer(
        (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
      );

      await tester.pumpWidget(
        wrap(
          (context) => WalletRouter.goToWalletHomeOrInitialSync(
            context,
            walletId: 'w1',
            isRecoveryOrImport: true,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletInitialSync.name);
      expect(landedPathParameters['walletId'], 'w1');
    });

    testWidgets('preserves the straight-to-wallet-home navigation for an '
        'Electrum wallet', (tester) async {
      when(
        () => getBackendUsecase.execute(walletId: 'w1'),
      ).thenAnswer((_) async => const Ok(BitcoinSyncBackend.electrum));

      await tester.pumpWidget(
        wrap(
          (context) => WalletRouter.goToWalletHomeOrInitialSync(
            context,
            walletId: 'w1',
            isRecoveryOrImport: true,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
    });

    testWidgets('preserves the straight-to-wallet-home navigation when the '
        'backend lookup fails, never blocking the user behind a routing '
        'error', (tester) async {
      when(
        () => getBackendUsecase.execute(walletId: 'w1'),
      ).thenAnswer((_) async => const Err(WalletSyncWalletNotFoundFailure()));

      await tester.pumpWidget(
        wrap(
          (context) => WalletRouter.goToWalletHomeOrInitialSync(
            context,
            walletId: 'w1',
            isRecoveryOrImport: true,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
    });

    testWidgets('bypasses straight to wallet home for a new wallet '
        '(isRecoveryOrImport: false), never even looking up the backend — '
        'this dedicated screen is never shown for a newly created wallet', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          (context) => WalletRouter.goToWalletHomeOrInitialSync(
            context,
            walletId: 'w1',
            isRecoveryOrImport: false,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
      verifyNever(
        () => getBackendUsecase.execute(walletId: any(named: 'walletId')),
      );
    });
  });

  group('goToWalletHomeOrInitialSyncForDefaultBitcoinWallet', () {
    testWidgets('looks up the default Bitcoin wallet fresh from storage and '
        'routes to initial sync for a CBF wallet', (tester) async {
      when(
        () => getWalletsUsecase.execute(onlyDefaults: true, onlyBitcoin: true),
      ).thenAnswer((_) async => [_wallet(id: 'default-btc')]);
      when(() => getBackendUsecase.execute(walletId: 'default-btc')).thenAnswer(
        (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
      );

      await tester.pumpWidget(
        wrap(
          (context) =>
              WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
                context,
                isRecoveryOrImport: true,
              ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletInitialSync.name);
      expect(landedPathParameters['walletId'], 'default-btc');
    });

    testWidgets('falls back to wallet home when no default Bitcoin wallet '
        'is found', (tester) async {
      when(
        () => getWalletsUsecase.execute(onlyDefaults: true, onlyBitcoin: true),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        wrap(
          (context) =>
              WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
                context,
                isRecoveryOrImport: true,
              ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
      verifyNever(
        () => getBackendUsecase.execute(walletId: any(named: 'walletId')),
      );
    });

    testWidgets('falls back to wallet home when the wallet lookup throws', (
      tester,
    ) async {
      when(
        () => getWalletsUsecase.execute(onlyDefaults: true, onlyBitcoin: true),
      ).thenThrow(Exception('boom'));

      await tester.pumpWidget(
        wrap(
          (context) =>
              WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
                context,
                isRecoveryOrImport: true,
              ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
    });

    testWidgets('bypasses straight to wallet home for a new wallet '
        '(isRecoveryOrImport: false), never looking up any wallet — this '
        'dedicated screen is never shown for a newly created wallet', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          (context) =>
              WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
                context,
                isRecoveryOrImport: false,
              ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(landedRouteName, WalletRoute.walletHome.name);
      verifyNever(
        () => getWalletsUsecase.execute(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
        ),
      );
      verifyNever(
        () => getBackendUsecase.execute(walletId: any(named: 'walletId')),
      );
    });
  });
}
