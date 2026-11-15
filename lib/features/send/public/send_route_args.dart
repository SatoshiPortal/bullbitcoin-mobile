import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

final class SendRouteArgs {
  final Wallet? wallet;
  final bool isSpMode;
  final Set<Outpoint> selectedOutpoints;
  final bool isSweep;
  final String? prefilledPaymentRequest;

  const SendRouteArgs({this.wallet, this.isSpMode = false})
    : selectedOutpoints = const {},
      isSweep = false,
      prefilledPaymentRequest = null;

  const SendRouteArgs.sp()
    : wallet = null,
      isSpMode = true,
      selectedOutpoints = const {},
      isSweep = false,
      prefilledPaymentRequest = null;

  const SendRouteArgs.spPrefilled(String address)
    : wallet = null,
      isSpMode = true,
      selectedOutpoints = const {},
      isSweep = false,
      prefilledPaymentRequest = address;

  const SendRouteArgs.prefilled(String paymentRequest)
    : wallet = null,
      isSpMode = false,
      selectedOutpoints = const {},
      isSweep = false,
      prefilledPaymentRequest = paymentRequest;

  SendRouteArgs.selected({
    required Wallet this.wallet,
    required Set<Outpoint> outpoints,
  }) : isSpMode = false,
       selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = false,
       prefilledPaymentRequest = null {
    _validate();
  }

  SendRouteArgs.sweep({
    required Wallet this.wallet,
    required Set<Outpoint> outpoints,
  }) : isSpMode = false,
       selectedOutpoints = Set.unmodifiable(outpoints),
       isSweep = true,
       prefilledPaymentRequest = null {
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
