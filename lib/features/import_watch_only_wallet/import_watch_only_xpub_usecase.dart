import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ImportWatchOnlyXpubUsecase {
  final BitcoinDescriptorPort _descriptorPort;

  ImportWatchOnlyXpubUsecase(this._descriptorPort);

  /// Maps failures from the core descriptor boundary to the feature's
  /// sanitized [ImportWatchOnlyFailure].
  @useResult
  Future<Result<Wallet, ImportWatchOnlyFailure>> execute({
    required WatchOnlyXpubEntity watchOnlyXpub,
  }) async {
    try {
      final descriptor =
          DescriptorDerivation.derivePublicBitcoinMultipathDescriptorFromXpub(
            watchOnlyXpub.canonicalXpub,
            scriptType: watchOnlyXpub.scriptType,
            isTestnet: watchOnlyXpub.network.isTestnet,
            masterFingerprint: watchOnlyXpub.masterFingerprint,
            derivationPath: watchOnlyXpub.derivationPath,
          );
      final signers = <WalletSigner>[];
      if (watchOnlyXpub.signer != SignerEntity.none) {
        final parsed = _descriptorPort.parseBitcoinDescriptor(
          descriptor: descriptor,
          network: watchOnlyXpub.network,
        );
        signers.add(
          WalletSigner(
            id: 'signer-0',
            signer: watchOnlyXpub.signer,
            signerDevice: watchOnlyXpub.signerDevice,
            descriptorKeys: [
              for (final key in parsed.descriptorKeys)
                key.copyWith(signerId: 'signer-0'),
            ],
          ),
        );
      }
      final wallet = await _descriptorPort.importDescriptor(
        descriptor: descriptor,
        network: watchOnlyXpub.network,
        label: watchOnlyXpub.label,
        signers: signers,
      );
      return Ok(wallet);
    } on Exception catch (_, st) {
      // Parser errors may contain key material.
      log.warning('Failed to import watch-only xpub', trace: st);
      return const Err(ImportFailedFailure());
    }
  }
}
