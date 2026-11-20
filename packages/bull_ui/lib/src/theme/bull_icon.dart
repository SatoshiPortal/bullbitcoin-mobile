import 'package:material_ui/material_ui.dart';

/// The curated icon set `bull_ui` exposes. Feature code references these
/// instead of Material `Icons` directly, e.g. `BullIcon(BullIcons.acUnit)`.
abstract final class BullIcons {
  static const IconData addCircleOutline = Icons.add_circle_outline;
  static const IconData removeCircleOutline = Icons.remove_circle_outline;
  static const IconData dragHandle = Icons.drag_handle;
  static const IconData candlestickChart = Icons.candlestick_chart;
  static const IconData receiptLong = Icons.receipt_long;
  static const IconData history = Icons.history;
  static const IconData supportAgent = Icons.support_agent;
  static const IconData showChart = Icons.show_chart;
  static const IconData shoppingCart = Icons.shopping_cart;
  static const IconData payments = Icons.payments;
  static const IconData swapHoriz = Icons.swap_horiz;
  static const IconData map = Icons.map;
  static const IconData settings = Icons.settings;
  static const IconData accountBalance = Icons.account_balance;
  static const IconData moreHoriz = Icons.more_horiz;
  static const IconData arrowDownward = Icons.arrow_downward;
  static const IconData tune = Icons.tune;
  static const IconData acUnit = Icons.ac_unit;
  static const IconData edit = Icons.edit;
  static const IconData expandMore = Icons.expand_more;
  static const IconData lockOpen = Icons.lock_open;
  static const IconData sync = Icons.sync;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData schedule = Icons.schedule;
  static const IconData contentCopy = Icons.content_copy;
  static const IconData qrCodeScanner = Icons.qr_code_scanner;
  static const IconData sell = Icons.sell;
  static const IconData close = Icons.close;
  static const IconData check = Icons.check;
  static const IconData swipe = Icons.swipe;
  static const IconData filterAltOff = Icons.filter_alt_off;
  static const IconData accountBalanceWallet = Icons.account_balance_wallet;
  static const IconData arrowBack = Icons.arrow_back;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData accountTree = Icons.account_tree;
  static const IconData deleteOutline = Icons.delete_outline;
  static const IconData errorOutline = Icons.error_outline;
  static const IconData callMerge = Icons.call_merge;
  static const IconData arrowUpward = Icons.arrow_upward;
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline;
  static const IconData headsetMic = Icons.headset_mic;
  static const IconData search = Icons.search;
  static const IconData verified = Icons.verified;
  static const IconData warningAmber = Icons.warning_amber_rounded;
  static const IconData currencyBitcoin = Icons.currency_bitcoin;
  static const IconData restaurant = Icons.restaurant;
  static const IconData storefront = Icons.storefront;
  static const IconData localGroceryStore = Icons.local_grocery_store;
  static const IconData localCafe = Icons.local_cafe;
  static const IconData localAtm = Icons.local_atm;
  static const IconData hotel = Icons.hotel;
  static const IconData contentCut = Icons.content_cut;
  static const IconData phoneOutlined = Icons.phone_outlined;
  static const IconData emailOutlined = Icons.email_outlined;
  static const IconData language = Icons.language;
  static const IconData link = Icons.link;
  static const IconData privacy = Icons.shield_outlined;
  static const IconData qrCode = Icons.qr_code_2;
}

/// A thin wrapper over the Flutter [Icon] so feature code never touches
/// Material's `Icon`/`Icons` directly. Pair with [BullIcons].
class BullIcon extends StatelessWidget {
  const BullIcon(this.icon, {super.key, this.size, this.color});

  /// The icon glyph — use a [BullIcons] constant.
  final IconData icon;

  /// Optional explicit size.
  final double? size;

  /// Optional explicit colour. Defaults to the ambient [IconTheme].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}
