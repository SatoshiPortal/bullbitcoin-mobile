import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_balance.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_balance_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

void main() {
  late _MockGetSpBalanceUsecase balanceUsecase;
  late ValidateSpAmountUsecase usecase;

  SilentBalance balance(int sats) => SilentBalance(
    confirmedSat: Sats(BigInt.from(sats)),
    totalUnifiedSat: Sats(BigInt.from(sats)),
  );

  setUp(() {
    balanceUsecase = _MockGetSpBalanceUsecase();
    usecase = ValidateSpAmountUsecase(getSpBalanceUsecase: balanceUsecase);
  });

  SilentFailure? failureOf(Result<Sats, SilentFailure> r) =>
      r is Err<Sats, SilentFailure> ? r.failure : null;

  test('rejects a non-positive amount', () {
    when(() => balanceUsecase.execute()).thenReturn(Ok(balance(50000)));
    expect(
      failureOf(usecase.execute(Sats.zero)),
      isA<SilentAmountBelowMinimum>(),
    );
  });

  test('rejects an amount above the available balance', () {
    when(() => balanceUsecase.execute()).thenReturn(Ok(balance(1000)));
    expect(
      failureOf(usecase.execute(Sats.fromInt(2000))),
      isA<SilentAmountExceedsBalance>(),
    );
  });

  test('allows spending unconfirmed coins, above the confirmed balance', () {
    // bwk selects unconfirmed coins too (only Spent is excluded), so a ceiling
    // at confirmedSat would refuse a spend the Rust side can fund.
    when(() => balanceUsecase.execute()).thenReturn(
      Ok(
        SilentBalance(
          confirmedSat: Sats.fromInt(1000),
          totalUnifiedSat: Sats.fromInt(5000),
        ),
      ),
    );

    expect(usecase.execute(Sats.fromInt(2000)), isA<Ok<Sats, SilentFailure>>());
    expect(
      failureOf(usecase.execute(Sats.fromInt(6000))),
      isA<SilentAmountExceedsBalance>(),
    );
  });

  test('accepts an amount within the balance', () {
    when(() => balanceUsecase.execute()).thenReturn(Ok(balance(50000)));
    final result = usecase.execute(Sats.fromInt(1000));
    expect(result, isA<Ok<Sats, SilentFailure>>());
    expect((result as Ok<Sats, SilentFailure>).value, Sats.fromInt(1000));
  });

  test('returns the balance failure when the balance read fails', () {
    when(() => balanceUsecase.execute())
        .thenReturn(const Err(SilentUnexpected('no session')));
    final result = usecase.execute(Sats.fromInt(999999));
    expect(failureOf(result), isA<SilentUnexpected>());
  });
}
