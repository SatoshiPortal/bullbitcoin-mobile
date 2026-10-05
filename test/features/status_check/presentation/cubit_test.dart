import 'dart:async';

import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/domain/status_check_failure.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckServiceStatusUsecase extends Mock
    implements CheckServiceStatusUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AllServicesStatus());
    registerFallbackValue((AllServicesStatus _) {});
  });

  test(
    'publishes partial service results while the refresh continues',
    () async {
      final checkService = _MockCheckServiceStatusUsecase();

      const partial = AllServicesStatus(
        liquidElectrum: ServiceStatusInfo(
          status: ServiceStatus.online,
          name: 'Liquid Electrum',
        ),
      );
      final completed = partial.copyWith(
        bitcoinElectrum: const ServiceStatusInfo(
          status: ServiceStatus.online,
          name: 'Bitcoin Electrum',
        ),
        lastChecked: DateTime(2026),
      );
      when(
        () => checkService.execute(
          initialStatus: any(named: 'initialStatus'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((invocation) async {
        final onUpdate =
            invocation.namedArguments[#onUpdate]
                as void Function(AllServicesStatus)?;
        onUpdate?.call(partial);
        return Ok<AllServicesStatus, StatusCheckFailure>(completed);
      });

      final cubit = ServiceStatusCubit(checkServiceStatusUsecase: checkService);
      addTearDown(cubit.close);
      final statesFuture = cubit.stream.take(3).toList();

      await cubit.checkStatus();
      final states = await statesFuture;

      expect(states.first.isLoading, isTrue);
      expect(states[1].isLoading, isTrue);
      expect(states[1].serviceStatus.liquidElectrum.isOnline, isTrue);
      expect(states.last.isLoading, isFalse);
      expect(states.last.serviceStatus.bitcoinElectrum.isOnline, isTrue);
    },
  );

  test('ignores results from an obsolete refresh', () async {
    final checkService = _MockCheckServiceStatusUsecase();
    final firstResult = Completer<AllServicesStatus>();
    final secondResult = Completer<AllServicesStatus>();
    void Function(AllServicesStatus)? firstUpdate;
    void Function(AllServicesStatus)? secondUpdate;
    var invocationCount = 0;
    when(
      () => checkService.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((invocation) {
      invocationCount++;
      final onUpdate =
          invocation.namedArguments[#onUpdate]
              as void Function(AllServicesStatus)?;
      if (invocationCount == 1) {
        firstUpdate = onUpdate;
        return firstResult.future.then(
          (value) => Ok<AllServicesStatus, StatusCheckFailure>(value),
        );
      }
      secondUpdate = onUpdate;
      return secondResult.future.then(
        (value) => Ok<AllServicesStatus, StatusCheckFailure>(value),
      );
    });
    const stale = AllServicesStatus(
      bitcoinElectrum: ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Bitcoin Electrum',
      ),
    );
    const current = AllServicesStatus(
      bitcoinElectrum: ServiceStatusInfo(
        status: ServiceStatus.online,
        name: 'Bitcoin Electrum',
      ),
    );
    final cubit = ServiceStatusCubit(checkServiceStatusUsecase: checkService);
    addTearDown(cubit.close);

    final firstCheck = cubit.checkStatus();
    await Future<void>.delayed(Duration.zero);
    final secondCheck = cubit.checkStatus();
    await Future<void>.delayed(Duration.zero);
    secondUpdate?.call(current);
    secondResult.complete(current);
    await secondCheck;
    firstUpdate?.call(stale);
    firstResult.complete(stale);
    await firstCheck;

    expect(cubit.state.serviceStatus.bitcoinElectrum.isOnline, isTrue);
    expect(cubit.state.isLoading, isFalse);
  });
}
