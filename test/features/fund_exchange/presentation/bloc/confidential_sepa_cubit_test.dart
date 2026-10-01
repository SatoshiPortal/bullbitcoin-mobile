import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/confidential_sepa_cubit.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchVirtualIbanUsecase extends Mock
    implements WatchVirtualIbanUsecase {}

void main() {
  late _MockWatchVirtualIbanUsecase watchUsecase;
  late ConfidentialSepaCubit cubit;

  const pending = VirtualIban(status: VirtualIbanStatus.pending);
  const active = VirtualIban(
    status: VirtualIbanStatus.active,
    iban: 'DE89370400440532013000',
    bicCode: 'TESTBIC',
    bankAddress: 'Test bank',
    ibanCountry: 'DE',
  );

  setUp(() {
    watchUsecase = _MockWatchVirtualIbanUsecase();
    cubit = ConfidentialSepaCubit(watchUsecase);
  });

  tearDown(() => cubit.close());

  test('load reports an absent virtual IBAN without creating it', () async {
    when(
      () => watchUsecase.execute(createIfAbsent: false),
    ).thenAnswer((_) => Stream.value(const Ok(VirtualIban.absent())));

    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.status, VirtualIbanStatus.absent);
    expect(cubit.state.isLoading, isFalse);
    verifyNever(() => watchUsecase.execute(createIfAbsent: true));
  });

  test('activate follows the stream from pending to active', () async {
    when(
      () => watchUsecase.execute(createIfAbsent: true),
    ).thenAnswer((_) => Stream.fromIterable(const [Ok(pending), Ok(active)]));
    final states = <ConfidentialSepaState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await cubit.activate();
    await pumpEventQueue();

    expect(
      states.map((s) => s.status),
      containsAllInOrder([
        null,
        VirtualIbanStatus.pending,
        VirtualIbanStatus.active,
      ]),
    );
    expect(cubit.state.status, VirtualIbanStatus.active);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.isCreating, isFalse);
  });

  test('surfaces the EU residency error with its api error code', () async {
    when(() => watchUsecase.execute(createIfAbsent: true)).thenAnswer(
      (_) => Stream.value(
        const Err(VirtualIbanEuResidencyRequiredFailure('EU only')),
      ),
    );

    await cubit.activate();
    await pumpEventQueue();

    final error = cubit.state.error;
    expect(error, isA<FundExchangeApiError>());
    expect((error! as FundExchangeApiError).code, 'ERR_RCP_400');
    expect(cubit.state.isLoading, isFalse);
  });

  test('confirmationChanged toggles the checkbox state', () {
    cubit.confirmationChanged(true);
    expect(cubit.state.isNameConfirmed, isTrue);
  });
}
