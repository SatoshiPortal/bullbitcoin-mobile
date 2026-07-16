import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

void main() {
  late _MockGetSpBalanceUsecase balanceUsecase;
  late ValidateSpAmountUsecase usecase;

  SpBalance balance(int sats) => SpBalance(
    confirmedSat: BigInt.from(sats),
    totalUnifiedSat: BigInt.from(sats),
  );

  setUp(() {
    balanceUsecase = _MockGetSpBalanceUsecase();
    usecase = ValidateSpAmountUsecase(getSpBalanceUsecase: balanceUsecase);
  });

  SpFailure? failureOf(Result<BigInt, SpFailure> r) =>
      r is Err<BigInt, SpFailure> ? r.failure : null;

  test('rejects a non-positive amount', () {
    when(() => balanceUsecase.execute()).thenReturn(balance(50000));
    expect(
      failureOf(usecase.execute(BigInt.zero)),
      isA<SpAmountBelowMinimum>(),
    );
  });

  test('rejects an amount above the available balance', () {
    when(() => balanceUsecase.execute()).thenReturn(balance(1000));
    expect(
      failureOf(usecase.execute(BigInt.from(2000))),
      isA<SpAmountExceedsBalance>(),
    );
  });

  test('accepts an amount within the balance', () {
    when(() => balanceUsecase.execute()).thenReturn(balance(50000));
    final result = usecase.execute(BigInt.from(1000));
    expect(result, isA<Ok<BigInt, SpFailure>>());
    expect((result as Ok<BigInt, SpFailure>).value, BigInt.from(1000));
  });

  test('skips the ceiling when the balance read fails', () {
    when(() => balanceUsecase.execute()).thenThrow(Exception('no session'));
    final result = usecase.execute(BigInt.from(999999));
    expect(result, isA<Ok<BigInt, SpFailure>>());
  });
}
