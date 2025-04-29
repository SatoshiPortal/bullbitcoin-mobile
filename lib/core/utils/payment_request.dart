import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:boltz/boltz.dart' as boltz;
import 'package:dart_bip21/dart_bip21.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lwk/lwk.dart' as lwk;

part 'payment_request.freezed.dart';

@freezed
sealed class PaymentRequest with _$PaymentRequest {
  const factory PaymentRequest.bitcoin({
    required String address,
    required bool isTestnet,
  }) = BitcoinPaymentRequest;

  const factory PaymentRequest.liquid({
    required String address,
    required bool isTestnet,
  }) = LiquidPaymentRequest;

  const factory PaymentRequest.lnAddress({required String address}) =
      LnAddressPaymentRequest;

  const factory PaymentRequest.bolt11({
    required String invoice,
    required int amountSat,
    required String paymentHash,
    @Default('') String description,
    required int expiresAt,
    required bool isTestnet,
  }) = Bolt11PaymentRequest;

  const factory PaymentRequest.bip21({
    required Network network,
    required String uri,
    required String address,
    @Default('') String label,
    @Default('') String message,
    int? amountSat,
    @Default('') String lightning,
    @Default('') String pj,
    @Default('') String pjos,
  }) = Bip21PaymentRequest;

  const PaymentRequest._();

  static Future<PaymentRequest> parse(String data) async {
    try {
      try {
        final address = await bdk.Address.fromString(
          s: data,
          network: bdk.Network.bitcoin,
        );

        return PaymentRequest.bitcoin(
          address: address.asString(),
          isTestnet: false,
        );
      } catch (_) {}

      try {
        final address = await bdk.Address.fromString(
          s: data,
          network: bdk.Network.testnet,
        );

        return PaymentRequest.bitcoin(
          address: address.asString(),
          isTestnet: true,
        );
      } catch (_) {}

      try {
        final uri = bip21.decode(data);
        final address = uri.address;
        Network network;
        if (uri.urnScheme == 'bitcoin') {
          try {
            await bdk.Address.fromString(
              s: address,
              network: bdk.Network.bitcoin,
            );
            network = Network.bitcoinMainnet;
          } catch (_) {
            try {
              await bdk.Address.fromString(
                s: address,
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

        final amount = uri.options['amount'] as double?;
        return PaymentRequest.bip21(
          network: network,
          address: address,
          uri: uri.toString(),
          label: uri.options['label'] as String? ?? '',
          message: uri.options['message'] as String? ?? '',
          amountSat: amount != null ? ConvertAmount.btcToSats(amount) : null,
          lightning: uri.options['lightning'] as String? ?? '',
          pj: uri.options['pj'] as String? ?? '',
          pjos: uri.options['pjos'] as String? ?? '',
        );
      } catch (_) {}

      try {
        final network = await lwk.Address.validate(addressString: data);
        return PaymentRequest.liquid(
          address: data,
          isTestnet: network == lwk.Network.testnet,
        );
      } catch (e) {
        debugPrint(e.toString());
      }

      try {
        final invoice = await boltz.DecodedInvoice.fromString(s: data);
        final sats = invoice.msats.toInt() ~/ 1000;

        return PaymentRequest.bolt11(
          invoice: data,
          amountSat: sats,
          paymentHash: invoice.preimageHash,
          description: invoice.description,
          expiresAt: invoice.expiresAt.toInt(),
          isTestnet: invoice.network != 'bitcoin',
        );
      } catch (e) {
        debugPrint(e.toString());
      }
      try {
        final lnurl = boltz.Lnurl(value: data);
        final valid = await lnurl.validate();
        if (!valid) {
          throw 'Invalid lnurl';
        }

        return PaymentRequest.lnAddress(address: data);
      } catch (e) {
        debugPrint(e.toString());
      }

      throw 'Invalid payment request';
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  bool get isBolt11 => this is Bolt11PaymentRequest;
  bool get isLnAddress => this is LnAddressPaymentRequest;
  bool get isBip21 => this is Bip21PaymentRequest;
  bool get isBitcoinAddress => this is BitcoinPaymentRequest;
  bool get isLiquidAddress => this is LiquidPaymentRequest;

  bool get isTestnet => switch (this) {
    BitcoinPaymentRequest(isTestnet: final isTestnet) => isTestnet,
    LiquidPaymentRequest(isTestnet: final isTestnet) => isTestnet,
    Bolt11PaymentRequest(isTestnet: final isTestnet) => isTestnet,
    Bip21PaymentRequest(network: final network) => network.isTestnet,
    _ => false,
  };

  String get name => switch (this) {
    BitcoinPaymentRequest() => 'Bitcoin Onchain',
    LiquidPaymentRequest() => 'Liquid Onchain',
    LnAddressPaymentRequest() => 'Lightning Address',
    Bolt11PaymentRequest() => 'Bolt11',
    Bip21PaymentRequest() => 'BIP21',
  };
}
