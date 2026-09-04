import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SendRouteArgs {
  final Wallet? wallet;
  final bool isSpMode;
  final Set<Outpoint> selectedOutpoints;
  final bool isSweep;

  const SendRouteArgs({this.wallet, this.isSpMode = false}) : selectedOutpoints = const {}, isSweep = false;

  const SendRouteArgs.sp() : wallet = null, isSpMode = true, selectedOutpoints = const {}, isSweep = false;

  SendRouteArgs.selected({
    required Wallet wallet,
    required Set<Outpoint> outpoints,
  }) : wallet = wallet, isSpMode = false, selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = false {
    _validate();
  }

  SendRouteArgs.sweep({required Wallet wallet, required Set<Outpoint> outpoints})
    : wallet = wallet, isSpMode = false, selectedOutpoints = Set.unmodifiable(outpoints),
      isSweep = true {
    _validate();
  }

  void _validate() {
    final wallet = this.wallet!;
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
