import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

import 'package:primitives/primitives.dart';

void main() {
  test('asks for the banks of the COP rail jurisdiction; an empty list '
      'is an answer', () async {
    final funding = FundingTestPort()..institutionsAnswer = const Ok([]);
    final read = await GetCopFundingInstitutionsUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect(
      (read as Ok<List<FundingInstitution>, ExchangeReadFailure>).value,
      isEmpty,
    );
    expect(funding.log, ['institutions CO a']);
  });
}
