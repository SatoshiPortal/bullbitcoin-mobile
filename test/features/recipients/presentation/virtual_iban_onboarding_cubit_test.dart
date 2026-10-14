import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchVirtualIbanUsecase extends Mock
    implements WatchVirtualIbanUsecase {}

class _MockGetAccountOwnerNameUsecase extends Mock
    implements GetAccountOwnerNameUsecase {}

typedef _Event = Result<VirtualIban?, RecipientsFailure>;

final _active = VirtualIban.fromBankDetails(
  iban: 'FR7616958000016918327146718',
  bicCode: 'FIRPFRP2',
  bankAddress: '1 Rue de la Paix, Paris',
);

void main() {
  late _MockWatchVirtualIbanUsecase watch;
  late _MockGetAccountOwnerNameUsecase ownerName;
  late Map<bool, List<StreamController<_Event>>> streams;

  setUp(() {
    watch = _MockWatchVirtualIbanUsecase();
    ownerName = _MockGetAccountOwnerNameUsecase();
    streams = {true: [], false: []};
    when(
      () => ownerName.execute(),
    ).thenAnswer((_) async => const Ok('Satoshi Nakamoto'));
    when(
      () => watch.execute(createIfAbsent: any(named: 'createIfAbsent')),
    ).thenAnswer((invocation) {
      final create = invocation.namedArguments[#createIfAbsent] as bool;
      final controller = StreamController<_Event>();
      streams[create]!.add(controller);
      return controller.stream;
    });
  });

  VirtualIbanOnboardingCubit build() => VirtualIbanOnboardingCubit(
    watchVirtualIbanUsecase: watch,
    getAccountOwnerNameUsecase: ownerName,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a user without a virtual IBAN sees the intro', () async {
    final cubit = build();
    await cubit.start();

    streams[false]!.single.add(const Ok(null));
    await settle();

    expect(cubit.state.step, VirtualIbanOnboardingStep.intro);
    expect(cubit.state.accountOwnerName, 'Satoshi Nakamoto');
    expect(streams[true], isEmpty);
    await cubit.close();
  });

  test('activating creates the virtual IBAN and waits for it', () async {
    final cubit = build();
    await cubit.start();
    streams[false]!.single.add(const Ok(null));
    await settle();

    await cubit.activate();
    expect(cubit.state.isCreating, isTrue);
    expect(streams[false]!.single.hasListener, isFalse);

    streams[true]!.single.add(const Ok(PendingVirtualIban()));
    await settle();
    expect(cubit.state.step, VirtualIbanOnboardingStep.activating);
    expect(cubit.state.isCreating, isFalse);

    streams[true]!.single.add(Ok(_active));
    await settle();
    expect(cubit.state.step, VirtualIbanOnboardingStep.active);
    await cubit.close();
  });

  test('a pending virtual IBAN goes straight to activating', () async {
    final cubit = build();
    await cubit.start();

    streams[false]!.single.add(const Ok(PendingVirtualIban()));
    await settle();

    expect(cubit.state.step, VirtualIbanOnboardingStep.activating);
    await cubit.close();
  });

  test('a refused creation keeps the intro and shows why', () async {
    final cubit = build();
    await cubit.start();
    streams[false]!.single.add(const Ok(null));
    await settle();

    await cubit.activate();
    streams[true]!.single.add(
      const Err(RecipientsEuResidencyRequiredFailure()),
    );
    await settle();

    expect(cubit.state.step, VirtualIbanOnboardingStep.intro);
    expect(cubit.state.isCreating, isFalse);
    expect(cubit.state.failure, isA<RecipientsEuResidencyRequiredFailure>());
    await cubit.close();
  });

  test(
    'an unreadable owner name is a failure and nothing is watched',
    () async {
      when(
        () => ownerName.execute(),
      ).thenAnswer((_) async => const Err(RecipientsUnexpectedFailure()));
      final cubit = build();

      await cubit.start();

      expect(cubit.state.failure, isA<RecipientsUnexpectedFailure>());
      expect(streams[false], isEmpty);
      await cubit.close();
    },
  );

  test('closing stops the watch', () async {
    final cubit = build();
    await cubit.start();

    await cubit.close();

    expect(streams[false]!.single.hasListener, isFalse);
  });
}
