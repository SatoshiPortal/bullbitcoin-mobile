import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

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
    int? amountSat,
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

      final parsed = await satoshifier.Satoshifier.parse(trimmed);

      return switch (parsed) {
        satoshifier.Bip21() => PaymentRequest.bip21(
          address: parsed.address,
          uri: parsed.uri,
          network: Network.fromSatoshifier(parsed.network),
          label: parsed.label,
          message: parsed.message,
          amountSat: parsed.sats,
          lightning: parsed.lightning,
          // TODO: The following line is a workaround for the issue with spaces in the 'pj' field.
          // TODO: It can be removed once PDK returns the pj field as an encoded uri string.
          pj: parsed.pj.replaceAll(' ', '+'),
          pjos: parsed.pjos,
        ),
        satoshifier.BitcoinAddress() => PaymentRequest.bitcoin(
          address: parsed.address,
          isTestnet: parsed.network.isTestnet,
        ),
        satoshifier.LiquidAddress() => PaymentRequest.liquid(
          address: parsed.address,
          isTestnet: parsed.network.isTestnet,
        ),
        satoshifier.Bolt11() => PaymentRequest.bolt11(
          invoice: parsed.invoice,
          amountSat: parsed.sats,
          paymentHash: parsed.paymentHash,
          description: parsed.description,
          expiresAt: parsed.expiresAt,
          isTestnet: parsed.isTestnet,
        ),
        satoshifier.Psbt() => PaymentRequest.psbt(psbt: parsed.psbt),
        satoshifier.Lnurl() => PaymentRequest.lnAddress(
          address: parsed.address,
        ),
        _ => throw 'Invalid payment request',
      };
    } catch (e) {
      log.severe(e.toString());
      rethrow;
    }
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
