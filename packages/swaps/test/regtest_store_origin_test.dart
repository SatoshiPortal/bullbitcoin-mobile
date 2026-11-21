import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:drift/native.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, Ok;
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every regtest row conversion retains its store origin without relabelling legacy rows', () async {
    final productionDb = BoltzSwapsDatabase(NativeDatabase.memory());
    final regtestDb = BoltzSwapsDatabase(NativeDatabase.memory());
    addTearDown(productionDb.close);
    addTearDown(regtestDb.close);
    final canonical = SwapStorage(
      rows: DriftSwapRowStore(productionDb),
      secrets: ReproKeychainBackend().capability,
    );
    final isolated = canonical.regtestView(rows: DriftSwapRowStore(regtestDb));
    final production = SwapStoreImpl(
      storage: canonical,
      environment: NetworkEnv.mainnet,
    );
    final regtest = SwapStoreImpl(
      storage: isolated,
      environment: NetworkEnv.regtest,
    );
    final row = SwapModel.lnReceive(
      id: 'public-id001',
      type: SwapType.lightningToBitcoin.name,
      status: SwapStatus.pending.name,
      keyIndex: 1,
      creationTime: 0,
      receiveWalletId: 'public-wallet',
      invoice: 'public-placeholder',
      receiveTxid: 'public-tx',
    );
    await canonical.store(row);
    await isolated.store(row);
    expect(
      (await production.get(
        row.id,
      ) as Ok<Swap, SwapsFailure>).value.environment,
      Environment.mainnet,
    );
    expect(
      (await regtest.get(row.id) as Ok<Swap, SwapsFailure>).value.environment,
      Environment.regtest,
    );
    expect(
      (await regtest.watch(row.id).first).environment,
      Environment.regtest,
    );
    expect(
      (await regtest.all() as Ok<List<Swap>, SwapsFailure>)
          .value
          .single
          .environment,
      Environment.regtest,
    );
    expect(
      (await regtest.ongoing() as Ok<List<Swap>, SwapsFailure>)
          .value
          .single
          .environment,
      Environment.regtest,
    );
    expect(
      (await regtest.byTxId(
        'public-tx',
      ) as Ok<Swap?, SwapsFailure>).value?.environment,
      Environment.regtest,
    );
    expect(row.toEntity().environment, Environment.mainnet);
    expect(
      row.copyWith(isTestnet: true).toEntity().environment,
      Environment.testnet,
    );
    expect(
      () => row
          .copyWith(isTestnet: true)
          .toEntity(environment: Environment.mainnet),
      throwsFormatException,
    );
    await isolated.trash(row.id);
    expect(await canonical.fetch(row.id), isNotNull);
  });
}
