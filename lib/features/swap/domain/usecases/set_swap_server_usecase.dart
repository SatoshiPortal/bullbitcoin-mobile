import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class SetSwapServerUsecase {
  final SwapServerSettings _servers;

  const SetSwapServerUsecase(this._servers);

  @useResult
  Future<Result<SwapServer, SwapFailure>> execute(String input) async =>
      (await _servers.setServer(input)).mapErr(
        (failure) => switch (failure) {
          SwapsBusyFailure() => const SwapServerBusyFailure(),
          SwapsUnsupportedNetworkFailure() =>
            const SwapUnsupportedNetworkFailure(),
          SwapsInvalidServerFailure(:final logMessage) => SwapValidationFailure(
            field: 'server',
            logMessage: logMessage,
          ),
          _ => const SwapStorageFailure(),
        },
      );
}
