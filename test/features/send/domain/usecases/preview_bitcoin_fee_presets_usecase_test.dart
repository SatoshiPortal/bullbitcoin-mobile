import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Sats;

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

void main() {
  late _MockPreviewBitcoinFeeUsecase previewOne;
  late PreviewBitcoinFeePresetsUsecase usecase;

  const presets = FeeOptions(
    fastest: RelativeFee(750),
    economic: RelativeFee(250),
    slow: RelativeFee(250),
    minRelay: RelativeFee(25),
  );
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
      txId: 'b' * 64,
      vout: 2,
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
    previewOne = _MockPreviewBitcoinFeeUsecase();
    usecase = PreviewBitcoinFeePresetsUsecase(
      previewBitcoinFeeUsecase: previewOne,
    );
  });

  test(
    'shares equal-rate builds and keeps each result in its fee tier',
    () async {
      final fastest = Completer<BitcoinFeePreviewSlot>();
      final economicAndSlow = Completer<BitcoinFeePreviewSlot>();
      when(
        () => previewOne.execute(
          walletId: 'wallet-1',
          recipients: recipients,
          networkFee: any(named: 'networkFee'),
          replaceByFee: false,
          selectedInputs: selectedInputs,
          selectedOnly: true,
        ),
      ).thenAnswer((invocation) {
        final networkFee =
            invocation.namedArguments[#networkFee] as RelativeFee;
        return networkFee.satPerKwu == 750
            ? fastest.future
            : economicAndSlow.future;
      });

      final resultFuture = usecase.execute(
        presets: presets,
        walletId: 'wallet-1',
        recipients: recipients,
        replaceByFee: false,
        selectedInputs: selectedInputs,
        selectedOnly: true,
      );
      economicAndSlow.complete(
        const BitcoinFeePreviewSlot(
          feeSat: 100,
          unsignedPsbt: 'shared',
          txSize: 120,
        ),
      );
      fastest.complete(
        const BitcoinFeePreviewSlot(
          feeSat: 300,
          unsignedPsbt: 'fastest',
          txSize: 140,
        ),
      );

      final result = await resultFuture;

      expect(result[FeeSelection.fastest]?.unsignedPsbt, 'fastest');
      expect(result[FeeSelection.economic]?.unsignedPsbt, 'shared');
      expect(result[FeeSelection.slow]?.unsignedPsbt, 'shared');
      verify(
        () => previewOne.execute(
          walletId: 'wallet-1',
          recipients: recipients,
          networkFee: any(named: 'networkFee'),
          replaceByFee: false,
          selectedInputs: selectedInputs,
          selectedOnly: true,
        ),
      ).called(2);
    },
  );
}
