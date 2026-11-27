import 'package:bull_exchange/src/payin/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _Sender extends Fake implements PayjoinSender {
  final Result<PayjoinSession, PayjoinFailure> answer;
  final asked = <String>[];

  _Sender(this.answer);

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> retryProposal(
    String sessionId,
  ) async {
    asked.add(sessionId);
    return answer;
  }
}

void main() {
  test('asks the session for the proposal again; a failure does not '
      'throw', () async {
    final sender = _Sender(const Err(PayjoinUnexpectedFailure('down')));
    await RetryPayjoinProposalUsecase(sender).execute('pj-1');
    expect(sender.asked, ['pj-1']);
  });
}
