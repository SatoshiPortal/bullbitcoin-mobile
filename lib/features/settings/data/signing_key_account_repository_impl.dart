import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/repositories/signing_key_account_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:meta/meta.dart';

class SigningKeyAccountRepositoryImpl implements SigningKeyAccountRepository {
  final LabelsFacade _labels;
  final Bip48AccountRepository _accounts;
  final Bip48AccountUsagePort _usages;
  final WalletRepository _wallets;
  final SettingsRepository _settings;
  final SeedVerificationPort _seedVerification;

  SigningKeyAccountRepositoryImpl({
    required this._labels,
    required this._accounts,
    required this._usages,
    required this._wallets,
    required this._settings,
    required this._seedVerification,
  });

  @override
  @useResult
  Future<Result<List<UsedSigningKeyAccount>, SettingsFailure>> sync({
    required String seedFingerprint,
    required int coinType,
  }) async {
    try {
      final labels = await _labels.fetchAllOrFailure();
      if (labels is Err) return const Err(SettingsSigningKeyExportFailure());
      final reserved = await _accounts.reservedAccounts(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
      );
      if (reserved is Err) return const Err(SettingsSigningKeyExportFailure());
      final marks = (reserved as Ok).value;
      final rows = <int, UsedSigningKeyAccount>{
        for (final account in marks)
          account: UsedSigningKeyAccount(account: account),
      };
      final usages = (await _usages.getBip48AccountUsages())
          .where(
            (usage) =>
                usage.coinType == coinType &&
                (usage.localSeedFingerprint ?? usage.seedFingerprint)
                        .toLowerCase() ==
                    seedFingerprint.toLowerCase(),
          )
          .toList();
      final wallets = usages.isEmpty
          ? const <Wallet>[]
          : await _wallets.getWallets(
              environment: (await _settings.fetch()).environment,
              onlyBitcoin: true,
            );
      for (final usage in usages) {
        if (usage.localSeedFingerprint == null &&
            !await _seedVerification.matchesXpubs(
              fingerprint: usage.seedFingerprint,
              keys: [(derivationPath: usage.derivationPath, xpub: usage.xpub)],
            )) {
          continue;
        }
        final wallet = wallets
            .where(
              (wallet) =>
                  wallet.network.coinType == coinType &&
                  wallet.signers.any(
                    (signer) => signer.descriptorKeys.any(
                      (key) =>
                          key.masterFingerprint.toLowerCase() ==
                              usage.seedFingerprint.toLowerCase() &&
                          key.derivationPath == usage.derivationPath &&
                          key.xpub == usage.xpub,
                    ),
                  ),
            )
            .firstOrNull;
        rows[usage.account] = UsedSigningKeyAccount(
          account: usage.account,
          description: wallet?.label ?? wallet?.id,
          walletId: wallet?.id,
        );
      }
      for (final label in (labels as Ok).value) {
        if (label.type != LabelType.extendedPublicKey) continue;
        final account = UsedSigningKeyAccount.accountFromOrigin(
          label.origin,
          seedFingerprint: seedFingerprint,
          coinType: coinType,
        );
        if (account != null) {
          rows[account] = UsedSigningKeyAccount(
            account: account,
            description: label.label,
            walletId: rows[account]?.walletId,
          );
        }
      }
      for (final account in rows.keys) {
        if (marks.contains(account)) continue;
        final result = await _accounts.reserve(
          seedFingerprint: seedFingerprint,
          coinType: coinType,
          account: account,
        );
        if (result is Err) return const Err(SettingsSigningKeyExportFailure());
      }
      return Ok(
        rows.values.toList()..sort((a, b) => a.account.compareTo(b.account)),
      );
    } on Exception {
      return const Err(SettingsSigningKeyExportFailure());
    }
  }
}
