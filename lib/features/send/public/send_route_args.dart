import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SendRouteArgs {
  final Wallet wallet;
  final Set<Outpoint> sweepOutpoints;

  SendRouteArgs.sweep({required this.wallet, required Set<Outpoint> outpoints})
    : sweepOutpoints = Set.unmodifiable(outpoints) {
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
