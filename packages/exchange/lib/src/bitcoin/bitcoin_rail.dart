import 'package:meta/meta.dart';

import '../data/btc_network_wire.dart';
import '../domain/entities/btc_network.dart';
import '../domain/entities/order.dart';

/// Where a sell or pay payin goes, read from its order by the payin's rail:
/// an on-chain address, a Liquid address or a Lightning invoice.
@immutable
sealed class DepositTarget {
  const DepositTarget();

  BtcNetwork get network;

  /// The address or invoice.
  String get value;
}

final class OnchainDeposit extends DepositTarget {
  final String address;

  const OnchainDeposit(this.address);

  @override
  BtcNetwork get network => BtcNetwork.bitcoin;

  @override
  String get value => address;

  @override
  bool operator ==(Object other) =>
      other is OnchainDeposit && other.address == address;

  @override
  int get hashCode => Object.hash(OnchainDeposit, address);

  @override
  String toString() => 'OnchainDeposit($address)';
}

final class LiquidDeposit extends DepositTarget {
  final String address;

  const LiquidDeposit(this.address);

  @override
  BtcNetwork get network => BtcNetwork.liquid;

  @override
  String get value => address;

  @override
  bool operator ==(Object other) =>
      other is LiquidDeposit && other.address == address;

  @override
  int get hashCode => Object.hash(LiquidDeposit, address);

  @override
  String toString() => 'LiquidDeposit($address)';
}

final class LightningInvoiceDeposit extends DepositTarget {
  final String invoice;

  const LightningInvoiceDeposit(this.invoice);

  @override
  BtcNetwork get network => BtcNetwork.lightning;

  @override
  String get value => invoice;

  @override
  bool operator ==(Object other) =>
      other is LightningInvoiceDeposit && other.invoice == invoice;

  @override
  int get hashCode => Object.hash(LightningInvoiceDeposit, invoice);

  @override
  String toString() => 'LightningInvoiceDeposit($invoice)';
}

/// What a rail reads as an order's deposit.
@immutable
sealed class DepositRead {
  const DepositRead();
}

final class DepositGiven extends DepositRead {
  final DepositTarget target;

  const DepositGiven(this.target);

  @override
  bool operator ==(Object other) =>
      other is DepositGiven && other.target == target;

  @override
  int get hashCode => Object.hash(DepositGiven, target);

  @override
  String toString() => 'DepositGiven($target)';
}

/// The order is paid in on this rail but carries no deposit for it.
final class DepositNotGiven extends DepositRead {
  const DepositNotGiven();

  @override
  bool operator ==(Object other) => other is DepositNotGiven;

  @override
  int get hashCode => (DepositNotGiven).hashCode;
}

/// The order is paid in by [payinMethod], not by this rail.
final class DepositOnOtherRail extends DepositRead {
  final OrderPaymentMethod payinMethod;

  const DepositOnOtherRail(this.payinMethod);

  @override
  bool operator ==(Object other) =>
      other is DepositOnOtherRail && other.payinMethod == payinMethod;

  @override
  int get hashCode => Object.hash(DepositOnOtherRail, payinMethod);
}

/// One bitcoin network as the exchange uses it (composition §3.3): the rules
/// flows used to branch on (bitcoin vs Liquid vs Lightning) live here, so a
/// flow asks its rail instead of switching on the network.
///
/// Address validation and the BIP21 link need the app's address parser and
/// URI builder; they stay in the app and `bull_exchange`
/// (`ExchangeLiquidAsset.paymentUri`) and take the rail's [network].
@immutable
sealed class BitcoinRail {
  const BitcoinRail();

  BtcNetwork get network;

  /// The `network` / `bitcoinNetwork` parameter of buy, sell and pay orders.
  String get orderNetworkWire => BtcNetworkWire.orderNetwork(network);

  /// The `recipientType` of a payout address on this rail.
  String get recipientTypeWire => BtcNetworkWire.recipientType(network);

  /// One of the app's own wallets can pay in or receive on this rail.
  bool get canBeAppWallet;

  /// A sell or pay can be paid in from outside the app on this rail.
  bool get canBeExternalPayin;

  /// Buy can pay out to one of the app's wallets on this rail (decided:
  /// bitcoin and Liquid).
  bool get canBeBuyAppWallet;

  /// Buy can pay out to a typed address on this rail (decided: bitcoin only;
  /// the API takes all three, kept for later).
  bool get canBeBuyExternal;

  /// The payin may go through payjoin (`usePayjoin` is bitcoin only).
  bool get supportsPayjoin;

  /// The order payin method of a payin on this rail.
  OrderPaymentMethod get payinMethod;

  DepositTarget _target(String value);

  String? _depositOf(Order order);

  /// The deposit [order] gives this rail. Only this rail's own field is read,
  /// so a Lightning order without an on-chain address is not a missing
  /// deposit (PAY-1), and a Liquid order never shows its bitcoin address.
  DepositRead depositOf(Order order) {
    if (order.payinMethod != payinMethod) {
      return DepositOnOtherRail(order.payinMethod);
    }
    final value = _depositOf(order);
    if (value == null || value.isEmpty) return const DepositNotGiven();
    return DepositGiven(_target(value));
  }

  /// Whether [order] still points at [expected]. A deposit that moved (or
  /// went) is never paid (SELL-4).
  bool keepsDeposit(DepositTarget expected, Order order) =>
      depositOf(order) == DepositGiven(expected);
}

final class OnchainBitcoinRail extends BitcoinRail {
  const OnchainBitcoinRail();

  @override
  BtcNetwork get network => BtcNetwork.bitcoin;

  @override
  bool get canBeAppWallet => true;

  @override
  bool get canBeExternalPayin => true;

  @override
  bool get canBeBuyAppWallet => true;

  @override
  bool get canBeBuyExternal => true;

  @override
  bool get supportsPayjoin => true;

  @override
  OrderPaymentMethod get payinMethod => OrderPaymentMethod.bitcoin;

  @override
  DepositTarget _target(String value) => OnchainDeposit(value);

  @override
  String? _depositOf(Order order) => switch (order) {
    SellOrder(:final bitcoinAddress) ||
    FiatPaymentOrder(:final bitcoinAddress) => bitcoinAddress,
    // Only sell and pay orders take a bitcoin payin.
    _ => null,
  };
}

final class LiquidRail extends BitcoinRail {
  const LiquidRail();

  @override
  BtcNetwork get network => BtcNetwork.liquid;

  @override
  bool get canBeAppWallet => true;

  @override
  bool get canBeExternalPayin => true;

  @override
  bool get canBeBuyAppWallet => true;

  @override
  bool get canBeBuyExternal => false;

  @override
  bool get supportsPayjoin => false;

  @override
  OrderPaymentMethod get payinMethod => OrderPaymentMethod.liquid;

  @override
  DepositTarget _target(String value) => LiquidDeposit(value);

  @override
  String? _depositOf(Order order) => switch (order) {
    SellOrder(:final liquidAddress) ||
    FiatPaymentOrder(:final liquidAddress) => liquidAddress,
    // Only sell and pay orders take a bitcoin payin.
    _ => null,
  };
}

final class LightningRail extends BitcoinRail {
  const LightningRail();

  @override
  BtcNetwork get network => BtcNetwork.lightning;

  @override
  bool get canBeAppWallet => false;

  @override
  bool get canBeExternalPayin => true;

  @override
  bool get canBeBuyAppWallet => false;

  @override
  bool get canBeBuyExternal => false;

  @override
  bool get supportsPayjoin => false;

  @override
  OrderPaymentMethod get payinMethod => OrderPaymentMethod.lnInvoice;

  @override
  DepositTarget _target(String value) => LightningInvoiceDeposit(value);

  @override
  String? _depositOf(Order order) => switch (order) {
    SellOrder(:final lightningInvoice) ||
    FiatPaymentOrder(:final lightningInvoice) => lightningInvoice,
    // Only sell and pay orders take a bitcoin payin.
    _ => null,
  };
}

/// The three rails.
abstract final class BitcoinRails {
  static const bitcoin = OnchainBitcoinRail();
  static const liquid = LiquidRail();
  static const lightning = LightningRail();

  static const all = <BitcoinRail>[bitcoin, liquid, lightning];

  static BitcoinRail of(BtcNetwork network) => switch (network) {
    BtcNetwork.bitcoin => bitcoin,
    BtcNetwork.liquid => liquid,
    BtcNetwork.lightning => lightning,
  };

  /// The rail an order is paid in on, or null for a fiat payin (or a method
  /// this build does not know).
  static BitcoinRail? ofPayinMethod(OrderPaymentMethod method) {
    for (final rail in all) {
      if (rail.payinMethod == method) return rail;
    }
    return null;
  }
}

extension BtcNetworkRail on BtcNetwork {
  BitcoinRail get rail => BitcoinRails.of(this);
}
