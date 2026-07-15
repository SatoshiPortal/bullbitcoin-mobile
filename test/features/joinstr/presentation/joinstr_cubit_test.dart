import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/get_joinstr_settings_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
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
  late _MockGetSettings getSettings;
  late _MockSaveRelay saveRelay;
  late _MockListPools listPools;
  late _MockJoinPool joinPool;
  late _MockInitiatePool initiatePool;

  JoinstrCubit build() => JoinstrCubit(
    getWalletsUsecase: getWallets,
    getJoinstrSettingsUsecase: getSettings,
    saveJoinstrRelayUsecase: saveRelay,
    listJoinstrPoolsUsecase: listPools,
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
    joinPool = _MockJoinPool();
    initiatePool = _MockInitiatePool();

    when(() => getSettings.execute()).thenAnswer(
      (_) async => const JoinstrSettings(relay: 'wss://nos.lol', history: []),
    );
  });

  Future<JoinstrCubit> loadedCubit() async {
    when(
      () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
    ).thenAnswer((_) async => [_wallet()]);
    when(() => listPools.execute()).thenAnswer((_) async => []);
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

    test('loads the persisted relay and history', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const JoinstrSettings(
          relay: 'wss://relay.example',
          history: [
            JoinstrHistoryEntry(
              amountSat: 100000,
              txId: 'tx-1',
              relay: 'wss://relay.example',
              completedAtUnixSec: 1793500000,
            ),
          ],
        ),
      );
      when(
        () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
      ).thenAnswer((_) async => [_wallet()]);
      when(() => listPools.execute()).thenAnswer((_) async => []);

      final cubit = build();
      await cubit.load();

      expect(cubit.state.relay, 'wss://relay.example');
      expect(cubit.state.history.single.txId, 'tx-1');
    });

    test('does not reload while a round is waiting', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenAnswer((_) async {
        // Re-entering the screen mid-round must not re-resolve the wallet.
        await cubit.load();
        verify(
          () => getWallets.execute(onlyBitcoin: any(named: 'onlyBitcoin')),
        ).called(1);
        return 'txid-abc';
      });

      await cubit.joinPool(_pool(100000));
      expect(cubit.state.rounds.single.txId, 'txid-abc');
    });
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

  group('relayChanged', () {
    test('persists the relay and refreshes pools', () async {
      when(() => saveRelay.execute(any())).thenAnswer((_) async {});
      when(() => listPools.execute()).thenAnswer((_) async => []);

      final cubit = build();
      await cubit.relayChanged('wss://relay.example');

      expect(cubit.state.relay, 'wss://relay.example');
      verify(() => saveRelay.execute('wss://relay.example')).called(1);
      verify(() => listPools.execute()).called(1);
    });

    test('surfaces an invalid relay without refreshing', () async {
      when(
        () => saveRelay.execute(any()),
      ).thenThrow(JoinstrException(JoinstrIssue.invalidRelayUrl));

      final cubit = build();
      await cubit.relayChanged('http://not-a-relay');

      expect(cubit.state.error?.issue, JoinstrIssue.invalidRelayUrl);
      verifyNever(() => listPools.execute());
    });
  });

  group('denominationChanged', () {
    test('accepts BTC decimal input and rejects everything else', () {
      final cubit = build();

      cubit.denominationChanged('0.001');
      expect(cubit.state.denominationBtc, '0.001');

      cubit.denominationChanged('0.001x');
      expect(cubit.state.denominationBtc, '0.001');

      cubit.denominationChanged('');
      expect(cubit.state.denominationBtc, '');
    });
  });

  group('initiatePool validation', () {
    test('rejects an out-of-range config before calling the usecase', () async {
      final cubit = await loadedCubit();
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
          maxDuration: any(named: 'maxDuration'),
        ),
      );
    });

    test('converts the BTC input to satoshis for the usecase', () async {
      final cubit = await loadedCubit();
      when(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: any(named: 'denominationSat'),
          peers: any(named: 'peers'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
          maxDuration: any(named: 'maxDuration'),
        ),
      ).thenAnswer((_) async => 'txid-abc');

      cubit.denominationChanged('0.005');
      await cubit.initiatePool();

      verify(
        () => initiatePool.execute(
          wallet: any(named: 'wallet'),
          denominationSat: 500000,
          peers: 2,
          feeRateSatPerVb: 1,
          maxDuration: any(named: 'maxDuration'),
        ),
      ).called(1);
      expect(cubit.state.rounds.single.status, JoinstrRoundStatus.broadcast);
      expect(cubit.state.rounds.single.initiated, isTrue);
    });
  });

  group('joinPool', () {
    test('tracks the round to broadcast with its txid', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenAnswer((_) async => 'txid-abc');

      await cubit.joinPool(_pool(100000));

      final round = cubit.state.rounds.single;
      expect(round.status, JoinstrRoundStatus.broadcast);
      expect(round.txId, 'txid-abc');
      expect(round.initiated, isFalse);
      expect(round.publicKey, 'pk');
      expect(cubit.state.isRunning, isFalse);
    });

    test('marks the round failed on a JoinstrException', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenThrow(JoinstrException(JoinstrIssue.noEligibleCoin));

      await cubit.joinPool(_pool(100000));

      final round = cubit.state.rounds.single;
      expect(round.status, JoinstrRoundStatus.failed);
      expect(round.error?.issue, JoinstrIssue.noEligibleCoin);
      expect(cubit.state.isRunning, isFalse);
    });

    test('refuses a second round while one is waiting', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenAnswer((_) async {
        // While the first round is in flight, a second join and an initiate
        // must both be no-ops: the same coin must never be offered twice.
        await cubit.joinPool(_pool(500000));
        await cubit.initiatePool();
        verify(
          () => joinPool.execute(
            wallet: any(named: 'wallet'),
            pool: any(named: 'pool'),
          ),
        ).called(1);
        return 'txid-abc';
      });

      await cubit.joinPool(_pool(100000));

      expect(cubit.state.rounds.single.txId, 'txid-abc');
    });

    test('reloads history after a broadcast', () async {
      final cubit = await loadedCubit();
      when(
        () => joinPool.execute(
          wallet: any(named: 'wallet'),
          pool: any(named: 'pool'),
        ),
      ).thenAnswer((_) async => 'txid-abc');
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const JoinstrSettings(
          relay: 'wss://nos.lol',
          history: [
            JoinstrHistoryEntry(
              amountSat: 100000,
              txId: 'txid-abc',
              relay: 'wss://nos.lol',
              completedAtUnixSec: 1793500000,
            ),
          ],
        ),
      );

      await cubit.joinPool(_pool(100000));

      expect(cubit.state.history.single.txId, 'txid-abc');
    });
  });
}
