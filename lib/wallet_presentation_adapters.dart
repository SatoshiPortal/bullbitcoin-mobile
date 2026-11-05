import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:flutter/widgets.dart';
import 'package:wallet/wallet.dart';

extension WalletPresentation on Wallet {
  String get addressType {
    if (isLiquid) {
      return 'Confidential Segwit';
    }

    return switch (scriptType) {
      ScriptType.bip84 => 'Native Segwit',
      ScriptType.bip49 => 'Nested Segwit',
      ScriptType.bip44 => 'Legacy',
    };
  }

  String get walletTypeString {
    String name = switch (network) {
      Network.bitcoinMainnet || Network.bitcoinTestnet => 'Bitcoin network',
      Network.liquidMainnet || Network.liquidTestnet => 'Liquid and Lightning',
    };
    if (isWatchOnly) name = 'Watch-Only';
    if (isWatchSigner) name = 'Watch-Signer';
    return name;
  }

  String get networkString {
    return switch (network) {
      Network.bitcoinMainnet => 'Bitcoin Network',
      Network.bitcoinTestnet => 'Bitcoin Testnet',
      Network.liquidMainnet => 'Liquid Network',
      Network.liquidTestnet => 'Liquid Testnet',
    };
  }

  String displayLabel(BuildContext context) {
    if (!isDefault) return label ?? origin;

    return switch (network) {
      Network.bitcoinMainnet ||
      Network.bitcoinTestnet => context.loc.globalDefaultBitcoinWalletLabel,
      Network.liquidMainnet ||
      Network.liquidTestnet => context.loc.globalDefaultLiquidWalletLabel,
    };
  }
}

extension SignerPresentation on SignerEntity {
  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}

extension SignerDevicePresentation on SignerDeviceEntity {
  String get displayName => switch (this) {
    SignerDeviceEntity.bitbox02 => 'BitBox02',
    _ => StringFormatting.camelCaseToTitleCase(name, separator: ' '),
  };
}
