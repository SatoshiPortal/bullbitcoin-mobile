import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    @Default('') String label,
    required Network network,
    @Default(false) bool isDefault,
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
    required BigInt balanceSat,
    @Default([]) List<Transaction> recentTransactions,
    // We should probably store lastSwapIndex here
    // reason is that when we store wallet metadata as part of a backup, its easy to get the last index
    // otherwise we have to store all swap metadata as part of the backup as well, which is not ideal
  }) = _Wallet;
  const Wallet._();

  String getWalletTypeString() {
    String str = '';

    switch (network) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        str = 'Bitcoin network';

      case Network.liquidMainnet:
      case Network.liquidTestnet:
        str = 'Liquid and Lightning network';
    }

    return str;
  }

  String getLabel() {
    if (!isDefault) return label;

    switch (network) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        return 'Secure Bitcoin wallet';

      case Network.liquidMainnet:
      case Network.liquidTestnet:
        return 'Instant payments wallet';
    }
  }

  bool isTestnet() {
    return network == Network.bitcoinTestnet ||
        network == Network.liquidTestnet;
  }

  bool isInstant() {
    return network == Network.liquidMainnet || network == Network.liquidTestnet;
  }

  bool watchOnly() {
    switch (source) {
      case WalletSource.xpub:
      case WalletSource.coldcard:
        return true;
      default:
        return false;
    }
  }

  String getOrigin() {
    final networkPath = network == Network.bitcoinMainnet
        ? '0h'
        : network == Network.liquidMainnet
            ? '1667h'
            : '1h';

    String scriptPath = '';
    switch (scriptType) {
      case ScriptType.bip84:
        scriptPath = '84h';
      case ScriptType.bip49:
        scriptPath = '49h';
      case ScriptType.bip44:
        scriptPath = '44h';
    }

    const String accountPath = '0h';

    return '[$masterFingerprint/$scriptPath/$networkPath/$accountPath]';
  }
}
