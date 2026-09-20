import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_usage.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';

class ListUsedSigningKeyAccountsUsecase {
  final LabelsFacade _labels;
  final Bip48AccountRepository _accounts;
  final Bip48AccountUsagePort _usages;
  final GetWalletsUsecase _getWallets;

  ListUsedSigningKeyAccountsUsecase({
    required this._labels,
    required this._accounts,
    required this._usages,
    required this._getWallets,
  });

  Future<({List<UsedSigningKeyAccount> accounts, bool incomplete})> execute({
    required String seedFingerprint,
    required int coinType,
  }) async {
    var incomplete = false;
    Set<int> reserved = {};
    switch (await _accounts.reservedAccounts(
      seedFingerprint: seedFingerprint,
      coinType: coinType,
    )) {
      case Ok(:final value):
        reserved = value;
      case Err():
        incomplete = true;
    }
    final rows = <int, UsedSigningKeyAccount>{
      for (final account in reserved)
        account: UsedSigningKeyAccount(
          account: account,
          source: UsedSigningKeySource.legacy,
        ),
    };
    List<Bip48AccountUsage> usages = [];
    List<Wallet> wallets = [];
    try {
      usages = (await _usages.getBip48AccountUsages())
          .where(
            (usage) =>
                usage.coinType == coinType &&
                (usage.localSeedFingerprint ?? usage.seedFingerprint)
                        .toLowerCase() ==
                    seedFingerprint.toLowerCase(),
          )
          .toList();
      if (usages.isNotEmpty) {
        wallets = await _getWallets.execute(
          onlyBitcoin: true,
          includeHidden: true,
        );
      }
    } on NoWalletsFoundException {
      // A usage can outlive the corresponding visible wallet record.
    } on Exception {
      incomplete = true;
    }
    for (final usage in usages) {
      String? name;
      for (final wallet in wallets) {
        if (wallet.network.coinType == coinType &&
            wallet.signers.any(
              (signer) => signer.descriptorKeys.any(
                (key) =>
                    key.masterFingerprint.toLowerCase() ==
                        usage.seedFingerprint.toLowerCase() &&
                    key.derivationPath == usage.derivationPath &&
                    key.xpub == usage.xpub,
              ),
            )) {
          name = wallet.label;
          break;
        }
      }
      rows[usage.account] = UsedSigningKeyAccount(
        account: usage.account,
        source: UsedSigningKeySource.wallet,
        description: name,
      );
    }
    switch (await _labels.fetchAllOrFailure()) {
      case Ok(:final value):
        for (final label in value) {
          if (label.type != LabelType.extendedPublicKey) continue;
          final account = UsedSigningKeyAccount.accountFromOrigin(
            label.origin,
            seedFingerprint: seedFingerprint,
            coinType: coinType,
          );
          if (account != null) {
            rows[account] = UsedSigningKeyAccount(
              account: account,
              source: UsedSigningKeySource.memo,
              description: label.label,
            );
          }
        }
      case Err():
        incomplete = true;
    }
    for (final account in rows.keys) {
      if (reserved.contains(account)) continue;
      final reservation = await _accounts.reserve(
        seedFingerprint: seedFingerprint,
        coinType: coinType,
        account: account,
      );
      if (reservation case Err()) {
        incomplete = true;
      }
    }
    return (
      accounts: rows.values.toList()
        ..sort((a, b) => a.account.compareTo(b.account)),
      incomplete: incomplete,
    );
  }
}
