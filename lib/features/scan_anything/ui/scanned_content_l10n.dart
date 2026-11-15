import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:flutter/material.dart';

(IconData, String) scannedContentType(
  BuildContext context,
  ScannedContent content,
) {
  final loc = context.loc;
  return switch (content) {
    BitcoinAddressContent() => (
      Icons.currency_bitcoin,
      loc.scanAnythingTypeBitcoinAddress,
    ),
    LiquidAddressContent() => (
      Icons.water_drop_outlined,
      loc.scanAnythingTypeLiquidAddress,
    ),
    Bip21Content() => (
      Icons.request_quote_outlined,
      loc.scanAnythingTypePaymentRequest,
    ),
    LightningInvoiceContent() => (
      Icons.bolt,
      loc.scanAnythingTypeLightningInvoice,
    ),
    LightningAddressContent() => (
      Icons.alternate_email,
      loc.scanAnythingTypeLightningAddress,
    ),
    DescriptorContent() => (
      Icons.account_tree_outlined,
      loc.scanAnythingTypeDescriptor,
    ),
    XpubContent() => (Icons.key_outlined, loc.scanAnythingTypeXpub),
    PsbtContent() => (Icons.draw_outlined, loc.scanAnythingTypePsbt),
    SignedTransactionContent() => (
      Icons.send_outlined,
      loc.scanAnythingTypeSignedTransaction,
    ),
    TransactionIdContent() => (
      Icons.receipt_long_outlined,
      loc.scanAnythingTypeTransactionId,
    ),
    SignerExportContent() => (
      Icons.usb_outlined,
      loc.scanAnythingTypeSignerExport,
    ),
    SilentPaymentAddressContent() => (
      Icons.volume_off_outlined,
      loc.scanAnythingTypeSilentPaymentAddress,
    ),
    ElectrumServerContent() => (
      Icons.dns_outlined,
      loc.scanAnythingTypeElectrumServer,
    ),
    LabelsExportContent() => (Icons.label_outline, loc.scanAnythingTypeLabels),
    RecoveryPhraseContent() => (
      Icons.warning_amber_outlined,
      loc.scanAnythingTypeRecoveryPhrase,
    ),
    PrivateKeyContent() => (
      Icons.warning_amber_outlined,
      loc.scanAnythingTypePrivateKey,
    ),
  };
}

String shortenScannedValue(String value) => value.length <= 28
    ? value
    : '${value.substring(0, 12)}…${value.substring(value.length - 12)}';
