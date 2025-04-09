import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:boltz/boltz.dart' as boltz;
import 'package:dart_bip21/dart_bip21.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lwk/lwk.dart' as lwk;

part 'payment_request.freezed.dart';

enum PaymentType {
  bitcoinAddress,
  liquidAddress,
  bolt11,
  bip21,
}

@freezed
class PaymentRequest with _$PaymentRequest {
  const factory PaymentRequest.bitcoin({
    required PaymentType type,
    required Network network,
    required String address,
  }) = BitcoinRequest;

  const factory PaymentRequest.liquid({
    required PaymentType type,
    required Network network,
    required String address,
  }) = LiquidRequest;

  const factory PaymentRequest.bolt11({
    required PaymentType type,
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
    required PaymentType type,
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
      try {
        final address =
            await bdk.Address.fromString(s: data, network: bdk.Network.bitcoin);

        return PaymentRequest.bitcoin(
          type: PaymentType.bitcoinAddress,
          address: address.asString(),
          network: Network.bitcoinMainnet,
        );
      } catch (_) {}

      try {
        final address =
            await bdk.Address.fromString(s: data, network: bdk.Network.testnet);

        return PaymentRequest.bitcoin(
          type: PaymentType.bitcoinAddress,
          address: address.asString(),
          network: Network.bitcoinTestnet,
        );
      } catch (_) {}

      try {
        final uri = bip21.decode(data);
        const type = PaymentType.bip21;
        Network network;
        if (uri.urnScheme == 'bitcoin') {
          network = Network.bitcoinMainnet;
        } else if (uri.urnScheme == 'liquid') {
          network = Network.liquidMainnet;
        } else {
          throw 'unhandled network'; // TODO(azad): ask how to deal with testnet
        }

        return PaymentRequest.bip21(
          type: type,
          network: network,
          address: uri.address,
          uri: uri.toString(),
          scheme: uri.urnScheme,
          options: uri.options,
        );
      } catch (_) {}

      try {
        final network = await lwk.Address.validate(addressString: data);
        const type = PaymentType.liquidAddress;
        debugPrint(network.name);
        if (network.name == 'mainnet') {
          return PaymentRequest.liquid(
            type: type,
            address: data,
            network: Network.liquidMainnet,
          );
        } else {
          return PaymentRequest.liquid(
            type: type,
            address: data,
            network: Network.liquidTestnet,
          );
        }
      } catch (e) {
        debugPrint(e.toString());
      }

      try {
        final invoice = await boltz.DecodedInvoice.fromString(s: data);

        return PaymentRequest.bolt11(
          type: PaymentType.bolt11,
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
      throw 'Invalid payment request';
    } catch (e) {
      rethrow;
    }
  }
}
