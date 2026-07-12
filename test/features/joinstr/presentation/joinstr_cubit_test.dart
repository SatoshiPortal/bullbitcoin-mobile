import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockListPools extends Mock implements ListJoinstrPoolsUsecase {}

class _MockJoinPool extends Mock implements JoinJoinstrPoolUsecase {}

class _MockInitiatePool extends Mock implements InitiateJoinstrPoolUsecase {}

Wallet _wallet({
  String origin = 'w-testnet',
  Network network = Network.bitcoinTestnet,
  ScriptType scriptType = ScriptType.bip84,
  SignerEntity signer = SignerEntity.local,
}) {
  return Wallet(
    origin: origin,
    network: network,
    xpubFingerprint: 'ffffffff',
    masterFingerprint: 'eeeeeeee',
    scriptType: scriptType,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/0/*)',
    internalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/1/*)',
    signer: signer,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

JoinstrPool _pool(int denominationSat) => JoinstrPool(
  id: 'pool-$denominationSat',
  rawJson: '{}',
  denominationSat: denominationSat,
  peers: 2,
  expiresAtUnixSec: 1793500000,
  relay: 'wss://nos.lol',
  feeRateSatPerVb: 1,
  publicKey: 'pk',
);

void main() {
  late _MockGetWallets getWallets;
  late _MockListPools listPools;
  late _MockJoinPool joinPool;
  late _MockInitiatePool initiatePool;

  JoinstrCubit build() => JoinstrCubit(
    getWalletsUsecase: getWallets,
    listJoinstrPoolsUsecase: listPools,
    joinJoinstrPoolUsecase: joinPool,
    initiateJoinstrPoolUsecase: initiatePool,
  );

  setUpAll(() {
    registerFallbackValue(_wallet());
    registerFallbackValue(_pool(100000));
  });

  setUp(() {
    getWallets = _MockGetWallets();
    listPools = _MockListPools();
    joinPool = _MockJoinPool();
    initiatePool = _MockInitiatePool();
  });

  group('load', () {
    test('errors when no local-signer wallet is available', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer((_) async => [_wallet(signer: SignerEntity.none)]);

      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, JoinstrStatus.error);
      expect(cubit.state.error?.issue, JoinstrIssue.watchOnlyWallet);
      verifyNever(() => listPools.execute());
    });

    test('selects a supported testnet wallet over a mainnet one', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer(
        (_) async => [
          _wallet(origin: 'w-mainnet', network: Network.bitcoinMainnet),
          _wallet(origin: 'w-testnet', network: Network.bitcoinTestnet),
        ],
      );
      when(() => listPools.execute()).thenAnswer((_) async => []);

      final cubit = build();
      await cubit.load();

      expect(cubit.state.wallet?.id, 'w-testnet');
      expect(cubit.state.error, isNull);
      expect(cubit.state.status, JoinstrStatus.idle);
    });

    test(
      'surfaces mainnetNotSupported when only a mainnet wallet exists',
      () async {
        when(
          () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
        ).thenAnswer((_) async => [_wallet(network: Network.bitcoinMainnet)]);

        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, JoinstrStatus.error);
        expect(cubit.state.error?.issue, JoinstrIssue.mainnetNotSupported);
      },
    );
  });

  group('refreshPools', () {
    test('moves to idle with the usecase result', () async {
      when(
        () => listPools.execute(),
      ).thenAnswer((_) async => [_pool(100000), _pool(500000)]);

      final cubit = build();
      await cubit.refreshPools();

      expect(cubit.state.status, JoinstrStatus.idle);
      expect(cubit.state.pools.map((p) => p.denominationSat), [100000, 500000]);
    });
  });

  group('initiatePool validation', () {
    test('rejects an out-of-range config before calling the usecase', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer((_) async => [_wallet()]);
      when(() => listPools.execute()).thenAnswer((_) async => []);

      final cubit = build();
      await cubit.load();
      cubit.peersChanged('1'); // below the 2-peer minimum

      await cubit.initiatePool();

      expect(cubit.state.status, JoinstrStatus.error);
      expect(cubit.state.error?.issue, JoinstrIssue.invalidPoolConfig);
      verifyNever(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: any(named: 'denominationSat'),
          peers: any(named: 'peers'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
        ),
      );
    });
  });

  group('joinPool', () {
    test('runs then reports the broadcast txid', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer((_) async => [_wallet()]);
      when(() => listPools.execute()).thenAnswer((_) async => []);
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenAnswer((_) async => 'txid-abc');

      final cubit = build();
      await cubit.load();
      await cubit.joinPool(_pool(100000));

      expect(cubit.state.status, JoinstrStatus.done);
      expect(cubit.state.txId, 'txid-abc');
    });

    test(
      'maps a JoinstrException from the usecase to the error state',
      () async {
        when(
          () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
        ).thenAnswer((_) async => [_wallet()]);
        when(() => listPools.execute()).thenAnswer((_) async => []);
        when(
          () => joinPool.execute(
            wallet: any(named: 'wallet'),
            pool: any(named: 'pool'),
          ),
        ).thenThrow(JoinstrException(JoinstrIssue.noEligibleCoin));

        final cubit = build();
        await cubit.load();
        await cubit.joinPool(_pool(100000));

        expect(cubit.state.status, JoinstrStatus.error);
        expect(cubit.state.error?.issue, JoinstrIssue.noEligibleCoin);
      },
    );
  });
}
