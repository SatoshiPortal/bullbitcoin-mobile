import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';

class PreparedPrivateInvoiceCreate {
  final EncryptedPrivateInvoice encrypted;
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

  PreparedPrivateInvoiceCreate({
    required this.encrypted,
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
    this.reservationLabelIds = const [],
  }) {
    final hasSat = amountSat != null;
    final hasFiat = fiatAmountMinor != null && fiatCurrency != null;
    final reservationIdsAreValid =
        reservationLabelIds.every((id) => id > 0) &&
        reservationLabelIds.toSet().length == reservationLabelIds.length;
    if (hasSat == hasFiat ||
        (amountSat != null && amountSat! <= 0) ||
        (fiatAmountMinor != null && fiatAmountMinor! <= 0) ||
        (fiatCurrency != null && fiatCurrency!.trim().isEmpty) ||
        (!acceptBtc && !acceptLn && !acceptLiquid) ||
        (acceptBtc && (bitcoinAddress == null || bitcoinAddress!.isEmpty)) ||
        ((acceptLn || acceptLiquid) &&
            (liquidAddress == null || liquidAddress!.isEmpty)) ||
        (acceptLiquid &&
            (liquidBlindingKeyHex == null ||
                !RegExp(
                  r'^[0-9a-fA-F]{64}$',
                ).hasMatch(liquidBlindingKeyHex!))) ||
        (expiresAtUnix != null && expiresAtUnix! <= 0) ||
        (linkToPageNym != null && linkToPageNym!.trim().isEmpty) ||
        !reservationIdsAreValid) {
      throw ArgumentError('invalid prepared private invoice operation');
    }
  }

  @override
  String toString() => 'PreparedPrivateInvoiceCreate(<redacted>)';
}
