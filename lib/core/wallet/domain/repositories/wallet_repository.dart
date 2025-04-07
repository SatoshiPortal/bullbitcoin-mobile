import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

abstract class WalletRepository {
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
    bool isDefault,
  });
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  });
  Future<Wallet> getWallet(
    String walletId, {
    bool sync = true,
  });
  // These should also sync the wallets before returning them
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = true,
  });
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    required int amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<Utxo>? unspendable,
    List<Utxo>? selected,
    bool? replaceByFee,
  });
  Future<String> signPsbt({
    required String walletId,
    required String psbt,
  });
  // TODO: The recoverbull backup functionality should be moved to the wallet repo
  // and instead of having the updateBackupInfo and updateEncryptedBackupTime methods,
  //  doing the restore and backup create through the Wallet repository should
  //  implicitly update the backup info and encrypted backup time of the metadata.
  Future<void> updateBackupInfo({
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    required DateTime? latestEncryptedBackup,
    required DateTime? latestPhysicalBackup,
    required String walletId,
  });
  Future<void> updateEncryptedBackupTime(
    DateTime time, {
    required String walletId,
  });
  //Future<void> sync(String walletId);
  //Future<BigInt> geTotalBalanceSat(); // Get it from the Wallet entity
  /*
  // UTXO repo
  Future<List<Utxo>> getUnspentUtxos({required String walletId});
  // Address repo
  // Future<List<Address>> listAddresses();
  Future<Address> getAddressByIndex(int index, {required String walletId});
  Future<Address> getLastUnusedAddress({required String walletId});
  Future<Address>
      getNewAddress({required String walletId}); // create receive transaction param(index/lastUnused)
  Future<bool> isAddressUsed(String address, {required String walletId});
  Future<BigInt> getAddressBalanceSat(String address, {required String walletId});
  // transaction repo
  Future<List<BaseWalletTransaction>> getTransactions({required String walletId});
  // labels: label datasource + repo (import/export bip329/label lookup)
  */
}
