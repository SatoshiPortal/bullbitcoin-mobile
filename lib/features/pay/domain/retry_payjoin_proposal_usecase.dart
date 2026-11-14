import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RetryPayjoinProposalUsecase {
  final PayjoinSender _sender;

  const RetryPayjoinProposalUsecase(this._sender);

  @useResult
  Future<Result<PayjoinSession, PayFailure>> execute(String sessionId) async =>
      switch (await _sender.retryProposal(sessionId)) {
        Ok(:final value) => Ok(value),
        Err() => const Err(PayPayjoinPausedFailure()),
      };
}
