import 'package:bull_ui/bull_ui.dart' show BuildContext, Widget;
import 'package:primitives/primitives.dart';

import 'domain/ark_display_data_port.dart';
import 'domain/ark_failure.dart';

/// What only the app can give Ark: its wallets' operations, its artwork and
/// its navigation. The app's composition root supplies them; every one is
/// optional, and Ark goes without what is missing.
final class ArkAppServices {
  /// A fresh unused receive address of [walletId], for an exit's funds.
  final Future<Result<String, ArkFailure>> Function(String walletId)?
  nextReceiveAddress;

  /// Sends [amount] from [walletId] to [address], as the wallet's own sends
  /// do; the txid. Pays an emergency exit's fees into the reserve.
  final Future<Result<String, ArkFailure>> Function(
    String walletId,
    String address,
    Sats amount,
  )?
  send;

  /// How the wallet list names [walletId], for reviews.
  final Future<ArkSourceWalletName?> Function(String walletId)? walletName;

  /// The Secure Bitcoin wallet card's artwork, for Ark's wallet card.
  final Widget? walletBackground;

  /// The arrow the app's send confirmation shows.
  final Widget? confirmIcon;

  /// Returns to the app's home after a finished flow.
  final void Function(BuildContext context)? onHome;

  const ArkAppServices({
    this.nextReceiveAddress,
    this.send,
    this.walletName,
    this.walletBackground,
    this.confirmIcon,
    this.onHome,
  });
}
