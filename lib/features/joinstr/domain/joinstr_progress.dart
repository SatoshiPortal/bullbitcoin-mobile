import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';

/// One coinjoin progress update from the bindings: the step reached, plus the
/// txid on `done` or the message on `failed`.
class JoinstrProgress {
  final JoinstrRoundStep step;
  final String? txId;
  final String? errorMessage;

  const JoinstrProgress({required this.step, this.txId, this.errorMessage});
}
