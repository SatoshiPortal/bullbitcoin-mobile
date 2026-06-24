import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart'
    show NoSpendableUtxoException;
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

WalletUtxo _utxo({required String txId, required int vout}) =>
    WalletUtxo.bitcoin(
      walletId: 'wallet-1',
      txId: txId,
      vout: vout,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(100000),
      address: 'bc1qexampleaddress',
    );

void main() {
  late _MockPayjoinRepository payjoin;
  late _MockBitcoinWalletRepository bitcoinWallet;
  late _MockWalletUtxoRepository walletUtxo;
  late PrepareBitcoinSendUsecase usecase;

  const walletId = 'wallet-1';
  const address = 'bc1qexampleaddress';
  const networkFee = NetworkFee.relative(1);

  setUpAll(() {
    registerFallbackValue(const NetworkFee.relative(1));
  });

  setUp(() {
    payjoin = _MockPayjoinRepository();
    bitcoinWallet = _MockBitcoinWalletRepository();
    walletUtxo = _MockWalletUtxoRepository();
    usecase = PrepareBitcoinSendUsecase(
      payjoinRepository: payjoin,
      walletUtxoRepository: walletUtxo,
      bitcoinWalletRepository: bitcoinWallet,
    );

    when(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer((_) async => 'psbt');
    when(
      () => bitcoinWallet.getTxSize(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 110);
    when(
      () => bitcoinWallet.isAddressOfWallet(any(), walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => false);
  });

  // Capture the `unspendable` arg passed to buildPsbt.
  List<Outpoint>? capturedUnspendable() {
    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: captureAny(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    return captured.single as List<Outpoint>?;
  }

  List<WalletUtxo>? capturedSelected() {
    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: any(named: 'unspendable'),
        selected: captureAny(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    return captured.single as List<WalletUtxo>?;
  }

  test('gate removed: unspendable is ALWAYS computed (both sources read)',
      () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => []);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => []);

    await usecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: 50000,
    );

    // Both unspendable sources are consulted on every build — no gate.
    verify(() => walletUtxo.getAllFrozenOutpoints()).called(1);
    verify(() => payjoin.getUtxosFrozenByOngoingPayjoins()).called(1);
    expect(capturedUnspendable(), isEmpty);
  });

  test('drain: unspendable still carries both sources (exclusion on drain too)',
      () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => [(txId: 'tx-user', vout: 1)]);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => [(txId: 'tx-payjoin', vout: 2)]);

    await usecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      drain: true,
    );

    // Capture drain + unspendable together (a second verify on the same call
    // would report "no matching calls").
    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: captureAny(named: 'drain'),
        unspendable: captureAny(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    expect(captured[0] as bool?, isTrue);
    final unspendable = captured[1] as List<Outpoint>?;
    expect(unspendable, contains((txId: 'tx-user', vout: 1)));
    expect(unspendable, contains((txId: 'tx-payjoin', vout: 2)));
  });

  test('NoSpendableUtxoException is rethrown unchanged (not wrapped)', () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => []);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => []);
    when(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenThrow(NoSpendableUtxoException('all frozen'));

    await expectLater(
      usecase.execute(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        drain: true,
      ),
      throwsA(isA<NoSpendableUtxoException>()),
    );
  });

  test('any other build failure is wrapped in PrepareBitcoinSendException',
      () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => []);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => []);
    when(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenThrow(Exception('insufficient funds'));

    await expectLater(
      usecase.execute(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        amountSat: 50000,
      ),
      throwsA(isA<PrepareBitcoinSendException>()),
    );
  });

  test('user-frozen ∪ payjoin-derived are merged + deduped into unspendable',
      () async {
    final shared = (txId: 'tx-shared', vout: 0);
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => [(txId: 'tx-user', vout: 1), shared]);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => [(txId: 'tx-payjoin', vout: 2), shared]);

    await usecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: 50000,
    );

    final unspendable = capturedUnspendable()!;
    expect(unspendable, contains((txId: 'tx-user', vout: 1)));
    expect(unspendable, contains((txId: 'tx-payjoin', vout: 2)));
    expect(unspendable, contains(shared));
    // Deduped: the shared outpoint appears only once.
    expect(unspendable.length, 3);
    expect(unspendable.where((o) => o == shared).length, 1);
  });

  test('a selectedInput that is frozen is stripped before buildPsbt', () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => [(txId: 'tx-frozen', vout: 0)]);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => []);

    final frozenInput = _utxo(txId: 'tx-frozen', vout: 0);
    final spendableInput = _utxo(txId: 'tx-ok', vout: 1);

    await usecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: 50000,
      selectedInputs: [frozenInput, spendableInput],
    );

    final selected = capturedSelected()!;
    expect(selected, hasLength(1));
    expect(selected.single.txId, 'tx-ok');
    expect(selected.any((u) => u.txId == 'tx-frozen'), isFalse);
  });

  test('happy path (no frozen) builds identically with empty unspendable',
      () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => []);
    when(
      () => payjoin.getUtxosFrozenByOngoingPayjoins(),
    ).thenAnswer((_) async => []);

    final input = _utxo(txId: 'tx-ok', vout: 0);

    final result = await usecase.execute(
      walletId: walletId,
      address: address,
      networkFee: networkFee,
      amountSat: 50000,
      selectedInputs: [input],
    );

    expect(result.unsignedPsbt, 'psbt');
    expect(result.txSize, 110);
    expect(result.isToSelf, false);

    // Capture both args in a single verify (a second verify on the same call
    // would report "no matching calls" since the first marks it verified).
    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: captureAny(named: 'unspendable'),
        selected: captureAny(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    expect(captured[0] as List<Outpoint>?, isEmpty);
    expect(captured[1] as List<WalletUtxo>?, hasLength(1));
  });
}
