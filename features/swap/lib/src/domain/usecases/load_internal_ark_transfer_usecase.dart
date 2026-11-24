import 'package:bull_ark/bull_ark.dart';
import 'package:primitives/primitives.dart';

import 'package:swaps/order_swaps.dart';

final class LoadInternalArkTransferUsecase {
  final ArkTransferFacade? Function() _facade;
  const LoadInternalArkTransferUsecase(this._facade);

  Future<Result<ArkTransferContext, SwapFailure>> execute() async {
    final facade = _facade();
    if (facade == null) return const Err(SwapUnsupportedNetworkFailure());
    try {
      return switch (await facade.load()) {
        Ok(:final value) => Ok(value),
        Err() => const Err(SwapUnsupportedNetworkFailure()),
      };
    } on Exception {
      return const Err(SwapProviderFailure());
    }
  }
}
