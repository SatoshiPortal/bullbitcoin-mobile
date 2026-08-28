import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Sats;

class _MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

void main() {
  late _MockPrepareBitcoinSendUsecase prepare;
  late _MockCalculateBitcoinAbsoluteFeesUsecase calculateFees;
  late PreviewBitcoinFeeUsecase usecase;

  final fee = NetworkFee.relativeFromSatPerVbyte(2);
  final recipients = [
    BitcoinTransactionRecipient.fixed(
      address: 'bc1qfixed',
      amountSat: Sats.fromInt(12000),
    ),
    BitcoinTransactionRecipient.remainder(address: 'bc1qremainder'),
  ];
  final selectedInputs = [
    WalletUtxo.bitcoin(
      walletId: 'wallet-1',
      txId: 'a' * 64,
      vout: 1,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(50000),
      address: 'bc1qinput',
    ),
  ];

  setUpAll(() {
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
    registerFallbackValue(<BitcoinTransactionRecipient>[]);
    registerFallbackValue(<WalletUtxo>[]);
  });

  setUp(() {
    prepare = _MockPrepareBitcoinSendUsecase();
    calculateFees = _MockCalculateBitcoinAbsoluteFeesUsecase();
    usecase = PreviewBitcoinFeeUsecase(
      prepareBitcoinSendUsecase: prepare,
      calculateBitcoinAbsoluteFeesUsecase: calculateFees,
    );
  });

  test(
    'forwards the transaction shape and preserves prepared output data',
    () async {
      when(
        () => prepare.execute(
          walletId: 'wallet-1',
          recipients: recipients,
          networkFee: fee,
          replaceByFee: false,
          selectedInputs: selectedInputs,
          selectedOnly: true,
        ),
      ).thenAnswer(
        (_) async => (
          unsignedPsbt: 'unsigned',
          txSize: 155,
          recipientAmountsSat: [Sats.fromInt(12000), Sats.fromInt(37000)],
          isToSelf: true,
        ),
      );
      when(
        () => calculateFees.execute(psbt: 'unsigned'),
      ).thenAnswer((_) async => 1000);

      final result = await usecase.execute(
        walletId: 'wallet-1',
        recipients: recipients,
        networkFee: fee,
        replaceByFee: false,
        selectedInputs: selectedInputs,
        selectedOnly: true,
      );

      expect(
        result,
        const BitcoinFeePreviewSlot(
          feeSat: 1000,
          unsignedPsbt: 'unsigned',
          txSize: 155,
          recipientAmountsSat: [12000, 37000],
          isToSelf: true,
        ),
      );
    },
  );

  test('returns an empty slot when preparation fails', () async {
    when(
      () => prepare.execute(
        walletId: any(named: 'walletId'),
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        replaceByFee: any(named: 'replaceByFee'),
        selectedInputs: any(named: 'selectedInputs'),
        selectedOnly: any(named: 'selectedOnly'),
      ),
    ).thenThrow(Exception('insufficient funds'));

    final result = await usecase.execute(
      walletId: 'wallet-1',
      recipients: recipients,
      networkFee: fee,
      replaceByFee: true,
      selectedInputs: selectedInputs,
      selectedOnly: true,
    );

    expect(result, const BitcoinFeePreviewSlot());
    verifyNever(() => calculateFees.execute(psbt: any(named: 'psbt')));
  });
}
