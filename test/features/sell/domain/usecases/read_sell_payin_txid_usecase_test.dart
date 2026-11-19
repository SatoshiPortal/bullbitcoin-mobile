import 'package:bb_mobile/features/sell/domain/usecases/read_sell_payin_txid_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  const usecase = ReadSellPayinTxidUsecase();

  test('an unreadable PSET keeps only the decoder category', () async {
    final result = await usecase.fromPset('');

    expect(result, isA<Err<String, SellFailure>>());
    final failure = (result as Err<String, SellFailure>).failure;
    expect(failure, isA<SellUnexpectedFailure>());
    expect(failure.logMessage, 'invalid_transaction');
  });

  test('a PSBT payin reads the txid of its transaction', () async {
    const psbt =
        'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9'
        '////AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAA'
        'FgAUMzMzMzMzMzMzMzMzMzMzMzMzMzMAAA==';
    final result = await usecase.fromPsbt(psbt);

    expect(result, isA<Ok<String, SellFailure>>());
    expect((result as Ok<String, SellFailure>).value, hasLength(64));
  });
}
