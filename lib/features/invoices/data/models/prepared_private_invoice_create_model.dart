import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';

class PreparedPrivateInvoiceCreateModel {
  final String clientRequestId;
  final String presentationEnvelope;
  final String viewingKey;
  final int? amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? liquidBlindingKeyHex;
  final int? expiresAtUnix;
  final String? linkToPageNym;
  final List<int> reservationLabelIds;

  const PreparedPrivateInvoiceCreateModel({
    required this.clientRequestId,
    required this.presentationEnvelope,
    required this.viewingKey,
    this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    this.bitcoinAddress,
    this.liquidAddress,
    this.liquidBlindingKeyHex,
    this.expiresAtUnix,
    this.linkToPageNym,
    required this.reservationLabelIds,
  });

  factory PreparedPrivateInvoiceCreateModel.fromEntity(
    PreparedPrivateInvoiceCreate entity,
  ) {
    return PreparedPrivateInvoiceCreateModel(
      clientRequestId: entity.encrypted.clientRequestId,
      presentationEnvelope: entity.encrypted.presentationEnvelope,
      viewingKey: entity.encrypted.viewingKey,
      amountSat: entity.amountSat,
      fiatAmountMinor: entity.fiatAmountMinor,
      fiatCurrency: entity.fiatCurrency,
      acceptBtc: entity.acceptBtc,
      acceptLn: entity.acceptLn,
      acceptLiquid: entity.acceptLiquid,
      bitcoinAddress: entity.bitcoinAddress,
      liquidAddress: entity.liquidAddress,
      liquidBlindingKeyHex: entity.liquidBlindingKeyHex,
      expiresAtUnix: entity.expiresAtUnix,
      linkToPageNym: entity.linkToPageNym,
      reservationLabelIds: List.unmodifiable(entity.reservationLabelIds),
    );
  }

  factory PreparedPrivateInvoiceCreateModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PreparedPrivateInvoiceCreateModel(
      clientRequestId: json['client_request_id'] as String,
      presentationEnvelope: json['presentation_envelope'] as String,
      viewingKey: json['viewing_key'] as String,
      amountSat: json['amount_sat'] as int?,
      fiatAmountMinor: json['fiat_amount_minor'] as int?,
      fiatCurrency: json['fiat_currency'] as String?,
      acceptBtc: json['accept_btc'] as bool,
      acceptLn: json['accept_ln'] as bool,
      acceptLiquid: json['accept_liquid'] as bool,
      bitcoinAddress: json['bitcoin_address'] as String?,
      liquidAddress: json['liquid_address'] as String?,
      liquidBlindingKeyHex: json['liquid_blinding_key_hex'] as String?,
      expiresAtUnix: json['expires_at_unix'] as int?,
      linkToPageNym: json['link_to_page_nym'] as String?,
      reservationLabelIds: (json['reservation_label_ids'] as List<dynamic>)
          .cast<int>(),
    );
  }

  Map<String, Object?> toJson() => {
    'client_request_id': clientRequestId,
    'presentation_envelope': presentationEnvelope,
    'viewing_key': viewingKey,
    'amount_sat': amountSat,
    'fiat_amount_minor': fiatAmountMinor,
    'fiat_currency': fiatCurrency,
    'accept_btc': acceptBtc,
    'accept_ln': acceptLn,
    'accept_liquid': acceptLiquid,
    'bitcoin_address': bitcoinAddress,
    'liquid_address': liquidAddress,
    'liquid_blinding_key_hex': liquidBlindingKeyHex,
    'expires_at_unix': expiresAtUnix,
    'link_to_page_nym': linkToPageNym,
    'reservation_label_ids': reservationLabelIds,
  };

  PreparedPrivateInvoiceCreate toEntity() {
    return PreparedPrivateInvoiceCreate(
      encrypted: EncryptedPrivateInvoice(
        clientRequestId: clientRequestId,
        presentationEnvelope: presentationEnvelope,
        viewingKey: viewingKey,
      ),
      amountSat: amountSat,
      fiatAmountMinor: fiatAmountMinor,
      fiatCurrency: fiatCurrency,
      acceptBtc: acceptBtc,
      acceptLn: acceptLn,
      acceptLiquid: acceptLiquid,
      bitcoinAddress: bitcoinAddress,
      liquidAddress: liquidAddress,
      liquidBlindingKeyHex: liquidBlindingKeyHex,
      expiresAtUnix: expiresAtUnix,
      linkToPageNym: linkToPageNym,
      reservationLabelIds: List.unmodifiable(reservationLabelIds),
    );
  }
}
