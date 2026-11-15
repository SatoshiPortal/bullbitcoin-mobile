import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scan_action.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:flutter_test/flutter_test.dart';

class FakeWallet extends Fake implements WatchOnlyWalletEntity {}

class FakeExistingWallet extends Fake implements Wallet {}

void main() {
  test('each content type offers its actions', () {
    final wallet = FakeWallet();
    final expected = <ScannedContent, List<ScanAction>>{
      const BitcoinAddressContent(
        address: 'a',
        network: Network.bitcoinMainnet,
        canSwap: true,
      ): [
        ScanAction.send,
        ScanAction.exploreAddress,
        ScanAction.swapToAddress,
        ScanAction.buyToAddress,
        ScanAction.copy,
      ],
      const BitcoinAddressContent(
        address: 'a',
        network: Network.bitcoinMainnet,
      ): [
        ScanAction.send,
        ScanAction.exploreAddress,
        ScanAction.buyToAddress,
        ScanAction.copy,
      ],
      const LiquidAddressContent(
        address: 'a',
        network: Network.liquidMainnet,
        canSwap: true,
      ): [
        ScanAction.send,
        ScanAction.swapToAddress,
        ScanAction.copy,
      ],
      const LiquidAddressContent(address: 'a', network: Network.liquidMainnet):
          [ScanAction.send, ScanAction.copy],
      SignerExportContent(
        export: '{}',
        options: const [],
        existingWallet: FakeExistingWallet(),
      ): [
        ScanAction.openWallet,
        ScanAction.copy,
      ],
      const LightningInvoiceContent(
        invoice: 'i',
        amountSat: 1,
        isExpired: true,
      ): [
        ScanAction.copy,
      ],
      DescriptorContent(wallet, existingWallet: FakeExistingWallet()): [
        ScanAction.openWallet,
        ScanAction.copy,
      ],
      XpubContent(wallet, existingWallet: FakeExistingWallet()): [
        ScanAction.openWallet,
        ScanAction.copy,
      ],
      const Bip21Content(
        uri: 'bitcoin:a',
        address: 'a',
        network: Network.bitcoinMainnet,
      ): [
        ScanAction.send,
        ScanAction.exploreAddress,
        ScanAction.copy,
      ],
      const Bip21Content(
        uri: 'liquidnetwork:a',
        address: 'a',
        network: Network.liquidMainnet,
      ): [
        ScanAction.send,
        ScanAction.copy,
      ],
      const LightningInvoiceContent(invoice: 'i', amountSat: 1): [
        ScanAction.send,
        ScanAction.copy,
      ],
      const LightningAddressContent(address: 'a'): [
        ScanAction.send,
        ScanAction.copy,
      ],
      DescriptorContent(wallet): [
        ScanAction.importWatchOnly,
        ScanAction.importRemoteSigner,
        ScanAction.copy,
      ],
      XpubContent(wallet): [ScanAction.importWatchOnly, ScanAction.copy],
      const PsbtContent(psbt: 'p'): [
        ScanAction.reviewAndBroadcast,
        ScanAction.copy,
      ],
      const SignedTransactionContent(hex: 'h'): [
        ScanAction.reviewAndBroadcast,
        ScanAction.copy,
      ],
      const TransactionIdContent(txid: 't'): [
        ScanAction.exploreTransaction,
        ScanAction.copy,
      ],
      SignerExportContent(export: '{}', options: const []): [
        ScanAction.importRemoteSigner,
        ScanAction.copy,
      ],
      const SilentPaymentAddressContent(
        address: 'sp1',
        network: Network.bitcoinMainnet,
        canSend: true,
      ): [
        ScanAction.send,
        ScanAction.copy,
      ],
      const SilentPaymentAddressContent(
        address: 'sp1',
        network: Network.bitcoinMainnet,
        canSend: false,
      ): [
        ScanAction.copy,
      ],
      const ElectrumServerContent(host: 'h', port: 1, useSsl: true): [
        ScanAction.addElectrumServer,
        ScanAction.copy,
      ],
      const LabelsExportContent(jsonl: '{}', count: 1): [
        ScanAction.importLabels,
      ],
      const RecoveryPhraseContent(): [ScanAction.importRecoveryPhrase],
      const PrivateKeyContent(): <ScanAction>[],
    };

    for (final MapEntry(key: content, value: actions) in expected.entries) {
      expect(content.actions, actions, reason: '${content.runtimeType}');
    }
  });

  test('only buying needs an exchange session', () {
    expect(
      ScanAction.values.where((action) => action.requiresExchangeSession),
      [ScanAction.buyToAddress],
    );
  });

  test('the secret types have no text to copy', () {
    expect(const RecoveryPhraseContent().copyText, isNull);
    expect(const PrivateKeyContent().copyText, isNull);
  });
}
