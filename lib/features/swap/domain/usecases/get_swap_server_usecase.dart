import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart'
    show SwapServer, SwapServerSettings, SwapsUnsupportedNetworkFailure;

class GetSwapServerUsecase {
  final SwapServerSettings _servers;

  const GetSwapServerUsecase(this._servers);

  @useResult
  Future<Result<({SwapServer server, NetworkEnv environment}), SwapFailure>>
  execute() async => (await _servers.readServer()).mapErr(
    (failure) => switch (failure) {
      SwapsUnsupportedNetworkFailure() => const SwapUnsupportedNetworkFailure(),
      _ => const SwapStorageFailure(),
    },
  );
}
