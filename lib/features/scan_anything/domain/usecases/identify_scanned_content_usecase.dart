import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart'
    show
        ParseSignerExportUsecase,
        SignerExportOption,
        ParseWatchOnlyInputUsecase,
        WatchOnlyDescriptorEntity,
        WatchOnlyWalletEntity,
        WatchOnlyXpubEntity;
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/scanned_format_detector.dart';
import 'package:bb_mobile/features/scan_anything/domain/scanned_secret_detector.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart'
    show DetectBitcoinStringUsecase;
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

typedef RawTransactionParser = Future<bool> Function(String hex);
typedef SilentPaymentSendCheck = Future<bool> Function();
typedef SwapSourceCheck = Future<bool> Function({required bool fromLiquid});
typedef ImportedWalletFinder =
    Future<Wallet?> Function(WatchOnlyWalletEntity wallet);

class IdentifyScannedContentUsecase {
  static final _txid = RegExp(r'^[0-9a-fA-F]{64}$');
  static final _hex = RegExp(r'^[0-9a-fA-F]+$');
  static final _extendedPublicKey = RegExp(
    r'[xyztuvXYZTUV]pub[1-9A-HJ-NP-Za-km-z]{20,}',
  );

  final ParseWatchOnlyInputUsecase _parseWatchOnlyInputUsecase;
  final ParseSignerExportUsecase _parseSignerExportUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final SilentPaymentSendCheck _canSendSilentPayment;
  final ImportedWalletFinder _findImportedWallet;
  final SwapSourceCheck _hasSwapSource;
  final DateTime Function() _now;
  final RawTransactionParser _isRawTransaction;

  const IdentifyScannedContentUsecase({
    required this._parseWatchOnlyInputUsecase,
    required this._parseSignerExportUsecase,
    required this._detectBitcoinStringUsecase,
    required this._canSendSilentPayment,
    required this._findImportedWallet,
    required this._hasSwapSource,
    this._now = DateTime.now,
    required this._isRawTransaction,
  });

  @useResult
  Future<Result<ScannedContent, ScanAnythingFailure>> execute(
    String input,
  ) async {
    final text = input.trim();
    if (text.isEmpty) return const Err(ScanAnythingEmptyInputFailure());

    try {
      if (ScannedSecretDetector.isRecoveryPhrase(text)) {
        return const Ok(RecoveryPhraseContent());
      }
      if (ScannedSecretDetector.isPrivateKeyMaterial(text)) {
        return const Ok(PrivateKeyContent());
      }
      if (_txid.hasMatch(text)) {
        return Ok(TransactionIdContent(txid: text.toLowerCase()));
      }
      if (text.length > 64 && text.length.isEven && _hex.hasMatch(text)) {
        if (await _isRawTransaction(text)) {
          return Ok(SignedTransactionContent(hex: text.toLowerCase()));
        }
      }
      if (ScannedFormatDetector.labelCount(text) case final count?) {
        return Ok(LabelsExportContent(jsonl: text, count: count));
      }
      if (_extendedPublicKey.hasMatch(text)) {
        final parsed = await _parseWatchOnlyInputUsecase.execute(text);
        if (parsed case Ok(value: final WatchOnlyWalletEntity wallet)) {
          return Ok(await _watchOnly(wallet));
        }
        final export = await _parseSignerExportUsecase.execute(text);
        if (export case Ok(value: final options) when options.isNotEmpty) {
          return Ok(
            options.length == 1
                ? await _watchOnly(options.first.wallet)
                : SignerExportContent(
                    export: text,
                    options: options,
                    existingWallet: await _firstImported(options),
                  ),
          );
        }
      }
      if (ScannedFormatDetector.isSilentPaymentAddress(text)) {
        return Ok(
          SilentPaymentAddressContent(
            address: text.toLowerCase(),
            network: ScannedFormatDetector.isTestnetSilentPaymentAddress(text)
                ? Network.bitcoinTestnet
                : Network.bitcoinMainnet,
            canSend: await _canSendSilentPayment(),
          ),
        );
      }
      if (ScannedFormatDetector.electrumServer(text) case final server?) {
        return Ok(server);
      }

      final PaymentRequest request;
      try {
        request = await _detectBitcoinStringUsecase.execute(data: text);
      } catch (_) {
        return const Err(ScanAnythingUnrecognizedFailure());
      }
      final content = _fromPaymentRequest(request);
      return Ok(switch (content) {
        BitcoinAddressContent(:final address, :final network) =>
          BitcoinAddressContent(
            address: address,
            network: network,
            canSwap: await _hasSwapSource(fromLiquid: true),
          ),
        LiquidAddressContent(:final address, :final network) =>
          LiquidAddressContent(
            address: address,
            network: network,
            canSwap: await _hasSwapSource(fromLiquid: false),
          ),
        _ => content,
      });
    } catch (e) {
      log.warning('Scan anything: identification failed (${e.runtimeType})');
      return Err(ScanAnythingUnexpectedFailure('${e.runtimeType}'));
    }
  }

  Future<Wallet?> _firstImported(List<SignerExportOption> options) async {
    for (final option in options) {
      final existing = await _findImportedWallet(option.wallet);
      if (existing != null) return existing;
    }
    return null;
  }

  Future<ScannedContent> _watchOnly(WatchOnlyWalletEntity wallet) async {
    final existing = await _findImportedWallet(wallet);
    return switch (wallet) {
      WatchOnlyDescriptorEntity() => DescriptorContent(
        wallet,
        existingWallet: existing,
      ),
      WatchOnlyXpubEntity() => XpubContent(wallet, existingWallet: existing),
      _ => XpubContent(wallet, existingWallet: existing),
    };
  }

  ScannedContent _fromPaymentRequest(
    PaymentRequest request,
  ) => switch (request) {
    BitcoinPaymentRequest(:final address, :final isTestnet) =>
      BitcoinAddressContent(
        address: address,
        network: isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
      ),
    LiquidPaymentRequest(:final address, :final isTestnet) =>
      LiquidAddressContent(
        address: address,
        network: isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
      ),
    LnAddressPaymentRequest(:final address) => LightningAddressContent(
      address: address,
    ),
    Bolt11PaymentRequest(
      :final invoice,
      :final amountSat,
      :final description,
      :final expiresAt,
      :final isTestnet,
    ) =>
      LightningInvoiceContent(
        invoice: invoice,
        amountSat: amountSat,
        description: description,
        expiresAt: expiresAt > 0
            ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            : null,
        isExpired:
            expiresAt > 0 && expiresAt <= _now().millisecondsSinceEpoch ~/ 1000,
        isTestnet: isTestnet,
      ),
    Bip21PaymentRequest(:final uri, :final address, :final network)
        when uri == address =>
      network.isBitcoin
          ? BitcoinAddressContent(address: address, network: network)
          : LiquidAddressContent(address: address, network: network),
    Bip21PaymentRequest(
      :final uri,
      :final address,
      :final network,
      :final amountSat,
      :final label,
      :final lightning,
      :final pj,
    ) =>
      Bip21Content(
        uri: uri,
        address: address,
        network: network,
        amountSat: amountSat,
        label: label,
        hasLightning: lightning.isNotEmpty,
        hasPayjoin: pj.isNotEmpty,
      ),
    PsbtPaymentRequest(:final psbt) => PsbtContent(psbt: psbt),
  };
}
