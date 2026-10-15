import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/presentation/sepa_virtual_payee_activation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSepaVirtualPayeeActivationUsecase extends Mock
    implements WatchSepaVirtualPayeeActivationUsecase {}

typedef _Event = Result<SepaVirtualPayeeStatus, RecipientsFailure>;

void main() {
  late _MockWatchSepaVirtualPayeeActivationUsecase usecase;
  late List<StreamController<_Event>> streams;

  setUp(() {
    usecase = _MockWatchSepaVirtualPayeeActivationUsecase();
    streams = [];
    when(
      () => usecase.execute(recipientId: any(named: 'recipientId')),
    ).thenAnswer((_) {
      final controller = StreamController<_Event>();
      streams.add(controller);
      return controller.stream;
    });
  });

  SepaVirtualPayeeActivationCubit build() => SepaVirtualPayeeActivationCubit(
    watchSepaVirtualPayeeActivationUsecase: usecase,
    recipientId: 'r-1',
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('follows the status until the recipient is active', () async {
    final cubit = build()..start();
    expect(cubit.state.isWatching, isTrue);

    streams.single.add(const Ok(SepaVirtualPayeeStatus.pending));
    await settle();
    expect(cubit.state.status, SepaVirtualPayeeStatus.pending);

    streams.single.add(const Ok(SepaVirtualPayeeStatus.active));
    await streams.single.close();
    await settle();
    expect(cubit.state.isActive, isTrue);
    expect(cubit.state.isWatching, isFalse);
    verify(() => usecase.execute(recipientId: 'r-1')).called(1);

    await cubit.close();
  });

  test('a second start does not watch twice', () async {
    final cubit = build()
      ..start()
      ..start();

    expect(streams, hasLength(1));

    await cubit.close();
  });

  test('a failure stops the watch and retry starts it again', () async {
    final cubit = build()..start();

    streams.single.add(const Err(RecipientsNetworkFailure()));
    await streams.single.close();
    await settle();
    expect(cubit.state.failure, isA<RecipientsNetworkFailure>());
    expect(cubit.state.isWatching, isFalse);

    await cubit.retry();
    expect(streams, hasLength(2));
    expect(cubit.state.failure, isNull);
    expect(cubit.state.isWatching, isTrue);

    await cubit.close();
  });

  test('retry while watching replaces the running watch', () async {
    final cubit = build()..start();

    await cubit.retry();

    expect(streams, hasLength(2));
    expect(streams.first.hasListener, isFalse);

    await cubit.close();
  });

  test('closing stops the watch, so nothing is emitted after close', () async {
    final cubit = build()..start();

    await cubit.close();

    expect(streams.single.hasListener, isFalse);
    expect(() => cubit.start(), returnsNormally);
    expect(streams, hasLength(1));
  });
}
