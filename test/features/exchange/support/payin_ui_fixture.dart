import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

ExchangePayinUi payinTestUi({String walletHome = '/wallet'}) => (
  walletCards: (_, _) => const SizedBox.shrink(),
  addressViewer: (_, address, {style, color, textAlign}) =>
      AddressViewer(address, style: style, color: color, textAlign: textAlign),
  openWalletHome: (context) => context.go(walletHome),
  openOrder: (_, _, {required returnToExchange}) {},
  openPayjoinTransaction: (_, _) {},
  brandAsset: Assets.logos.bbLogoSmall.path,
  successAsset: Assets.animations.successTick.path,
);
