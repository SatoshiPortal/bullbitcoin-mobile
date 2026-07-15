import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_proxy_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements JoinstrDatasource {}

class _MockStore extends Mock implements JoinstrStore {}

class _MockResolvePeerContext extends Mock
    implements ResolveJoinstrPeerContextUsecase {}

class _MockResolveProxy extends Mock implements ResolveJoinstrProxyUsecase {}

Wallet _wallet() => Wallet(
  origin: 'origin',
  network: Network.bitcoinTestnet,
  xpubFingerprint: 'ffffffff',
  masterFingerprint: 'eeeeeeee',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/0/*)',
  internalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/1/*)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

JoinstrPool _pool({
  required int denominationSat,
  required int expiresAtUnixSec,
}) => JoinstrPool(
  id: 'pool-$denominationSat',
  rawJson: '{}',
  denominationSat: denominationSat,
  peers: 2,
  expiresAtUnixSec: expiresAtUnixSec,
  relay: 'wss://nos.lol',
  feeRateSatPerVb: 1,
  publicKey: 'pk',
);

void main() {
  late _MockDatasource datasource;
  late _MockStore store;
  late _MockResolvePeerContext resolvePeerContext;
  late _MockResolveProxy resolveProxy;

  setUpAll(() {
    registerFallbackValue(_wallet());
    registerFallbackValue(
      _pool(denominationSat: 100000, expiresAtUnixSec: 1793500000),
    );
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(
      const JoinstrHistoryEntry(
        amountSat: 0,
        txId: '',
        relay: '',
        completedAtUnixSec: 0,
      ),
    );
  });

  setUp(() {
    datasource = _MockDatasource();
    store = _MockStore();
    resolvePeerContext = _MockResolvePeerContext();
    resolveProxy = _MockResolveProxy();

    when(() => store.getRelay()).thenAnswer((_) async => null);
    when(() => store.appendHistory(any())).thenAnswer((_) async {});
    when(() => resolveProxy.execute()).thenAnswer((_) async => '127.0.0.1:9050');
    when(
      () => resolvePeerContext.execute(wallet: any(named: 'wallet')),
    ).thenAnswer(
      (_) async => const JoinstrPeerContext(
        mnemonic: 'mnemonic',
        electrumUrl: 'ssl://electrum.example:50002',
        outputAddress: 'tb1qaddress',
        proxy: '127.0.0.1:9050',
      ),
    );
  });

  group('ListJoinstrPoolsUsecase', () {
    ListJoinstrPoolsUsecase build() => ListJoinstrPoolsUsecase(
      datasource: datasource,
      store: store,
      resolveProxyUsecase: resolveProxy,
    );

    int nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

    test('drops expired pools, which can never fill', () async {
      when(
        () => datasource.listPools(
          relay: any(named: 'relay'),
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) async => [
          _pool(denominationSat: 100000, expiresAtUnixSec: nowSec() - 10),
          _pool(denominationSat: 200000, expiresAtUnixSec: nowSec() + 600),
        ],
      );

      final pools = await build().execute();
      expect(pools.map((p) => p.denominationSat), [200000]);
    });

    test('sorts joinable pools by denomination', () async {
      when(
        () => datasource.listPools(
          relay: any(named: 'relay'),
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) async => [
          _pool(denominationSat: 500000, expiresAtUnixSec: nowSec() + 600),
          _pool(denominationSat: 100000, expiresAtUnixSec: nowSec() + 600),
        ],
      );

      final pools = await build().execute();
      expect(pools.map((p) => p.denominationSat), [100000, 500000]);
    });

    test('uses the stored relay, falling back to the default', () async {
      when(
        () => datasource.listPools(
          relay: any(named: 'relay'),
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer((_) async => []);

      await build().execute();
      verify(
        () => datasource.listPools(
          relay: ApiServiceConstants.defaultNostrRelayUrl,
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).called(1);

      when(
        () => store.getRelay(),
      ).thenAnswer((_) async => 'wss://relay.example');
      await build().execute();
      verify(
        () => datasource.listPools(
          relay: 'wss://relay.example',
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).called(1);
    });
  });

  group('SaveJoinstrRelayUsecase', () {
    SaveJoinstrRelayUsecase build() => SaveJoinstrRelayUsecase(store: store);

    test('persists a valid websocket relay', () async {
      when(() => store.saveRelay(any())).thenAnswer((_) async {});
      await build().execute('wss://relay.example');
      verify(() => store.saveRelay('wss://relay.example')).called(1);
    });

    test('rejects a non-websocket url without touching the store', () async {
      await expectLater(
        () => build().execute('https://relay.example'),
        throwsA(
          isA<JoinstrException>().having(
            (e) => e.issue,
            'issue',
            JoinstrIssue.invalidRelayUrl,
          ),
        ),
      );
      verifyNever(() => store.saveRelay(any()));
    });
  });

  group('JoinJoinstrPoolUsecase', () {
    JoinJoinstrPoolUsecase build() => JoinJoinstrPoolUsecase(
      datasource: datasource,
      store: store,
      resolvePeerContextUsecase: resolvePeerContext,
    );

    test('appends a history entry after the broadcast', () async {
      when(
        () => datasource.joinPool(
          pool: any(named: 'pool'),
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer((_) async => 'txid-abc');

      final txId = await build().execute(
        wallet: _wallet(),
        pool: _pool(denominationSat: 100000, expiresAtUnixSec: 1793500000),
      );

      expect(txId, 'txid-abc');
      final entry =
          verify(() => store.appendHistory(captureAny())).captured.single
              as JoinstrHistoryEntry;
      expect(entry.txId, 'txid-abc');
      expect(entry.amountSat, 100000);
      expect(entry.relay, 'wss://nos.lol');
    });

    test('does not write history when the round fails', () async {
      when(
        () => datasource.joinPool(
          pool: any(named: 'pool'),
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          proxy: any(named: 'proxy'),
        ),
      ).thenThrow(JoinstrException(JoinstrIssue.coinjoinFailed));

      await expectLater(
        () => build().execute(
          wallet: _wallet(),
          pool: _pool(denominationSat: 100000, expiresAtUnixSec: 1793500000),
        ),
        throwsA(isA<JoinstrException>()),
      );
      verifyNever(() => store.appendHistory(any()));
    });
  });

  group('InitiateJoinstrPoolUsecase', () {
    InitiateJoinstrPoolUsecase build() => InitiateJoinstrPoolUsecase(
      datasource: datasource,
      store: store,
      resolvePeerContextUsecase: resolvePeerContext,
    );

    test('uses the stored relay and records history', () async {
      when(
        () => store.getRelay(),
      ).thenAnswer((_) async => 'wss://relay.example');
      when(
        () => datasource.initiatePool(
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          relay: any(named: 'relay'),
          denominationSat: any(named: 'denominationSat'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
          peers: any(named: 'peers'),
          maxDuration: any(named: 'maxDuration'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer((_) async => 'txid-abc');

      await build().execute(
        wallet: _wallet(),
        denominationSat: 100000,
        peers: 2,
        feeRateSatPerVb: 1,
      );

      verify(
        () => datasource.initiatePool(
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          relay: 'wss://relay.example',
          denominationSat: 100000,
          feeRateSatPerVb: 1,
          peers: 2,
          maxDuration: any(named: 'maxDuration'),
          proxy: any(named: 'proxy'),
        ),
      ).called(1);
      final entry =
          verify(() => store.appendHistory(captureAny())).captured.single
              as JoinstrHistoryEntry;
      expect(entry.relay, 'wss://relay.example');
      expect(entry.amountSat, 100000);
    });

    test('wraps an unexpected error as coinjoinFailed', () async {
      when(
        () => datasource.initiatePool(
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          relay: any(named: 'relay'),
          denominationSat: any(named: 'denominationSat'),
          feeRateSatPerVb: any(named: 'feeRateSatPerVb'),
          peers: any(named: 'peers'),
          maxDuration: any(named: 'maxDuration'),
          proxy: any(named: 'proxy'),
        ),
      ).thenThrow(StateError('boom'));

      await expectLater(
        () => build().execute(
          wallet: _wallet(),
          denominationSat: 100000,
          peers: 2,
          feeRateSatPerVb: 1,
        ),
        throwsA(
          isA<JoinstrException>().having(
            (e) => e.issue,
            'issue',
            JoinstrIssue.coinjoinFailed,
          ),
        ),
      );
      verifyNever(() => store.appendHistory(any()));
    });
  });
}
