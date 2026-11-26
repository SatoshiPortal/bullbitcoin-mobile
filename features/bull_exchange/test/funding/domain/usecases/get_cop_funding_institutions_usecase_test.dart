import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

void main() {
  test('asks for the banks of the COP rail jurisdiction; an empty list '
      'is an answer', () async {
    final funding = FundingTestPort()..institutionsAnswer = const ReadGot([]);
    final read = await GetCopFundingInstitutionsUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect((read as ReadGot<List<FundingInstitution>>).value, isEmpty);
    expect(funding.log, ['institutions CO a']);
  });
}
