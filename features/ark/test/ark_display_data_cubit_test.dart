import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_display_data_usecase.dart';
import 'package:bull_ark/src/presentation/ark_display_data_cubit.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account;

class Source implements ArkDisplayDataPort {
  final replies = <Completer<Result<ArkDisplayData, ArkFailure>>>[];
  final calls = <ArkAccountId>[];
  final updates = StreamController<void>.broadcast(sync: true);

  Source() {
    addTearDown(updates.close);
  }

  @override
  Stream<void> changes(ArkAccountId account) => updates.stream;

  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) {
    calls.add(account);
    final reply = Completer<Result<ArkDisplayData, ArkFailure>>();
    replies.add(reply);
    return reply.future;
  }
}

ArkDisplayData observation({ArkAccountId? owner, Sats? available}) =>
    ArkDisplayData(
      account: owner ?? account(),
      walletId: 'selected-source',
      available: available,
    );

void main() {
  test(
    'a source change keeps the shown balance until the reload replaces it',
    () async {
      final source = Source();
      final cubit = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(source),
        account: account(),
      );
      addTearDown(cubit.close);
      final loaded = cubit.load();
      source.replies.last.complete(
        Ok(observation(available: Sats.fromInt(42))),
      );
      await loaded;
      expect(cubit.state, isA<ArkDisplayDataReady>());
      source.updates.add(null);
      // No flash of "Unavailable" while reloading.
      expect(
        (cubit.state as ArkDisplayDataReady).source.available,
        Sats.fromInt(42),
      );
      expect(source.calls, [account(), account()]);
      final published = cubit.stream.first;
      source.replies.last.complete(
        Ok(observation(available: Sats.fromInt(21))),
      );
      expect(
        (await published as ArkDisplayDataReady).source.available,
        Sats.fromInt(21),
      );
    },
  );

  test(
    'late observations cannot overwrite the latest display request',
    () async {
      final source = Source();
      final cubit = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(source),
        account: account(),
      );
      addTearDown(cubit.close);
      final old = cubit.load();
      final current = cubit.load();
      final latest = observation(available: Sats.fromInt(1234));
      source.replies.last.complete(Ok(latest));
      await current;
      source.replies.first.complete(Ok(observation(available: Sats.zero)));
      await old;
      expect((cubit.state as ArkDisplayDataReady).source, same(latest));
      expect(source.calls, [account(), account()]);
    },
  );

  test(
    'an unavailable source is not published as zero or retained data',
    () async {
      final source = Source();
      final cubit = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(source),
        account: account(),
      );
      addTearDown(cubit.close);
      var pending = cubit.load();
      source.replies.last.complete(
        Ok(observation(available: Sats.fromInt(1234))),
      );
      await pending;
      pending = cubit.load();
      source.replies.last.complete(const Err(ArkServiceUnavailableFailure()));
      await pending;
      expect(cubit.state, isA<ArkDisplayDataUnavailable>());
    },
  );

  test(
    'foreign and post-close observations never publish display data',
    () async {
      final source = Source();
      final cubit = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(source),
        account: account(),
      );
      var pending = cubit.load();
      final original = account();
      source.replies.last.complete(
        Ok(
          observation(
            owner: ArkAccountId(
              parent: original.parent,
              network: original.network,
              serverIdentity: 'other-server',
            ),
          ),
        ),
      );
      await pending;
      expect(cubit.state, isA<ArkDisplayDataUnavailable>());
      pending = cubit.load();
      await cubit.close();
      source.replies.last.complete(Ok(observation(available: Sats.fromInt(5))));
      await pending;
      expect(cubit.state, isA<ArkDisplayDataLoading>());
    },
  );
}
