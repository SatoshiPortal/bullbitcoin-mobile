import 'package:bull_exchange/src/payin/domain/usecases/get_fee_options_usecase.dart';
import 'package:fees/fees.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../payin_fixtures.dart';

const _options = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);

final class _Fees extends Fake implements Fees {
  final Result<FeeOptions, FeesFailure> answer;
  final asked = <Network>[];

  _Fees(this.answer);

  @override
  Future<Result<FeeOptions, FeesFailure>> estimate(
    Network network, {
    FeeSource? source,
  }) async {
    asked.add(network);
    return answer;
  }
}

final _ok = isA<Ok<FeeOptions, ExchangeFeeEstimatesUnavailableFailure>>()
    .having((r) => r.value, 'value', _options);

void main() {
  test('estimates on the bitcoin network of the session', () async {
    final fees = _Fees(const Ok(_options));
    expect(await GetFeeOptionsUsecase(fees).execute(payinTestnetSession), _ok);
    expect(await GetFeeOptionsUsecase(fees).execute(payinSession), _ok);
    expect(fees.asked, [BitcoinNetwork.testnet, BitcoinNetwork.mainnet]);
  });

  test('estimates that can not be read are a failure', () async {
    expect(
      await GetFeeOptionsUsecase(
        _Fees(const Err(FeeEstimateUnavailableFailure())),
      ).execute(payinSession),
      isA<Err<FeeOptions, ExchangeFeeEstimatesUnavailableFailure>>(),
    );
  });
}
