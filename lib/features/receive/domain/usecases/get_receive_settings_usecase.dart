import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared settings use-case, which still
/// throws.
class GetReceiveSettingsUsecase {
  final GetSettingsUsecase _getSettingsUsecase;

  const GetReceiveSettingsUsecase(this._getSettingsUsecase);

  @useResult
  Future<Result<SettingsEntity, ReceiveFailure>> execute({
    ReceiveNetworkType? mode,
    primitives.Network? selectedNetwork,
  }) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final network =
          selectedNetwork ??
          primitives.BitcoinNetwork.values.firstWhere(
            (network) => network.env == settings.activeNetwork,
          );
      if (mode != null && !mode.supportsNetwork(network)) {
        return const Err(ReceiveUnsupportedNetworkFailure());
      }
      return Ok(settings);
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to read settings for receive',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
