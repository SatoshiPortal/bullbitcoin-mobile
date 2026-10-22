import 'dart:async';

import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/get_sell_confidential_sepa_availability_usecase_v2.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLoadMethods extends Mock
    implements GetSellConfidentialSepaAvailabilityUsecaseV2 {}

void main() {
  late _MockLoadMethods load;
  late SellPayoutCubitV2 cubit;

  setUp(() {
    load = _MockLoadMethods();
    cubit = SellPayoutCubitV2(load);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('retry restores availability after a failed lookup', () async {
    when(load.execute).thenAnswer((_) async => const Err(SellNetworkFailure()));
    await cubit.load();
    expect(cubit.state.failure, isA<SellNetworkFailure>());
    expect(cubit.state.availability, isNull);

    when(
      load.execute,
    ).thenAnswer((_) async => const Ok(ConfidentialSepaAvailability.ready));
    await cubit.load();
    expect(cubit.state.availability, ConfidentialSepaAvailability.ready);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.isLoading, isFalse);
  });

  test('ineligibility is a successful lookup with no error', () async {
    when(load.execute).thenAnswer(
      (_) async => const Ok(ConfidentialSepaAvailability.unavailable),
    );
    await cubit.load();
    expect(cubit.state.availability, ConfidentialSepaAvailability.unavailable);
    expect(cubit.state.failure, isNull);
  });

  test('ignores duplicate requests and results after close', () async {
    final response =
        Completer<Result<ConfidentialSepaAvailability, SellFailure>>();
    when(load.execute).thenAnswer((_) => response.future);
    final pending = cubit.load();
    await cubit.load();
    expect(cubit.state.isLoading, isTrue);
    verify(load.execute).called(1);
    await cubit.close();
    response.complete(const Ok(ConfidentialSepaAvailability.ready));
    await pending;
  });

  test('completed onboarding clears the setup requirement', () async {
    when(load.execute).thenAnswer(
      (_) async => const Ok(ConfidentialSepaAvailability.needsVirtualIban),
    );
    await cubit.load();
    cubit.virtualIbanActivated();
    expect(cubit.state.availability, ConfidentialSepaAvailability.ready);
  });
}
