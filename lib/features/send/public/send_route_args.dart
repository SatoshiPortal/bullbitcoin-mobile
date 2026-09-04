import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SendRouteArgs {
  final Wallet wallet;
  final Set<Outpoint> selectedOutpoints;
  final bool isSweep;

  SendRouteArgs.selected({
    required this.wallet,
    required Set<Outpoint> outpoints,
  }) : selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = false {
    _validate();
  }

  SendRouteArgs.sweep({required this.wallet, required Set<Outpoint> outpoints})
    : selectedOutpoints = Set.unmodifiable(outpoints),
      isSweep = true {
    _validate();
  }

  void _validate() {
    if (!wallet.isBitcoin) {
      throw ArgumentError.value(
        wallet.id,
        'wallet',
        'must be a Bitcoin wallet',
      );
    }
    if (selectedOutpoints.isEmpty) {
      throw ArgumentError.value(
        selectedOutpoints,
        'outpoints',
        'must not be empty',
      );
    }
  }
}
