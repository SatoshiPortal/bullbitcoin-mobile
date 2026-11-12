import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SendRouteArgs {
  final Wallet? wallet;
  final bool isSpMode;
  final Set<Outpoint> sweepOutpoints;

  const SendRouteArgs({this.wallet, this.isSpMode = false})
    : sweepOutpoints = const {};

  const SendRouteArgs.sp()
    : wallet = null,
      isSpMode = true,
      sweepOutpoints = const {};

  SendRouteArgs.sweep({
    required Wallet wallet,
    required Set<Outpoint> outpoints,
  }) : wallet = wallet,
       isSpMode = false,
       sweepOutpoints = Set.unmodifiable(outpoints) {
    if (!wallet.isBitcoin) {
      throw ArgumentError.value(
        wallet.id,
        'wallet',
        'must be a Bitcoin wallet',
      );
    }
    if (sweepOutpoints.isEmpty) {
      throw ArgumentError.value(outpoints, 'outpoints', 'must not be empty');
    }
  }
}
