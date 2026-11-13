import 'dart:async';

import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
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
    when(() => watch.current).thenReturn(const ExchangeAccessDisabled());
    when(watch.execute).thenAnswer((_) => changes.stream);
    cubit = ExchangeAccessSettingsCubit(watch, set);
  });
  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  test('ignores a second tap while the first operation is pending', () async {
    final pending = Completer<Result<void, SettingsFailure>>();
    when(() => set.execute(true)).thenAnswer((_) => pending.future);
    final first = cubit.setEnabled(true);
    expect(cubit.state.busy, isTrue);
    expect(await cubit.setEnabled(false), isFalse);
    verifyNever(() => set.execute(false));
    pending.complete(const Ok(null));
    expect(await first, isTrue);
  });

  test(
    'incomplete logout cannot activate and retry invokes logout again',
    () async {
      changes.add(const ExchangeAccessSignOutIncomplete());
      await Future<void>.delayed(Duration.zero);
      when(() => set.execute(false)).thenAnswer((_) async => const Ok(null));
      expect(await cubit.setEnabled(true), isFalse);
      verifyNever(() => set.execute(true));
      expect(await cubit.setEnabled(false), isTrue);
      verify(() => set.execute(false)).called(1);
    },
  );

  test('exposes a failure after logout fails', () async {
    when(
      () => set.execute(false),
    ).thenAnswer((_) async => const Err(SettingsExchangeSyncFailure()));
    expect(await cubit.setEnabled(false), isFalse);
    expect(cubit.state.failure, isA<SettingsExchangeSyncFailure>());
    expect(cubit.state.busy, isFalse);
  });
}
