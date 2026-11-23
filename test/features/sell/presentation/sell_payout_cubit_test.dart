import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLoadMethods extends Mock
    implements GetSellConfidentialSepaAvailabilityUsecase {}

void main() {
  late _MockLoadMethods load;
  late SellPayoutCubit cubit;

  setUpAll(() => registerFallbackValue(FiatCurrency.eur));

  setUp(() {
    load = _MockLoadMethods();
    cubit = SellPayoutCubit(load);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('retry restores availability after a failed lookup', () async {
    when(() => load.execute(any()))
        .thenAnswer((_) async => const Err(SellNetworkFailure()));
    await cubit.load(FiatCurrency.eur);
    expect(cubit.state.failure, isA<SellNetworkFailure>());
    expect(cubit.state.availability, isNull);

    when(() => load.execute(any()))
        .thenAnswer((_) async => const Ok(ConfidentialSepaAvailability.ready));
    await cubit.load(FiatCurrency.eur);
    expect(cubit.state.availability, ConfidentialSepaAvailability.ready);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.isLoading, isFalse);
  });

  test('ineligibility is a successful lookup with no error', () async {
    when(() => load.execute(any())).thenAnswer(
      (_) async => const Ok(ConfidentialSepaAvailability.unavailable),
    );
    await cubit.load(FiatCurrency.eur);
    expect(cubit.state.availability, ConfidentialSepaAvailability.unavailable);
    expect(cubit.state.failure, isNull);
  });

  test('ignores duplicate requests and results after close', () async {
    final response =
        Completer<Result<ConfidentialSepaAvailability, SellFailure>>();
    when(() => load.execute(any())).thenAnswer((_) => response.future);
    final pending = cubit.load(FiatCurrency.eur);
    await cubit.load(FiatCurrency.eur);
    expect(cubit.state.isLoading, isTrue);
    verify(() => load.execute(FiatCurrency.eur)).called(1);
    await cubit.close();
    response.complete(const Ok(ConfidentialSepaAvailability.ready));
    await pending;
  });

  test('completed onboarding clears the setup requirement', () async {
    when(() => load.execute(any())).thenAnswer(
      (_) async => const Ok(ConfidentialSepaAvailability.needsVirtualIban),
    );
    await cubit.load(FiatCurrency.eur);
    cubit.virtualIbanActivated();
    expect(cubit.state.availability, ConfidentialSepaAvailability.ready);
  });
}
