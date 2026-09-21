import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:meta/meta.dart';

class SyncUsedSigningKeyAccountsUsecase {
  final LabelsFacade _labels;
  final Bip48AccountRepository _accounts;
  final Bip48AccountUsagePort _usages;
  final GetWalletsUsecase _getWallets;

  SyncUsedSigningKeyAccountsUsecase({
    required this._labels,
    required this._accounts,
    required this._usages,
    required this._getWallets,
  });

  @useResult
  Future<Result<List<UsedSigningKeyAccount>, SettingsFailure>> execute({
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
      List<Wallet> wallets = [];
      if (usages.isNotEmpty) {
        try {
          wallets = await _getWallets.execute(
            onlyBitcoin: true,
            includeHidden: true,
          );
        } on NoWalletsFoundException {
          // A usage can outlive its wallet record.
        }
      }
      for (final usage in usages) {
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
