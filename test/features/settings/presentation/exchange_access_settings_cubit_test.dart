import 'dart:async';

import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Watch extends Mock implements WatchSettingsExchangeAccessUsecase {}

class _Set extends Mock implements SetSettingsExchangeAccessUsecase {}

void main() {
  late _Watch watch;
  late _Set set;
  late StreamController<ExchangeAccess> changes;
  late ExchangeAccessSettingsCubit cubit;

  setUp(() {
    watch = _Watch();
    set = _Set();
    changes = StreamController<ExchangeAccess>();
    when(() => watch.current).thenReturn(const ExchangeAccess());
    when(watch.execute).thenAnswer((_) => changes.stream);
    cubit = ExchangeAccessSettingsCubit(watch, set);
  });
  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  test('ignores a second tap while the first operation is pending', () async {
    final pending = Completer<Result<ExchangeAccessOutcome, SettingsFailure>>();
    when(() => set.execute(true)).thenAnswer((_) => pending.future);
    final first = cubit.setEnabled(true);
    expect(cubit.state.busy, isTrue);
    expect(await cubit.setEnabled(false), isNull);
    verifyNever(() => set.execute(false));
    pending.complete(const Ok(ExchangeAccessOutcome.authenticationRequired));
    expect(await first, ExchangeAccessOutcome.authenticationRequired);
    expect(cubit.state.busy, isFalse);
    verify(() => set.execute(true)).called(1);
  });

  test('exposes a typed failure and clears busy', () async {
    when(
      () => set.execute(false),
    ).thenAnswer((_) async => const Err(SettingsExchangeSyncFailure()));
    expect(await cubit.setEnabled(false), isNull);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.failure, isA<SettingsExchangeSyncFailure>());
  });

  test('returns OFF success and reflects the updated access stream', () async {
    when(() => set.execute(false)).thenAnswer((_) async {
      changes.add(const ExchangeAccess(choice: ExchangeAccessChoice.disabled));
      return const Ok(ExchangeAccessOutcome.applied);
    });
    expect(await cubit.setEnabled(false), ExchangeAccessOutcome.applied);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.access.choice, ExchangeAccessChoice.disabled);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.busy, isFalse);
  });
}
