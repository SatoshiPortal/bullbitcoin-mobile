import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../default_wallets_failure.dart';

final class GetDefaultWalletsUsecase {
  final Exchange _exchange;

  const GetDefaultWalletsUsecase(this._exchange);

  @useResult
  Future<Result<DefaultWallets, DefaultWalletsFailure>> execute() async =>
      (await _exchange.getDefaultWallets()).mapErr(
        (_) => const DefaultWalletsLoadFailure(),
      );
}
