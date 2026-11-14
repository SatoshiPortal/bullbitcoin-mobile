import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:secrets/secrets.dart';

/// Puts a default wallet's missing seed back from the user's recovery phrase.
///
/// The wallets are still there, so nothing is created: the words are stored
/// again, and only if they are the ones a wallet was built from.
class RestoreMissingDefaultSecretUsecase {
  final Secrets _secrets;
  final WalletRepository _walletRepository;

  RestoreMissingDefaultSecretUsecase({
    required this._secrets,
    required this._walletRepository,
  });

  @useResult
  Future<Result<void, AppStartupFailure>> execute({
    required String expectedFingerprint,
    required List<String> words,
    String passphrase = '',
  }) async {
    final expected = Fingerprint.tryParse(expectedFingerprint);
    if (expected == null) {
      return const Err(AppStartupRestoreFailure('unparseable fingerprint'));
    }

    // Fingerprints are only 32 bits. Match the full public descriptors before
    // allowing any write, including when restoring another local wallet.
    final Set<Fingerprint> accepted;
    switch (await _matchingFingerprints(words, passphrase)) {
      case Ok(:final value):
        accepted = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (accepted.isEmpty) {
      return const Err(AppStartupRestoreMismatchFailure('descriptor mismatch'));
    }
    final Secret secret;
    switch (await _secrets.import(
      words: words,
      passphrase: passphrase,
      acceptOnly: accepted,
    )) {
      case Ok(:final value):
        secret = value;
      case Err(failure: SecretAlreadyExistsFailure()):
        // Already stored, so not the missing one: its fingerprint is taken.
        return const Err(AppStartupRestoreMismatchFailure('already stored'));
      case Err(failure: InvalidMnemonicFailure()):
        return const Err(AppStartupRestoreMismatchFailure('invalid words'));
      case Err(failure: FingerprintMismatchFailure()):
        return const Err(AppStartupRestoreMismatchFailure('another wallet'));
      case Err(:final failure):
        log.warning('Restore default secret: ${failure.runtimeType}');
        return Err(AppStartupRestoreFailure('${failure.runtimeType}'));
    }

    if (secret.id == expected) {
      log.info('Restore default secret: ${secret.id} is back');
      return const Ok(null);
    }
    return const Err(AppStartupRestoreMismatchFailure('another wallet'));
  }

  Future<Result<Set<Fingerprint>, AppStartupFailure>> _matchingFingerprints(
    List<String> words,
    String passphrase,
  ) async {
    final wallets = switch (await _walletRepository.getWallets()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (wallets == null) {
      return const Err(AppStartupRestoreFailure('wallet metadata unavailable'));
    }
    final accepted = <Fingerprint>{};
    final mismatched = <Fingerprint>{};
    for (final wallet in wallets.where((w) => w.signsLocally && w.isBitcoin)) {
      final fingerprint = Fingerprint.tryParse(wallet.masterFingerprint);
      if (fingerprint == null) continue;
      final type = wallet.scriptType.shared;
      final preview = await _secrets.preview.bitcoinDescriptors(
        words: words,
        passphrase: passphrase,
        network: wallet.network.bitcoin,
        scriptTypes: {type},
      );
      switch (preview) {
        case Err(failure: InvalidMnemonicFailure()):
          return const Err(AppStartupRestoreMismatchFailure('invalid words'));
        case Err():
          return const Err(
            AppStartupRestoreFailure('descriptor preview failed'),
          );
        case Ok(:final value):
          final descriptors = value[type];
          if (descriptors != null &&
              _withoutChecksum(descriptors.external) ==
                  _withoutChecksum(wallet.externalPublicDescriptor) &&
              _withoutChecksum(descriptors.internal) ==
                  _withoutChecksum(wallet.internalPublicDescriptor)) {
            accepted.add(fingerprint);
          } else {
            mismatched.add(fingerprint);
          }
      }
    }
    return Ok(accepted.difference(mismatched));
  }

  static String _withoutChecksum(String descriptor) =>
      descriptor.split('#').first;
}
