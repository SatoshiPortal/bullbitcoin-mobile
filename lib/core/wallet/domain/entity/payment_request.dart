import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:boltz/boltz.dart' as boltz;
import 'package:dart_bip21/dart_bip21.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lwk/lwk.dart' as lwk;

part 'payment_request.freezed.dart';

@freezed
class PaymentRequest with _$PaymentRequest {
  const factory PaymentRequest.bitcoin({
    required Network network,
    required String address,
  }) = BitcoinRequest;

  const factory PaymentRequest.liquid({
    required Network network,
    required String address,
  }) = LiquidRequest;

  const factory PaymentRequest.bolt11({
    required Network network,
    required BigInt amount,
    required BigInt expiry,
    required BigInt expiresIn,
    required BigInt expiresAt,
    required bool isExpired,
    required BigInt cltvExpDelta,
    required String preimageHash,
    String? bip21,
  }) = Bolt11Request;

  const factory PaymentRequest.bip21({
    required Network network,
    required String address,
    required String uri,
    required String scheme,
    required Map<String, dynamic> options,
  }) = Bip21Request;

  static Future<PaymentRequest> parse(String data) async {
    // lnbc –> lightning
    //
    // BitcoinAddressOnly - bdk.Address
    // LiquidAddressOnly - lwk.Address
    // BitcoinBip21 - bdk.Address
    // LiquidBip21 - lwk.Address
    // Bolt11 - boltz.DecodedInvoice
    // Bolt12 - boltz (pending)
    // LnUrlWithdraw - boltz (pending)
    // LnUrlPay - boltz (pending)

    try {
      final address =
          await bdk.Address.fromString(s: data, network: bdk.Network.bitcoin);
      return PaymentRequest.bitcoin(
        address: address.asString(),
        network: Network.bitcoinMainnet,
      );
    } catch (_) {}

    try {
      final address =
          await bdk.Address.fromString(s: data, network: bdk.Network.testnet);
      return PaymentRequest.bitcoin(
        address: address.asString(),
        network: Network.bitcoinTestnet,
      );
    } catch (_) {}

    try {
      final uri = bip21.decode(data);
      Network network;
      if (uri.urnScheme == 'bitcoin') {
        network = Network.bitcoinMainnet;
      } else if (uri.urnScheme == 'liquid') {
        network = Network.liquidMainnet;
      } else {
        throw 'unhandled network'; // TODO(azad): ask how to deal with testnet
      }

      return PaymentRequest.bip21(
        network: network,
        address: uri.address,
        uri: uri.toString(),
        scheme: uri.urnScheme,
        options: uri.options,
      );
    } catch (_) {}

    try {
      final network = await lwk.Address.validate(addressString: data);
      if (network.name == 'mainnet') {
        return PaymentRequest.liquid(
          address: data,
          network: Network.liquidMainnet,
        );
      } else {
        return PaymentRequest.liquid(
          address: data,
          network: Network.liquidTestnet,
        );
      }
    } catch (_) {}

    try {
      final invoice = await boltz.DecodedInvoice.fromString(s: data);

      return PaymentRequest.bolt11(
        amount: invoice.msats,
        expiry: invoice.expiry,
        expiresIn: invoice.expiresIn,
        expiresAt: invoice.expiresAt,
        isExpired: invoice.isExpired,
        network: Network.bitcoinMainnet, // TODO(azad): is it correct?
        cltvExpDelta: invoice.cltvExpDelta,
        preimageHash: invoice.preimageHash,
      );
    } catch (_) {}

    throw 'Unsupported $PaymentRequest payload';
  }
}
