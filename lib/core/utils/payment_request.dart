import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip21_uri/bip21_uri.dart';
import 'package:boltz/boltz.dart' as boltz;
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

  const factory PaymentRequest.psbt({required String psbt}) =
      PsbtPaymentRequest;

  const PaymentRequest._();

  int? get amountSat => switch (this) {
    BitcoinPaymentRequest() => null,
    LiquidPaymentRequest() => null,
    LnAddressPaymentRequest() => null,
    Bolt11PaymentRequest(amountSat: final amountSat) => amountSat,
    Bip21PaymentRequest(amountSat: final amountSat) => amountSat,
    PsbtPaymentRequest() => null,
  };

  static Future<PaymentRequest> parse(String data) async {
    try {
      final String trimmed = data.trim();

      if (trimmed.toLowerCase().startsWith('bitcoin:') ||
          trimmed.toLowerCase().startsWith('liquidnetwork:') ||
          trimmed.toLowerCase().startsWith('liquidtestnet:')) {
        final result = await _tryParseBip21(trimmed);
        if (result != null) return result;
      }

      if (trimmed.toLowerCase().startsWith('lnbc') ||
          trimmed.toLowerCase().startsWith('lntb') ||
          trimmed.toLowerCase().startsWith('lightning:')) {
        if (trimmed.toLowerCase().startsWith('lightning:')) {
          final withoutPrefix = trimmed
              .replaceAll("lightning:", "")
              .replaceAll("LIGHTNING:", "");
          if (withoutPrefix.toLowerCase().startsWith('lnurl') ||
              withoutPrefix.contains('@')) {
            final result = await _tryParseLnAddress(withoutPrefix);
            if (result != null) return result;
          } else {
            final result = await _tryParseBolt11(withoutPrefix.toLowerCase());
            if (result != null) return result;
          }
        } else {
          final result = await _tryParseBolt11(trimmed.toLowerCase());
          if (result != null) return result;
        }
      }

      if (trimmed.toLowerCase().startsWith('lnurl') || trimmed.contains('@')) {
        final result = await _tryParseLnAddress(trimmed);
        if (result != null) return result;
      }

      if (trimmed.startsWith('1') ||
          trimmed.startsWith('3') ||
          trimmed.toLowerCase().startsWith('bc1') ||
          trimmed.startsWith('2') ||
          trimmed.startsWith('m') ||
          trimmed.startsWith('n') ||
          trimmed.toLowerCase().startsWith('tb1')) {
        final result = await _tryParseBitcoinAddress(trimmed);
        if (result != null) return result;
      }

      final liquid = await _tryParseLiquidAddress(trimmed);
      if (liquid != null) return liquid;

      final psbt = await _tryParsePsbt(data);
      if (psbt != null) return psbt;

      throw 'Invalid payment request';
    } catch (e) {
      log.severe(e.toString());
      rethrow;
    }
  }

  static Future<PaymentRequest?> _tryParseBitcoinAddress(String data) async {
    final bool tryTestnetFirst =
        data.startsWith('2') ||
        data.startsWith('m') ||
        data.startsWith('n') ||
        data.startsWith('tb1');

    if (!tryTestnetFirst) {
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
    }

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

    return null;
  }

  static Future<PaymentRequest?> _tryParseBip21(String data) async {
    if (!data.startsWith('bitcoin:') &&
        !data.startsWith('liquidnetwork:') &&
        !data.startsWith('liquidtestnet:')) {
      return null;
    }

    try {
      final uri = bip21.decode(data);
      final address = uri.address;
      Network network;

      if (uri.scheme == 'bitcoin') {
        if (address.startsWith('1') ||
            address.startsWith('3') ||
            address.startsWith('bc1')) {
          network = Network.bitcoinMainnet;
          await bdk.Address.fromString(
            s: address,
            network: bdk.Network.bitcoin,
          );
        } else if (address.startsWith('2') ||
            address.startsWith('m') ||
            address.startsWith('n') ||
            address.startsWith('tb1')) {
          network = Network.bitcoinTestnet;
          await bdk.Address.fromString(
            s: address,
            network: bdk.Network.testnet,
          );
        } else {
          network = await _validateBitcoinAddress(address);
        }
      } else if (uri.scheme == 'liquidnetwork' || uri.scheme == 'liquid') {
        network = Network.liquidMainnet;
        final networkValidation = await lwk.Address.validate(
          addressString: address,
        );
        if (networkValidation != lwk.Network.mainnet) {
          throw 'Invalid liquid mainnet address';
        }
      } else if (uri.scheme == 'liquidtestnet') {
        network = Network.liquidTestnet;
        final networkValidation = await lwk.Address.validate(
          addressString: address,
        );
        if (networkValidation != lwk.Network.testnet) {
          throw 'Invalid liquid testnet address';
        }
      } else {
        throw 'unhandled network';
      }

      final amount = uri.amount;
      // TODO: The following line is a workaround for the issue with spaces in the 'pj' field.
      // It can be removed once PDK returns the pj field as an encoded uri string.
      uri.options['pj'] = uri.options['pj']?.replaceAll(' ', '+');

      return PaymentRequest.bip21(
        network: network,
        address: address,
        uri: uri.toString(),
        label: uri.label ?? '',
        message: uri.message ?? '',
        amountSat: amount != null ? ConvertAmount.btcToSats(amount) : null,
        lightning: uri.options['lightning'] as String? ?? '',
        pj: uri.options['pj'] as String? ?? '',
        pjos: uri.options['pjos'] as String? ?? '',
      );
    } catch (_) {}

    return null;
  }

  static Future<Network> _validateBitcoinAddress(String address) async {
    try {
      await bdk.Address.fromString(s: address, network: bdk.Network.bitcoin);
      return Network.bitcoinMainnet;
    } catch (_) {
      try {
        await bdk.Address.fromString(s: address, network: bdk.Network.testnet);
        return Network.bitcoinTestnet;
      } catch (e) {
        throw 'Invalid bitcoin address';
      }
    }
  }

  static Future<PaymentRequest?> _tryParseLiquidAddress(String data) async {
    try {
      final network = await lwk.Address.validate(addressString: data);
      return PaymentRequest.liquid(
        address: data,
        isTestnet: network == lwk.Network.testnet,
      );
    } catch (e) {
      log.warning(e.toString());
    }

    return null;
  }

  static Future<PaymentRequest?> _tryParseBolt11(String data) async {
    if (!data.toLowerCase().startsWith('lnbc') &&
        !data.toLowerCase().startsWith('lntb')) {
      return null;
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
      log.warning(e.toString());
    }

    return null;
  }

  static Future<PaymentRequest?> _tryParseLnAddress(String data) async {
    final bool isEmailStyle = data.contains('@');
    final bool isLnurlPrefix = data.toLowerCase().startsWith('lnurl');

    if (!isEmailStyle && !isLnurlPrefix) {
      return null;
    }

    try {
      final lnurl = boltz.Lnurl(value: data);
      final valid = await lnurl.validate();
      if (!valid) {
        throw 'Invalid lnurl';
      }

      return PaymentRequest.lnAddress(address: data);
    } catch (e) {
      log.warning(e.toString());
    }

    return null;
  }

  static Future<PaymentRequest?> _tryParsePsbt(String psbtBase64) async {
    try {
      final psbt = await bdk.PartiallySignedTransaction.fromString(psbtBase64);
      return PaymentRequest.psbt(psbt: psbt.toString());
    } catch (e) {
      log.warning(e.toString());
    }
    return null;
  }

  bool get isBolt11 => this is Bolt11PaymentRequest;
  bool get isLnAddress => this is LnAddressPaymentRequest;
  bool get isBip21 => this is Bip21PaymentRequest;
  bool get isBitcoinAddress => this is BitcoinPaymentRequest;
  bool get isLiquidAddress => this is LiquidPaymentRequest;
  bool get isPsbt => this is PsbtPaymentRequest;

  bool get isTestnet => switch (this) {
    BitcoinPaymentRequest(isTestnet: final isTestnet) => isTestnet,
    LiquidPaymentRequest(isTestnet: final isTestnet) => isTestnet,
    Bolt11PaymentRequest(isTestnet: final isTestnet) => isTestnet,
    Bip21PaymentRequest(network: final network) => network.isTestnet,
    LnAddressPaymentRequest() => false,
    PsbtPaymentRequest() => false,
  };

  String get name => switch (this) {
    BitcoinPaymentRequest() => 'Bitcoin Onchain',
    LiquidPaymentRequest() => 'Liquid Onchain',
    LnAddressPaymentRequest() => 'Lightning Address',
    Bolt11PaymentRequest() => 'Bolt11',
    Bip21PaymentRequest() => 'BIP21',
    PsbtPaymentRequest() => 'PSBT',
  };
}
