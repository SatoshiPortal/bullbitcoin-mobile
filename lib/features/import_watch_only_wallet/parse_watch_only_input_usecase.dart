import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_input_parser.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Parses pasted/scanned text into a [WatchOnlyWalletEntity].
///
/// Extended public keys are parsed through Satoshifier and descriptors through
/// the descriptor port. Parser failures are mapped to a sanitized
/// [InvalidFormatFailure] without logging the pasted input or parser message.
class ParseWatchOnlyInputUsecase {
  final WatchOnlyInputParser _parser;
  final GetSettingsUsecase _getSettingsUsecase;
  final SeedVerificationPort _seedVerification;

  ParseWatchOnlyInputUsecase(
    this._parser,
    this._getSettingsUsecase,
    this._seedVerification,
  );

  @useResult
  Future<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>> execute(
    String input, {
    SignerDeviceEntity? signerDevice,
  }) async {
    final normalizedInput = input.trim();
    try {
      final parsedXpub = await _parser.parseXpub(
        normalizedInput,
        signerDevice: signerDevice,
      );
      if (parsedXpub != null) return Ok(parsedXpub);
    } on SignerOriginRequiredException {
      return const Err(SignerOriginRequiredFailure());
    } on Exception catch (_, st) {
      log.warning('Failed to parse watch-only input', trace: st);
      return const Err(InvalidFormatFailure());
    }

    late final Network network;
    try {
      final settings = await _getSettingsUsecase.execute();
      network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
    } on Exception catch (_, st) {
      log.warning('Failed to load settings for watch-only import', trace: st);
      return const Err(ImportFailedFailure());
    }

    late final ParsedWatchOnlyDescriptor parsedDescriptor;
    try {
      parsedDescriptor = _parser.parseDescriptor(
        normalizedInput,
        preferredNetwork: network,
      );
    } on UnsupportedFixedPublicKeyDescriptorException catch (_, st) {
      log.warning(
        'Fixed public key descriptor import is not supported',
        trace: st,
      );
      return const Err(FixedPublicKeyUnsupportedFailure());
    } on Exception catch (_, st) {
      // Parser errors may contain pasted key material. Preserve the trace but
      // never forward the raw rejection to logs or user-facing state.
      log.warning('Failed to parse watch-only input', trace: st);
      return const Err(InvalidFormatFailure());
    }

    final keyGroups = _parser.groupDescriptorKeys(
      parsedDescriptor.descriptorKeys,
    );
    final localGroups = <int>{};
    try {
      for (final (index, keys) in keyGroups.indexed) {
        if (await _isLocalSigner(keys) &&
            !_parser.requiresExplicitHardwareSigner(
              keys,
              descriptor: parsedDescriptor,
              signerDevice: signerDevice,
            )) {
          localGroups.add(index);
        }
      }
    } on Exception catch (_, st) {
      log.warning('Failed to inspect signer for watch-only import', trace: st);
      return const Err(ImportFailedFailure());
    }
    final externalSignerCount = keyGroups.length - localGroups.length;
    final signers = [
      for (final (index, keys) in keyGroups.indexed)
        WalletSigner(
          id: 'signer-$index',
          signer: localGroups.contains(index)
              ? SignerEntity.local
              : SignerEntity.remote,
          signerDevice: !localGroups.contains(index) && externalSignerCount == 1
              ? signerDevice
              : null,
          descriptorKeys: [
            for (final key in keys) key.copyWith(signerId: 'signer-$index'),
          ],
        ),
    ];
    return Ok(
      WatchOnlyWalletEntity.descriptor(
        descriptor: parsedDescriptor.descriptor,
        network: parsedDescriptor.network,
        scriptType: parsedDescriptor.scriptType,
        signers: signers,
        inferredChangePath: parsedDescriptor.inferredChangePath,
      ),
    );
  }

  Future<bool> _isLocalSigner(List<WalletDescriptorKey> keys) async {
    final fingerprints = {
      for (final key in keys)
        if (key.masterFingerprint.isNotEmpty)
          key.masterFingerprint.toLowerCase(),
    };
    if (fingerprints.length != 1) return false;

    final fingerprint = fingerprints.single;
    final verifiableKeys = [
      for (final key in keys)
        if (key.derivationPath case final derivationPath?)
          (derivationPath: derivationPath, xpub: key.xpub),
    ];
    if (keys.any(
          (key) =>
              key.derivationPath != null &&
              key.masterFingerprint.toLowerCase() != fingerprint,
        ) ||
        !await _seedVerification.matchesXpubs(
          fingerprint: fingerprint,
          keys: verifiableKeys,
        )) {
      return false;
    }
    final verifiedXpubs = verifiableKeys.map((key) => key.xpub).toSet();
    return verifiedXpubs.isNotEmpty &&
        keys.every(
          (key) =>
              key.derivationPath != null || verifiedXpubs.contains(key.xpub),
        );
  }
}
