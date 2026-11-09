import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RetryPayjoinProposalUsecase {
  final PayjoinSender _sender;

  const RetryPayjoinProposalUsecase(this._sender);

  @useResult
  Future<core.Result<PayjoinSession, SendFailure>> execute(
    String sessionId,
  ) async => switch (await _sender.retryProposal(sessionId)) {
    Ok(:final value) => core.Ok(value),
    Err() => const core.Err(SendPayjoinPausedFailure()),
  };
}
