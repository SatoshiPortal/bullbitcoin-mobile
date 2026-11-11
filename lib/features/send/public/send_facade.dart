import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export '../domain/send_failure.dart';
export 'send_route.dart';
export 'send_route_args.dart';

class SendFacade {
  final VerifySignedTxUsecase _verifySignedTxUsecase;

  const SendFacade(this._verifySignedTxUsecase);

  @useResult
  Future<Result<void, SendFailure>> verifySignedTransaction({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) => _verifySignedTxUsecase.execute(
    unsignedPsbt: unsignedPsbt,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );
}
