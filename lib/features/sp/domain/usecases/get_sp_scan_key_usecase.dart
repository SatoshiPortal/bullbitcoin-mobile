import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The watch-only scan credential the SP account is opened from, derived by
/// the custody package from the default Bitcoin wallet of the SP network's
/// environment: mainnet SP from the mainnet default, every test chain from the
/// testnet default.
///
/// The words, the seed and the spend key stay in `package:secrets`; this only
/// ever holds the scan private key and public data. The passphrase, if any,
/// takes part in the derivation there.
class GetSpScanKeyUsecase {
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  GetSpScanKeyUsecase({
    required this._walletRepository,
    required this._secrets,
  });

  /// Failures carry fixed text plus at most a failure type name: nothing
  /// derived from the secret or its error message reaches a log.
  @useResult
  Future<Result<SilentPaymentDescriptors, SpFailure>> execute({
    required BitcoinNetwork network,
  }) async {
    final environment = network.isMainnet
        ? Environment.mainnet
        : Environment.testnet;
    final List<Wallet> wallets;
    switch (await _walletRepository.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    )) {
      case Ok(:final value):
        wallets = value;
      // A failed read is not "no default wallet": the wallet layer's reason
      // stays in its log, only its type travels.
      case Err(:final failure):
        return Err(
          SpUnexpected('default wallet lookup failed: ${failure.runtimeType}'),
        );
    }
    if (wallets.isEmpty) {
      return Err(
        SpNoDefaultWallet('no default bitcoin wallet for ${environment.name}'),
      );
    }
    final masterFingerprint = wallets.first.masterFingerprint;

    final fingerprint = Fingerprint.tryParse(masterFingerprint);
    if (fingerprint == null) {
      return const Err(SpUnexpected('default wallet fingerprint is malformed'));
    }

    final Secret secret;
    switch (await _secrets.fetch(fingerprint)) {
      case Err(:final failure):
        return Err(_toSpFailure(failure));
      case Ok(:final value):
        secret = value;
    }

    return switch (await secret.derive.descriptors.silentPayment(
      network: network,
    )) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(_toSpFailure(failure)),
    };
  }

  static SpFailure _toSpFailure(SecretFailure failure) {
    final type = failure.runtimeType.toString();
    log.warning('SP scan credential unavailable: $type');
    return switch (failure) {
      KeystoreLockedFailure() => SpKeystoreLocked(type),
      _ => SpUnexpected('scan credential unavailable: $type'),
    };
  }
}
