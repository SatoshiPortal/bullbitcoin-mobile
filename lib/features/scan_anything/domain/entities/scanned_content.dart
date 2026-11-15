import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart'
    show
        SignerExportOption,
        WatchOnlyDescriptorEntity,
        WatchOnlyDescriptorEntityExtension,
        WatchOnlyWalletEntity;
import 'package:bb_mobile/features/scan_anything/domain/entities/scan_action.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

sealed class ScannedContent {
  const ScannedContent();

  String? get copyText;

  List<ScanAction> get actions => switch (this) {
    BitcoinAddressContent(:final canSwap) => [
      ScanAction.send,
      ScanAction.exploreAddress,
      if (canSwap) ScanAction.swapToAddress,
      ScanAction.buyToAddress,
      ScanAction.copy,
    ],
    LiquidAddressContent(:final canSwap) => [
      ScanAction.send,
      if (canSwap) ScanAction.swapToAddress,
      ScanAction.copy,
    ],
    Bip21Content(:final network) => [
      ScanAction.send,
      if (network.isBitcoin) ScanAction.exploreAddress,
      ScanAction.copy,
    ],
    LightningInvoiceContent(:final isExpired) => [
      if (!isExpired) ScanAction.send,
      ScanAction.copy,
    ],
    LightningAddressContent() => const [ScanAction.send, ScanAction.copy],
    DescriptorContent(:final existingWallet) => [
      if (existingWallet != null)
        ScanAction.openWallet
      else ...[
        ScanAction.importWatchOnly,
        ScanAction.importRemoteSigner,
      ],
      ScanAction.copy,
    ],
    XpubContent(:final existingWallet) => [
      if (existingWallet != null)
        ScanAction.openWallet
      else
        ScanAction.importWatchOnly,
      ScanAction.copy,
    ],
    PsbtContent() || SignedTransactionContent() => const [
      ScanAction.reviewAndBroadcast,
      ScanAction.copy,
    ],
    TransactionIdContent() => const [
      ScanAction.exploreTransaction,
      ScanAction.copy,
    ],
    SignerExportContent(:final existingWallet) => [
      if (existingWallet != null)
        ScanAction.openWallet
      else
        ScanAction.importRemoteSigner,
      ScanAction.copy,
    ],
    SilentPaymentAddressContent(:final canSend) => [
      if (canSend) ScanAction.send,
      ScanAction.copy,
    ],
    ElectrumServerContent() => const [
      ScanAction.addElectrumServer,
      ScanAction.copy,
    ],
    LabelsExportContent() => const [ScanAction.importLabels],
    RecoveryPhraseContent() => const [ScanAction.importRecoveryPhrase],
    PrivateKeyContent() => const [],
  };
}

final class BitcoinAddressContent extends ScannedContent {
  final String address;
  final Network network;

  final bool canSwap;

  const BitcoinAddressContent({
    required this.address,
    required this.network,
    this.canSwap = false,
  });

  @override
  String get copyText => address;
}

final class LiquidAddressContent extends ScannedContent {
  final String address;
  final Network network;

  final bool canSwap;

  const LiquidAddressContent({
    required this.address,
    required this.network,
    this.canSwap = false,
  });

  @override
  String get copyText => address;
}

final class Bip21Content extends ScannedContent {
  final String uri;
  final String address;
  final Network network;
  final int? amountSat;
  final String label;
  final bool hasLightning;
  final bool hasPayjoin;

  const Bip21Content({
    required this.uri,
    required this.address,
    required this.network,
    this.amountSat,
    this.label = '',
    this.hasLightning = false,
    this.hasPayjoin = false,
  });

  @override
  String get copyText => uri;
}

final class LightningInvoiceContent extends ScannedContent {
  final String invoice;
  final int amountSat;
  final String description;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool isTestnet;

  const LightningInvoiceContent({
    required this.invoice,
    required this.amountSat,
    this.description = '',
    this.expiresAt,
    this.isExpired = false,
    this.isTestnet = false,
  });

  @override
  String get copyText => invoice;
}

final class LightningAddressContent extends ScannedContent {
  final String address;

  const LightningAddressContent({required this.address});

  @override
  String get copyText => address;
}

final class DescriptorContent extends ScannedContent {
  final WatchOnlyWalletEntity wallet;
  final Wallet? existingWallet;

  const DescriptorContent(this.wallet, {this.existingWallet});

  @override
  String get copyText => switch (wallet) {
    final WatchOnlyDescriptorEntity entity => entity.descriptor.combined,
    _ => wallet.pubkey,
  };
}

final class XpubContent extends ScannedContent {
  final WatchOnlyWalletEntity wallet;
  final Wallet? existingWallet;

  const XpubContent(this.wallet, {this.existingWallet});

  @override
  String get copyText => wallet.pubkey;
}

final class PsbtContent extends ScannedContent {
  final String psbt;

  const PsbtContent({required this.psbt});

  @override
  String get copyText => psbt;
}

final class SignedTransactionContent extends ScannedContent {
  final String hex;

  const SignedTransactionContent({required this.hex});

  @override
  String get copyText => hex;
}

final class TransactionIdContent extends ScannedContent {
  final String txid;

  const TransactionIdContent({required this.txid});

  @override
  String get copyText => txid;
}

final class SignerExportContent extends ScannedContent {
  final String export;
  final List<SignerExportOption> options;
  final Wallet? existingWallet;

  SignerExportContent({
    required this.export,
    required List<SignerExportOption> options,
    this.existingWallet,
  }) : options = List.unmodifiable(options);

  @override
  String get copyText => export;
}

final class SilentPaymentAddressContent extends ScannedContent {
  final String address;
  final Network network;
  final bool canSend;

  const SilentPaymentAddressContent({
    required this.address,
    required this.network,
    required this.canSend,
  });

  @override
  String get copyText => address;
}

final class ElectrumServerContent extends ScannedContent {
  final String host;
  final int port;
  final bool useSsl;

  const ElectrumServerContent({
    required this.host,
    required this.port,
    required this.useSsl,
  });

  String get serverInput => '$host:$port:${useSsl ? 's' : 't'}';

  @override
  String get copyText => '${useSsl ? 'ssl' : 'tcp'}://$host:$port';
}

final class LabelsExportContent extends ScannedContent {
  final String jsonl;
  final int count;

  const LabelsExportContent({required this.jsonl, required this.count});

  @override
  String? get copyText => null;
}

final class RecoveryPhraseContent extends ScannedContent {
  const RecoveryPhraseContent();

  @override
  String? get copyText => null;
}

final class PrivateKeyContent extends ScannedContent {
  const PrivateKeyContent();

  @override
  String? get copyText => null;
}
