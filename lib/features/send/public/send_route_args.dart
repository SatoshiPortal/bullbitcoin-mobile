import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SendRouteArgs {
  final Wallet? wallet;
  final String? pendingTransactionId;
  final bool isSpMode;
  final Set<Outpoint> selectedOutpoints;
  final bool isSweep;

  const SendRouteArgs({
    this.wallet,
    this.pendingTransactionId,
    this.isSpMode = false,
  }) : selectedOutpoints = const {},
       isSweep = false;

  const SendRouteArgs.sp()
    : wallet = null,
      pendingTransactionId = null,
      isSpMode = true,
      selectedOutpoints = const {},
      isSweep = false;

  SendRouteArgs.selected({
    required Wallet this.wallet,
    required Set<Outpoint> outpoints,
  }) : pendingTransactionId = null,
       isSpMode = false,
       selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = false {
    _validate();
  }

  SendRouteArgs.sweep({
    required Wallet this.wallet,
    required Set<Outpoint> outpoints,
  }) : pendingTransactionId = null,
       isSpMode = false,
       selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = true {
    _validate();
  }

  void _validate() {
    if (selectedOutpoints.isEmpty) {
      throw ArgumentError.value(
        selectedOutpoints,
        'outpoints',
        'must not be empty',
      );
    }
  }
}
