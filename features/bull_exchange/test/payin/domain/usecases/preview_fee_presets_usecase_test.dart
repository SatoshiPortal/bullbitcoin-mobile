import 'package:bull_exchange/src/payin/domain/usecases/preview_fee_presets_usecase.dart';
import 'package:bull_exchange/src/payin/spend_options_state.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

const _fees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);
const _shape = SpendPreviewShape(
  'w1',
  SpendPreviewTarget('bc1q-deposit', 1000),
  false,
  {},
);

final class _Spend extends FakeSpend {
  final Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure> answer;
  final asked = <String>[];

  _Spend(this.answer);

  @override
  Future<Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>
  previewBitcoinFeePresets({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required FeeOptions presets,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async {
    final recipient = recipients.single;
    asked.add(
      '$walletId ${recipient.address} ${recipient.amountSat?.value} '
      'rbf=$replaceByFee ${identical(presets, _fees)}',
    );
    return answer;
  }
}

void main() {
  test('previews the payin to the quoted deposit at each preset', () async {
    final spend = _Spend(
      Ok({
        FeeSelection.fastest: (
          prepared: SpendFixtures.preparedBitcoin(
            unsignedPsbt: 'psbt',
            fee: Sats.fromInt(300),
            txSize: 140,
          ),
          fee: Sats.fromInt(300),
        ),
        FeeSelection.slow: null,
      }),
    );
    final slots = await PreviewFeePresetsUsecase(spend).execute(_shape, _fees);
    expect(slots[FeeSelection.fastest]?.feeSat, 300);
    expect(slots[FeeSelection.fastest]?.txSize, 140);
    expect(slots[FeeSelection.slow], const BitcoinFeePreviewSlot());
    expect(spend.asked, ['w1 bc1q-deposit 1000 rbf=false true']);
  });

  test('a wallet that can not preview gives no slots', () async {
    expect(
      await PreviewFeePresetsUsecase(
        _Spend(const Err(SpendUnavailableFailure())),
      ).execute(_shape, _fees),
      isEmpty,
    );
  });
}
