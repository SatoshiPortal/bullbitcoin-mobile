import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:meta/meta.dart';

/// The payjoin receiver policy: whether payjoin is on, and the anti-probing
/// minimum below which the receiver declines a request.
typedef ReceivePayjoinPolicy = ({bool enabled, int minimumAmountSat});

/// Receive-owned wrapper around the settings feature's public contract.
class GetReceivePayjoinPolicyUsecase {
  final SettingsFacade _settings;

  const GetReceivePayjoinPolicyUsecase(this._settings);

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
      return Ok(await _settings.watchPayjoinPolicy().first);
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to read the payjoin policy; caller fails closed',
        error: e,
        trace: st,
      );
      return Err(ReceivePayjoinPolicyUnavailableFailure(e.toString()));
    }
  }
}
