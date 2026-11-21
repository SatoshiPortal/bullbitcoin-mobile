import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';

class CheckElectrumStatusUsecase {
  final ElectrumServers _servers;

  CheckElectrumStatusUsecase(this._servers);

  Future<bool> execute(ElectrumServerNetwork network) async {
    final result = await _servers.check(network: network);
    return switch (result) {
      Ok(value: ElectrumServerStatus.online) => true,
      _ => false,
    };
  }
}
