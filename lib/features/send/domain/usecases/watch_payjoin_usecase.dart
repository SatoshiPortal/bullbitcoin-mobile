import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  @useResult
  Stream<core.Result<PayjoinSession, SendFailure>> execute({
    List<String>? ids,
  }) => Stream.multi((controller) async {
    final observed = <String>{};
    final subscription = _sessions
        .watch(sessionIds: ids?.toSet())
        .listen(
          (result) {
            if (result case Ok(:final value)) observed.add(value.id);
            controller.add(_mapResult(result));
          },
          onError: controller.addError,
          onDone: controller.close,
        );
    controller.onCancel = subscription.cancel;
    // Subscribe before reading so a payment completing during the lookup
    // cannot be missed or replaced by an older snapshot.
    for (final id in ids ?? const <String>[]) {
      final current = await _sessions.byId(id);
      if (controller.isClosed) return;
      if (observed.contains(id)) continue;
      switch (current) {
        case Ok(value: final session?):
          controller.add(core.Ok(session));
        case Err(:final failure):
          controller.add(_mapResult(Err(failure)));
        case Ok(value: null):
          break;
      }
    }
  });

  core.Result<PayjoinSession, SendFailure> _mapResult(
    Result<PayjoinSession, PayjoinFailure> result,
  ) {
    switch (result) {
      case Ok(:final value):
        return core.Ok(value);
      case Err(:final failure):
        log.warning(
          'Failed to watch Payjoin session',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: failure.logMessage ?? 'Failed to watch Payjoin',
          ),
        );
    }
  }
}
