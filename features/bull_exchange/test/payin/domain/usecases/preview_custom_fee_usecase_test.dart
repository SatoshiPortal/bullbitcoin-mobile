import 'package:bull_exchange/src/payin/domain/usecases/preview_custom_fee_usecase.dart';
import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

const _shape = SpendPreviewShape(
  'w1',
  SpendPreviewTarget('bc1q-deposit', 1000),
  true,
  {},
);

final class _Spend extends FakeSpend {
  final Result<BitcoinSpendPreview?, SpendFailure> answer;
  final asked = <String>[];

  _Spend(this.answer);

  @override
  Future<Result<BitcoinSpendPreview?, SpendFailure>> previewBitcoinFee({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async {
    final recipient = recipients.single;
    asked.add(
      '$walletId ${recipient.address} ${recipient.amountSat?.value} '
      '${(networkFee as RelativeFee).satPerKwu} rbf=$replaceByFee',
    );
    return answer;
  }
}

void main() {
  test('previews the payin to the quoted deposit at the typed fee', () async {
    final spend = _Spend(
      Ok((
        prepared: SpendFixtures.preparedBitcoin(
          unsignedPsbt: 'psbt',
          fee: Sats.fromInt(420),
          txSize: 141,
        ),
        fee: Sats.fromInt(420),
      )),
    );
    final slot = await PreviewCustomFeeUsecase(spend)
        .execute(_shape, const RelativeFee(800));
    expect(slot.feeSat, 420);
    expect(slot.txSize, 141);
    expect(spend.asked, ['w1 bc1q-deposit 1000 800 rbf=true']);
  });

  test('a wallet that can not preview gives an empty slot', () async {
    expect(
      await PreviewCustomFeeUsecase(
        _Spend(const Err(SpendUnavailableFailure())),
      ).execute(_shape, const RelativeFee(800)),
      const BitcoinFeePreviewSlot(),
    );
  });
}
