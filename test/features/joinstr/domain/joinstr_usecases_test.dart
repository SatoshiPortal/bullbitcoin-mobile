import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_coins_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_node_context_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_proxy_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements JoinstrDatasource {}

class _MockStore extends Mock implements JoinstrStore {}

class _MockResolveNodeContext extends Mock
    implements ResolveJoinstrNodeContextUsecase {}

class _MockResolveProxy extends Mock implements ResolveJoinstrProxyUsecase {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

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
  late _MockResolveNodeContext resolveNode;
  late _MockResolveProxy resolveProxy;
  late _MockGetReceiveAddress getReceiveAddress;

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
    resolveNode = _MockResolveNodeContext();
    resolveProxy = _MockResolveProxy();
    getReceiveAddress = _MockGetReceiveAddress();

    when(() => store.getRelay()).thenAnswer((_) async => null);
    when(() => store.appendHistory(any())).thenAnswer((_) async {});
    when(
      () => resolveProxy.execute(),
    ).thenAnswer((_) async => '127.0.0.1:9050');
    when(() => resolveNode.execute(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => const JoinstrNodeContext(
        mnemonic: 'mnemonic',
        electrumUrl: 'ssl://electrum.example:50002',
        proxy: '127.0.0.1:9050',
      ),
    );
    when(
      () => getReceiveAddress.execute(
        walletId: any(named: 'walletId'),
        generateNew: any(named: 'generateNew'),
      ),
    ).thenAnswer(
      (_) async => WalletAddress(
        walletId: 'w',
        index: 0,
        address: 'tb1qaddress',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
  });

  int nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  group('ListJoinstrPoolsUsecase', () {
    ListJoinstrPoolsUsecase build() => ListJoinstrPoolsUsecase(
      datasource: datasource,
      store: store,
      resolveProxyUsecase: resolveProxy,
    );

    void stubPools(List<JoinstrPool> pools) => when(
      () => datasource.listPools(
        relay: any(named: 'relay'),
        back: any(named: 'back'),
        wait: any(named: 'wait'),
        proxy: any(named: 'proxy'),
      ),
    ).thenAnswer((_) async => pools);

    test('drops expired pools and sorts by denomination', () async {
      stubPools([
        _pool(denominationSat: 500000, expiresAtUnixSec: nowSec() + 600),
        _pool(denominationSat: 100000, expiresAtUnixSec: nowSec() + 600),
        _pool(denominationSat: 200000, expiresAtUnixSec: nowSec() - 10),
      ]);

      final pools = await build().execute();
      expect(pools.map((p) => p.denominationSat), [100000, 500000]);
    });

    test('uses the stored relay, falling back to the default', () async {
      stubPools([]);
      await build().execute();
      verify(
        () => datasource.listPools(
          relay: ApiServiceConstants.defaultNostrRelayUrl,
          back: any(named: 'back'),
          wait: any(named: 'wait'),
          proxy: any(named: 'proxy'),
        ),
      ).called(1);
    });
  });

  group('ListJoinstrCoinsUsecase', () {
    ListJoinstrCoinsUsecase build() => ListJoinstrCoinsUsecase(
      datasource: datasource,
      resolveNodeContextUsecase: resolveNode,
    );

    test('resolves node context and returns coins sorted by value', () async {
      when(
        () => datasource.listCoins(
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          electrumUrl: any(named: 'electrumUrl'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) async => const [
          JoinstrCoin(txid: 'a', vout: 0, valueSat: 100000),
          JoinstrCoin(txid: 'b', vout: 1, valueSat: 500000),
        ],
      );

      final coins = await build().execute(wallet: _wallet());
      expect(coins.map((c) => c.valueSat), [500000, 100000]);
      verify(
        () => datasource.listCoins(
          wallet: any(named: 'wallet'),
          mnemonic: 'mnemonic',
          electrumUrl: 'ssl://electrum.example:50002',
          proxy: '127.0.0.1:9050',
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

  group('InitiateJoinstrPoolUsecase', () {
    InitiateJoinstrPoolUsecase build() => InitiateJoinstrPoolUsecase(
      datasource: datasource,
      store: store,
      resolveNodeContextUsecase: resolveNode,
      getReceiveAddressUsecase: getReceiveAddress,
    );

    test('forwards progress and records history on broadcast', () async {
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
          inputOutpoint: any(named: 'inputOutpoint'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.connecting),
          JoinstrProgress(step: JoinstrRoundStep.done, txId: 'txid-abc'),
        ]),
      );

      final steps = await build()
          .execute(
            wallet: _wallet(),
            denominationSat: 100000,
            peers: 2,
            feeRateSatPerVb: 1,
            inputOutpoint: 'a:0',
          )
          .map((p) => p.step)
          .toList();

      expect(steps, [JoinstrRoundStep.connecting, JoinstrRoundStep.done]);
      final entry =
          verify(() => store.appendHistory(captureAny())).captured.single
              as JoinstrHistoryEntry;
      expect(entry.txId, 'txid-abc');
      expect(entry.amountSat, 100000);
    });

    test('does not record history when the round fails', () async {
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
          inputOutpoint: any(named: 'inputOutpoint'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.failed, errorMessage: 'boom'),
        ]),
      );

      await build()
          .execute(
            wallet: _wallet(),
            denominationSat: 100000,
            peers: 2,
            feeRateSatPerVb: 1,
            inputOutpoint: 'a:0',
          )
          .toList();

      verifyNever(() => store.appendHistory(any()));
    });
  });

  group('JoinJoinstrPoolUsecase', () {
    JoinJoinstrPoolUsecase build() => JoinJoinstrPoolUsecase(
      datasource: datasource,
      store: store,
      resolveNodeContextUsecase: resolveNode,
      getReceiveAddressUsecase: getReceiveAddress,
    );

    test('forwards progress and records history on broadcast', () async {
      when(
        () => datasource.joinPool(
          pool: any(named: 'pool'),
          wallet: any(named: 'wallet'),
          mnemonic: any(named: 'mnemonic'),
          outputAddress: any(named: 'outputAddress'),
          electrumUrl: any(named: 'electrumUrl'),
          inputOutpoint: any(named: 'inputOutpoint'),
          proxy: any(named: 'proxy'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          JoinstrProgress(step: JoinstrRoundStep.done, txId: 'txid-join'),
        ]),
      );

      await build()
          .execute(
            wallet: _wallet(),
            pool: _pool(denominationSat: 100000, expiresAtUnixSec: 1793500000),
            inputOutpoint: 'a:0',
          )
          .toList();

      final entry =
          verify(() => store.appendHistory(captureAny())).captured.single
              as JoinstrHistoryEntry;
      expect(entry.txId, 'txid-join');
    });
  });
}
