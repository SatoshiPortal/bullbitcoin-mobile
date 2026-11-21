import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

class PrioritizeElectrumServersUsecase {
  final SetCustomServersPriorityUsecase _saveOrder;
  final HasActiveCustomBitcoinOnionServerUsecase _hasActiveOnionServer;

  const PrioritizeElectrumServersUsecase(
    this._saveOrder,
    this._hasActiveOnionServer,
  );

  Future<
    Result<
      ({
        List<ElectrumServerDto> servers,
        bool hasActiveCustomBitcoinOnionServer,
      }),
      ElectrumServersFailure
    >
  >
  execute({
    required List<ElectrumServerDto> servers,
    required int oldIndex,
    required int newIndex,
  }) async {
    final reordered = [...servers];
    reordered.insert(
      oldIndex < newIndex ? newIndex - 1 : newIndex,
      reordered.removeAt(oldIndex),
    );
    switch (await _saveOrder.execute(
      SetCustomServersPriorityRequest(servers: reordered),
    )) {
      case Ok(:final value):
        return Ok((
          servers: value.servers,
          hasActiveCustomBitcoinOnionServer: await _hasActiveOnionServer
              .execute(),
        ));
      case Err(:final failure):
        return Err(ElectrumServersSavePriorityFailure(failure.logMessage));
    }
  }
}
