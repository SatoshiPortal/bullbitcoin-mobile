import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

typedef ElectrumSettingsSnapshot = ({
  LoadElectrumServerDataResponse data,
  bool hasActiveCustomBitcoinOnionServer,
});

class LoadElectrumSettingsUsecase {
  final LoadElectrumServerDataUsecase _loadServers;
  final HasActiveCustomBitcoinOnionServerUsecase _hasActiveOnionServer;

  const LoadElectrumSettingsUsecase(
    this._loadServers,
    this._hasActiveOnionServer,
  );

  Future<Result<ElectrumSettingsSnapshot?, ElectrumFailure>> execute({
    required bool isLiquid,
    required bool Function() isCurrent,
    required void Function(LoadElectrumServerDataResponse) onUpdate,
  }) async {
    final result = await _loadServers.execute(
      LoadElectrumServerDataRequest(isLiquid: isLiquid),
      onUpdate: onUpdate,
    );
    if (!isCurrent()) return const Ok(null);
    return switch (result) {
      Ok(:final value) => Ok((
        data: value,
        hasActiveCustomBitcoinOnionServer: await _hasActiveOnionServer
            .execute(),
      )),
      Err(:final failure) => Err(failure),
    };
  }
}
