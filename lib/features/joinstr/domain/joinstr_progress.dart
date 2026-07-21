import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';

/// One coinjoin progress update from the bindings: the step reached, plus the
/// timeline detail known so far. `txId` is set on `done`; `errorMessage` on
/// `failed`; the event ids, psbt and output address accumulate as their step is
/// reached so the timeline can show real data like the reference wallets.
class JoinstrProgress {
  final JoinstrRoundStep step;
  final String? txId;
  final String? errorMessage;
  final String? outputAddress;
  final String? outputEventId;
  final String? inputEventId;
  final String? psbt;

  const JoinstrProgress({
    required this.step,
    this.txId,
    this.errorMessage,
    this.outputAddress,
    this.outputEventId,
    this.inputEventId,
    this.psbt,
  });
}
