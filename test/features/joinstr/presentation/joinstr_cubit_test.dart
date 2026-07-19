import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/get_joinstr_settings_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_coins_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockGetSettings extends Mock implements GetJoinstrSettingsUsecase {}

class _MockSaveRelay extends Mock implements SaveJoinstrRelayUsecase {}

class _MockListPools extends Mock implements ListJoinstrPoolsUsecase {}

class _MockListCoins extends Mock implements ListJoinstrCoinsUsecase {}

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

const _coin = JoinstrCoin(txid: 'a', vout: 0, valueSat: 100000);

void main() {
  late _MockGetWallets getWallets;
  late _MockGetSettings getSettings;
  late _MockSaveRelay saveRelay;
  late _MockListPools listPools;
  late _MockListCoins listCoins;
  late _MockJoinPool joinPool;
  late _MockInitiatePool initiatePool;

  JoinstrCubit build() => JoinstrCubit(
    getWalletsUsecase: getWallets,
    getJoinstrSettingsUsecase: getSettings,
    saveJoinstrRelayUsecase: saveRelay,
    listJoinstrPoolsUsecase: listPools,
    listJoinstrCoinsUsecase: listCoins,
    joinJoinstrPoolUsecase: joinPool,
    initiateJoinstrPoolUsecase: initiatePool,
  );

  setUpAll(() {
    registerFallbackValue(_wallet());
    registerFallbackValue(_pool(100000));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    getWallets = _MockGetWallets();
    getSettings = _MockGetSettings();
    saveRelay = _MockSaveRelay();
    listPools = _MockListPools();
    listCoins = _MockListCoins();
    joinPool = _MockJoinPool();
    initiatePool = _MockInitiatePool();

    when(() => getSettings.execute()).thenAnswer(
      (_) async => const JoinstrSettings(relay: 'wss://nos.lol', history: []),
    );
    when(
      () => listCoins.execute(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => const [_coin]);
    when(() => listPools.execute()).thenAnswer((_) async => []);
  });

  Future<JoinstrCubit> loadedCubit() async {
    when(
      () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
    ).thenAnswer((_) async => [_wallet()]);
    final cubit = build();
    await cubit.load();
    return cubit;
  }

  group('load', () {
    test('errors when no local-signer wallet is available', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer((_) async => [_wallet(signer: SignerEntity.none)]);

      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, JoinstrStatus.error);
      expect(cubit.state.error?.issue, JoinstrIssue.watchOnlyWallet);
    });

    test(
      'runs once when called concurrently, e.g. from route rebuilds',
      () async {
        when(
          () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
        ).thenAnswer((_) async => [_wallet()]);

        final cubit = build();
        await Future.wait([cubit.load(), cubit.load()]);

        verify(() => getSettings.execute()).called(1);
        verify(() => listPools.execute()).called(1);
      },
    );

    test('selects a supported testnet wallet and loads coins', () async {
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer(
        (_) async => [
          _wallet(origin: 'w-mainnet', network: Network.bitcoinMainnet),
          _wallet(origin: 'w-testnet', network: Network.bitcoinTestnet),
        ],
      );

      final cubit = build();
      await cubit.load();

      expect(cubit.state.wallet?.id, 'w-testnet');
      expect(cubit.state.coins, [_coin]);
      expect(cubit.state.error, isNull);
    });
  });

  group('initiatePool', () {
    test('requires a selected coin', () async {
      final cubit = await loadedCubit();
      // no coin selected
      await cubit.initiatePool();
      expect(cubit.state.error?.issue, JoinstrIssue.invalidPoolConfig);
      verifyNever(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: any(named: 'denominationSat'),
          peers: any(named: 'peers'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
          inputOutpoint: any(named: 'inputOutpoint'),
          maxDuration: any(named: 'maxDuration'),
        ),
      );
    });

    test('derives the denomination from the coin and advances the round '
        'through the progress stream', () async {
      final cubit = await loadedCubit();
      when(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: any(named: 'denominationSat'),
          peers: any(named: 'peers'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
          inputOutpoint: any(named: 'inputOutpoint'),
          maxDuration: any(named: 'maxDuration'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.outputRegistration),
          JoinstrProgress(step: JoinstrRoundStep.done, txId: 'txid-abc'),
        ]),
      );

      cubit.selectCoin(_coin);
      await cubit.initiatePool();

      // denomination = coin value (100000) - surplus (fee 1 -> 500) = 99500
      verify(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: 99500,
          peers: 2,
          feeRateSatPerVb: 1,
          inputOutpoint: 'a:0',
          maxDuration: any(named: 'maxDuration'),
        ),
      ).called(1);

      final round = cubit.state.rounds.single;
      expect(round.isBroadcast, isTrue);
      expect(round.txId, 'txid-abc');
      expect(round.initiated, isTrue);
    });
  });

  group('joinPool', () {
    test('runs the join stream to a broadcast round', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
          inputOutpoint: any(named: 'inputOutpoint'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.done, txId: 'txid-join'),
        ]),
      );

      await cubit.joinPool(_pool(99500), _coin);

      final round = cubit.state.rounds.single;
      expect(round.isBroadcast, isTrue);
      expect(round.txId, 'txid-join');
      expect(round.initiated, isFalse);
    });

    test('marks the round failed on a failed progress event', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
          inputOutpoint: any(named: 'inputOutpoint'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.failed, errorMessage: 'boom'),
        ]),
      );

      await cubit.joinPool(_pool(99500), _coin);

      final round = cubit.state.rounds.single;
      expect(round.isFailed, isTrue);
    });
  });

  group('round lifecycle', () {
    Future<JoinstrCubit> joinWith(List<JoinstrProgress> updates) async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
          inputOutpoint: any(named: 'inputOutpoint'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(updates));
      await cubit.joinPool(_pool(99500), _coin);
      return cubit;
    }

    test('a late failure keeps the step the round had reached', () async {
      final cubit = await joinWith(const [
        JoinstrProgress(step: JoinstrRoundStep.posting),
        JoinstrProgress(step: JoinstrRoundStep.inputRegistration),
        JoinstrProgress(step: JoinstrRoundStep.failed, errorMessage: 'boom'),
      ]);

      final round = cubit.state.rounds.single;
      expect(round.isFailed, isTrue);
      expect(round.step, JoinstrRoundStep.inputRegistration);
    });

    test('completion keeps the step the round had reached', () async {
      final cubit = await joinWith(const [
        JoinstrProgress(step: JoinstrRoundStep.mined),
        JoinstrProgress(step: JoinstrRoundStep.done, txId: 'txid-abc'),
      ]);

      final round = cubit.state.rounds.single;
      expect(round.isBroadcast, isTrue);
      expect(round.step, JoinstrRoundStep.mined);
    });

    test('a stream that ends without a result fails the round instead of '
        'leaving it waiting and its coin reserved forever', () async {
      final cubit = await joinWith(const [
        JoinstrProgress(step: JoinstrRoundStep.outputRegistration),
      ]);

      final round = cubit.state.rounds.single;
      expect(round.isWaiting, isFalse);
      expect(round.isFailed, isTrue);
      expect(round.step, JoinstrRoundStep.outputRegistration);
      expect(cubit.state.busyOutpoints, isEmpty);
    });

    test('done without a txid is a failure, not an empty broadcast', () async {
      final cubit = await joinWith(const [
        JoinstrProgress(step: JoinstrRoundStep.done),
      ]);

      final round = cubit.state.rounds.single;
      expect(round.isBroadcast, isFalse);
      expect(round.isFailed, isTrue);
    });
  });
}
