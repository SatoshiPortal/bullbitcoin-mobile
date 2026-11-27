import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class SetSwapServerUsecase {
  final SwapServerSettings _servers;

  const SetSwapServerUsecase(this._servers);

  @useResult
  Future<Result<SwapServer, SwapsFailure>> execute(
    String input, {
    SwapServerCredentials? credentials,
  }) => _servers.setServer(input, credentials: credentials);
}
