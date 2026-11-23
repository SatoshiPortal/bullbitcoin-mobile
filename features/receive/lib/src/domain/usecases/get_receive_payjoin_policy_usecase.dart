import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:receive/receive.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

/// The payjoin receiver policy: whether payjoin is on for receiving from other
/// users, and the anti-probing minimum below which the receiver declines a
/// request.
typedef ReceivePayjoinPolicy = ({bool enabled, int minimumAmountSat});

class GetReceivePayjoinPolicyUsecase {
  final PayjoinPolicyAccess _policy;

  const GetReceivePayjoinPolicyUsecase(this._policy);

  /// This is the feature's boundary for the settings read: `.first` throws on
  /// an errored or empty stream, and that must not escape into the bloc.
  ///
  /// Callers are expected to fail *closed* — payjoin off — on an [Err], which
  /// is why it does not reuse [ReceivePayjoinSettingFailure]: that one is
  /// rendered as a snackbar by the payjoin toggle, and a failed policy read
  /// is not something to interrupt the user with.
  @useResult
  Future<Result<ReceivePayjoinPolicy, ReceiveFailure>> execute() async {
    try {
      return (await _policy.watch().first)
          .map(
            (policy) => (
              enabled: policy.receiveEnabled,
              minimumAmountSat: policy.minimumAmount.value.toInt(),
            ),
          )
          .mapErr((failure) {
            log.warning(
              'Failed to read receive Payjoin policy: ${failure.runtimeType}',
            );
            return const ReceivePayjoinPolicyUnavailableFailure();
          });
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to read the payjoin policy; caller fails closed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(ReceivePayjoinPolicyUnavailableFailure());
    }
  }
}
