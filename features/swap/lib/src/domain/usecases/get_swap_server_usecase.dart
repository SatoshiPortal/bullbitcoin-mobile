import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart'
    show SwapServer, SwapServerSettings, SwapsFailure;

class GetSwapServerUsecase {
  final SwapServerSettings _servers;

  const GetSwapServerUsecase(this._servers);

  @useResult
  Future<Result<({SwapServer server, NetworkEnv environment}), SwapsFailure>>
  execute() => _servers.readServer();
}
