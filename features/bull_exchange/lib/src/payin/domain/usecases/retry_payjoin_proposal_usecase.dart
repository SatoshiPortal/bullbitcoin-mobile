import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Asks payjoin session [sessionId] for the receiver's proposal again; a
/// failure is logged, the session's watch shows what happens next.
class RetryPayjoinProposalUsecase {
  final PayjoinSender _payjoinSender;

  const RetryPayjoinProposalUsecase(this._payjoinSender);

  Future<void> execute(String sessionId) async {
    if (await _payjoinSender.retryProposal(sessionId) case Err()) {
      log.warning('Could not retry the payjoin proposal');
    }
  }
}
