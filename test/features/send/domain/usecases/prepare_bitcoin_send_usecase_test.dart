import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok, Outpoint, Sats;

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockBitcoinSendPort extends Mock implements BitcoinSendPort {}

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
  late _MockPayjoinSessions payjoin;
  late _MockBitcoinSendPort bitcoinWallet;
  late _MockWalletUtxoRepository walletUtxo;
  late PrepareBitcoinSendUsecase usecase;

  const walletId = 'wallet-1';
  const address = 'bc1qexampleaddress';
  final networkFee = NetworkFee.relativeFromSatPerVbyte(1);
  final fixedRecipients = [
    BitcoinTransactionRecipient.fixed(
      address: address,
      amountSat: Sats.fromInt(50000),
    ),
  ];
  final remainderRecipients = [
    BitcoinTransactionRecipient.remainder(address: address),
  ];

  setUpAll(() {
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
    registerFallbackValue(<BitcoinTransactionRecipient>[]);
  });

  setUp(() {
    payjoin = _MockPayjoinSessions();
    bitcoinWallet = _MockBitcoinSendPort();
    walletUtxo = _MockWalletUtxoRepository();
    usecase = PrepareBitcoinSendUsecase(
      payjoinSessions: payjoin,
      walletUtxoRepository: walletUtxo,
      bitcoinWalletRepository: bitcoinWallet,
    );

    when(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer((_) async => 'psbt');
    when(
      () => bitcoinWallet.getTxSize(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 110);
    when(
      () => bitcoinWallet.getRecipientAmounts(
        psbt: any(named: 'psbt'),
        recipients: any(named: 'recipients'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => [Sats.fromInt(50000)]);
    when(
      () => bitcoinWallet.areAddressesOfWallet(
        any(),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => walletUtxo.getWalletUtxos(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
  });

  // Capture the `unspendable` arg passed to buildPsbt.
  List<Outpoint>? capturedUnspendable() {
    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: captureAny(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    return captured.single as List<Outpoint>?;
  }

  test(
    'gate removed: unspendable is ALWAYS computed (both sources read)',
    () async {
      when(
        () => walletUtxo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => []);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok({}));

      await usecase.execute(
        walletId: walletId,
        recipients: fixedRecipients,
        networkFee: networkFee,
      );

      // Both unspendable sources are consulted on every build — no gate.
      verify(() => walletUtxo.getAllFrozenOutpoints()).called(1);
      verify(() => payjoin.reservedOutpoints()).called(1);
      expect(capturedUnspendable(), isEmpty);
    },
  );

  test('remainder send still carries both unspendable sources', () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => [(txId: 'tx-user', vout: 1)]);
    when(
      () => payjoin.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok({(txId: 'tx-payjoin', vout: 2)}));

    await usecase.execute(
      walletId: walletId,
      recipients: remainderRecipients,
      networkFee: networkFee,
    );

    final captured = verify(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: captureAny(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: captureAny(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).captured;
    final recipients = captured[0] as List<BitcoinTransactionRecipient>;
    expect(recipients.single.receivesRemainder, isTrue);
    final unspendable = captured[1] as List<Outpoint>?;
    expect(unspendable, contains((txId: 'tx-user', vout: 1)));
    expect(unspendable, contains((txId: 'tx-payjoin', vout: 2)));
  });

  test(
    'NoSpendableUtxoException is rethrown unchanged (not wrapped)',
    () async {
      when(
        () => walletUtxo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => []);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok(<Outpoint>{}));
      when(
        () => bitcoinWallet.buildPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          unspendable: any(named: 'unspendable'),
          selected: any(named: 'selected'),
          selectedOnly: any(named: 'selectedOnly'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(NoSpendableUtxoException('all frozen'));

      await expectLater(
        usecase.execute(
          walletId: walletId,
          recipients: remainderRecipients,
          networkFee: networkFee,
        ),
        throwsA(isA<NoSpendableUtxoException>()),
      );
    },
  );

  test(
    'any other build failure is wrapped in PrepareBitcoinSendException',
    () async {
      when(
        () => walletUtxo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => []);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok(<Outpoint>{}));
      when(
        () => bitcoinWallet.buildPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          unspendable: any(named: 'unspendable'),
          selected: any(named: 'selected'),
          selectedOnly: any(named: 'selectedOnly'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(Exception('insufficient funds'));

      await expectLater(
        usecase.execute(
          walletId: walletId,
          recipients: fixedRecipients,
          networkFee: networkFee,
        ),
        throwsA(isA<PrepareBitcoinSendException>()),
      );
    },
  );

  test(
    'user-frozen ∪ payjoin-derived are merged + deduped into unspendable',
    () async {
      final shared = (txId: 'tx-shared', vout: 0);
      when(
        () => walletUtxo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => [(txId: 'tx-user', vout: 1), shared]);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => Ok({(txId: 'tx-payjoin', vout: 2), shared}));

      await usecase.execute(
        walletId: walletId,
        recipients: fixedRecipients,
        networkFee: networkFee,
      );

      final unspendable = capturedUnspendable()!;
      expect(unspendable, contains((txId: 'tx-user', vout: 1)));
      expect(unspendable, contains((txId: 'tx-payjoin', vout: 2)));
      expect(unspendable, contains(shared));
      // Deduped: the shared outpoint appears only once.
      expect(unspendable.length, 3);
      expect(unspendable.where((o) => o == shared).length, 1);
    },
  );

  test('a partly filtered selection fails before buildPsbt', () async {
    when(
      () => walletUtxo.getAllFrozenOutpoints(),
    ).thenAnswer((_) async => [(txId: 'tx-frozen', vout: 0)]);
    when(
      () => payjoin.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok(<Outpoint>{}));

    final frozenInput = _utxo(txId: 'tx-frozen', vout: 0);
    final spendableInput = _utxo(txId: 'tx-ok', vout: 1);
    when(
      () => walletUtxo.getWalletUtxos(walletId: walletId),
    ).thenAnswer((_) async => [frozenInput, spendableInput]);

    await expectLater(
      usecase.execute(
        walletId: walletId,
        recipients: fixedRecipients,
        networkFee: networkFee,
        selectedInputs: [frozenInput, spendableInput],
      ),
      throwsA(isA<NoSpendableUtxoException>()),
    );
    verifyNever(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    );
  });

  test('a Payjoin-reserved selected coin fails before buildPsbt', () async {
    final reservedInput = _utxo(txId: 'tx-reserved', vout: 0);
    when(() => walletUtxo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
    when(() => payjoin.reservedOutpoints()).thenAnswer(
      (_) async => const Ok(<Outpoint>{(txId: 'tx-reserved', vout: 0)}),
    );
    when(
      () => walletUtxo.getWalletUtxos(walletId: walletId),
    ).thenAnswer((_) async => [reservedInput]);

    await expectLater(
      usecase.execute(
        walletId: walletId,
        recipients: fixedRecipients,
        networkFee: networkFee,
        selectedInputs: [reservedInput],
      ),
      throwsA(isA<NoSpendableUtxoException>()),
    );
    verifyNever(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    );
  });

  test('selected-only drain rejects a Payjoin-reserved input', () async {
    when(() => walletUtxo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
    when(() => payjoin.reservedOutpoints()).thenAnswer(
      (_) async => const Ok(<Outpoint>{(txId: 'tx-reserved', vout: 0)}),
    );

    await expectLater(
      usecase.execute(
        walletId: walletId,
        recipients: remainderRecipients,
        networkFee: networkFee,
        selectedInputs: [_utxo(txId: 'tx-reserved', vout: 0)],
        selectedOnly: true,
      ),
      throwsA(isA<SelectedInputsUnavailableException>()),
    );
    verifyNever(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    );
  });

  test('selected-only drain rejects a partially reserved selection', () async {
    when(() => walletUtxo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
    when(() => payjoin.reservedOutpoints()).thenAnswer(
      (_) async => const Ok(<Outpoint>{(txId: 'tx-reserved', vout: 0)}),
    );

    await expectLater(
      usecase.execute(
        walletId: walletId,
        recipients: remainderRecipients,
        networkFee: networkFee,
        selectedInputs: [
          _utxo(txId: 'tx-reserved', vout: 0),
          _utxo(txId: 'tx-spendable', vout: 1),
        ],
        selectedOnly: true,
      ),
      throwsA(isA<SelectedInputsUnavailableException>()),
    );
    verifyNever(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    );
  });

  test(
    'happy path (no frozen) builds identically with empty unspendable',
    () async {
      when(
        () => walletUtxo.getAllFrozenOutpoints(),
      ).thenAnswer((_) async => []);
      when(
        () => payjoin.reservedOutpoints(),
      ).thenAnswer((_) async => const Ok(<Outpoint>{}));

      final input = _utxo(txId: 'tx-ok', vout: 0);
      when(
        () => walletUtxo.getWalletUtxos(walletId: walletId),
      ).thenAnswer((_) async => [input]);

      final result = await usecase.execute(
        walletId: walletId,
        recipients: fixedRecipients,
        networkFee: networkFee,
        selectedInputs: [input],
      );

      expect(result.unsignedPsbt, 'psbt');
      expect(result.txSize, 110);
      expect(result.isToSelf, false);
      verify(
        () => bitcoinWallet.areAddressesOfWallet([address], walletId: walletId),
      ).called(1);

      // Capture both args in a single verify (a second verify on the same call
      // would report "no matching calls" since the first marks it verified).
      final captured = verify(
        () => bitcoinWallet.buildPsbt(
          walletId: any(named: 'walletId'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          unspendable: captureAny(named: 'unspendable'),
          selected: captureAny(named: 'selected'),
          selectedOnly: any(named: 'selectedOnly'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).captured;
      expect(captured[0] as List<Outpoint>?, isEmpty);
      expect(captured[1] as List<WalletUtxo>?, hasLength(1));
    },
  );

  test('lets invalid recipient lists fail before repository work', () async {
    await expectLater(
      usecase.execute(
        walletId: walletId,
        recipients: [
          BitcoinTransactionRecipient.remainder(address: 'bc1qfirst'),
          BitcoinTransactionRecipient.remainder(address: 'bc1qsecond'),
        ],
        networkFee: networkFee,
      ),
      throwsArgumentError,
    );

    verifyNever(() => walletUtxo.getAllFrozenOutpoints());
    verifyNever(
      () => bitcoinWallet.buildPsbt(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    );
  });
}
