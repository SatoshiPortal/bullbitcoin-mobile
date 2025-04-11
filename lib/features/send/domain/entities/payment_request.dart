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
  lnAddress,
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

  const factory PaymentRequest.lnAddress({
    required PaymentType type,
    required Network network,
    required String address,
  }) = LnAddressRequest;

  const factory PaymentRequest.bolt11({
    required PaymentType type,
    required int amountSat,
    required Network network,
    required int expiry,
    required int expiresIn,
    required int expiresAt,
    required bool isExpired,
    required int cltvExpDelta,
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
          try {
            await bdk.Address.fromString(s: data, network: bdk.Network.bitcoin);
            network = Network.bitcoinMainnet;
          } catch (_) {
            try {
              await bdk.Address.fromString(
                s: data,
                network: bdk.Network.testnet,
              );
              network = Network.bitcoinTestnet;
            } catch (e) {
              rethrow;
            }
          }

          // TODO: add signet and regtest to Network entity
          // try {
          //   await bdk.Address.fromString(s: data, network: bdk.Network.signet);
          //   network = Network.signet;
          // } catch (_) {}

          // try {
          //   await bdk.Address.fromString(s: data, network: bdk.Network.regtest);
          //   network = Network.regtest;
          // } catch (_) {}
        } else if (uri.urnScheme == 'liquidnetwork') {
          network = Network.liquidMainnet;
        } else if (uri.urnScheme == 'liquidtestnet') {
          network = Network.liquidTestnet;
        } else {
          throw 'unhandled network';
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
        final sats = invoice.msats.toInt() ~/ 1000;

        return PaymentRequest.bolt11(
          type: PaymentType.bolt11,
          amountSat: sats,
          network: invoice.network == 'bitcoin'
              ? Network.bitcoinMainnet
              : Network.liquidMainnet,
          expiry: invoice.expiry.toInt(),
          expiresIn: invoice.expiresIn.toInt(),
          expiresAt: invoice.expiresAt.toInt(),
          isExpired: invoice.isExpired,
          cltvExpDelta: invoice.cltvExpDelta.toInt(),
          preimageHash: invoice.preimageHash,
          bip21: invoice.bip21,
        );
      } catch (e) {
        debugPrint(e.toString());
      }
      try {
        final valid = await boltz.validateLnurl(lnurl: data);
        if (!valid) {
          throw 'Invalid lnurl';
        }

        return PaymentRequest.lnAddress(
          type: PaymentType.lnAddress,
          network: Network.bitcoinMainnet,
          address: data,
        );
      } catch (e) {
        debugPrint(e.toString());
      }

      throw 'Invalid payment request';
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}

extension PaymentRequestMethods on PaymentRequest {
  bool get isBolt11 => this is Bolt11Request;
}
