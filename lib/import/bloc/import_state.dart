import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_state.freezed.dart';

enum ImportTypes { xpub, coldcard, words, notSelected }

// enum WalletType { bech32, p2sh, p2wpkh }

enum ImportSteps {
  selectCreateType,
  selectImportType,
  importWords,
  importXpub,
  scanningNFC,
  scanningWallets,
  advancedOptions,
  // selectColdCard,
  // coldcardFile,
  // coldcardNFC,
  selectWalletType,
}

@freezed
class ImportState with _$ImportState {
  const factory ImportState({
    @Default(emptyWords) List<String> words,
    @Default('') String password,
    @Default('') String xpub,
    @Default('') String tempXpub,
    @Default('') String fingerprint,
    // @Default('') String coldCardFile,
    @Default(ImportSteps.selectCreateType) ImportSteps importStep,
    @Default(WalletType.bip84) WalletType walletType,
    @Default(ImportTypes.notSelected) ImportTypes importType,
    List<Wallet>? walletDetails,
    @Default('') String customDerivation,
    @Default(0) int accountNumber,
    String? manualDescriptor,
    String? manualChangeDescriptor,
    String? manualCombinedDescriptor,
    @Default(false) bool importing,
    @Default('') String errImporting,
    @Default(false) bool loadingFile,
    @Default('') String errLoadingFile,
    @Default(false) bool savingWallet,
    @Default('') String errSavingWallet,
    Wallet? savedWallet,
    ColdCard? coldCard,
  }) = _ImportState;
  const ImportState._();

  bool enableImportButton() {
    return xpub.isNotEmpty && !importing;
  }

  bool enableRecoverButton() {
    bool enable = true;

    for (final word in words) {
      if (word.isEmpty) enable = false;
    }

    return enable;
  }

  String stepName() {
    switch (importStep) {
      case ImportSteps.selectCreateType:
        return 'Add a new wallet';
      case ImportSteps.selectImportType:
        return 'Import a new wallet';
      case ImportSteps.importXpub:
        return 'Import XPUB';
      case ImportSteps.importWords:
        return 'Import Words';
      // case ImportSteps.selectColdCard:
      //   return 'Select Coldcard';
      // // case ImportSteps.coldcardFile:
      // //   return 'Coldcard File';
      // case ImportSteps.coldcardNFC:
      //   return 'Scanning Coldcard NFC';
      case ImportSteps.scanningNFC:
        return 'Scanning NFC';
      case ImportSteps.scanningWallets:
        return 'Scanning Wallets';
      case ImportSteps.advancedOptions:
        return 'Advanced Options';

      case ImportSteps.selectWalletType:
        return 'Select Wallet Type';
    }
  }

  String xpubStr() {
    final walletType = this.walletType;
    final walletD = walletDetails;

    switch (walletType) {
      case WalletType.bip84:
        return walletD?.where((e) => e.walletType == WalletType.bip84).first.xpub ?? '';
      case WalletType.bip49:
        return walletD?.where((e) => e.walletType == WalletType.bip49).first.xpub ?? '';
      case WalletType.bip44:
        return walletD?.where((e) => e.walletType == WalletType.bip44).first.xpub ?? '';
    }
    // switch (walletType) {
    //   case WalletType.bip84:
    //     return walletDetails?.where((e) => e.type == WalletType.bip84).first.expandedPubKey ?? '';
    //   case WalletType.bip49:
    //     return walletDetails?.where((e) => e.type == WalletType.bip49).first.expandedPubKey ?? '';
    //   case WalletType.bip44:
    //     return walletDetails?.where((e) => e.type == WalletType.bip44).first.expandedPubKey ?? '';
    // }
  }

  Wallet? getWalletDetails(WalletType type) {
    final walletDetails = this.walletDetails;

    if (!showWalletType(type)) return null;

    try {
      switch (type) {
        case WalletType.bip84:
          return walletDetails?.where((e) => e.walletType == WalletType.bip84).first;
        case WalletType.bip49:
          return walletDetails?.where((e) => e.walletType == WalletType.bip49).first;
        case WalletType.bip44:
          return walletDetails?.where((e) => e.walletType == WalletType.bip44).first;
      }
    } catch (e) {
      return null;
    }
  }

  bool showWalletType(WalletType type) {
    final pub = tempXpub;

    if (pub.startsWith('x') || pub.startsWith('t')) return true;

    if (pub.startsWith('z') && type == WalletType.bip84) return true;
    if (pub.startsWith('y') && type == WalletType.bip49) return true;

    if (pub.startsWith('u') && type == WalletType.bip84) return true;
    if (pub.startsWith('v') && type == WalletType.bip44) return true;

    return false;
  }

  Wallet? getSelectWalletDetails() {
    final walletType = this.walletType;
    final walletDetails = this.walletDetails;

    switch (walletType) {
      case WalletType.bip84:
        return walletDetails?.where((e) => e.walletType == WalletType.bip84).first;
      case WalletType.bip49:
        return walletDetails?.where((e) => e.walletType == WalletType.bip49).first;
      case WalletType.bip44:
        return walletDetails?.where((e) => e.walletType == WalletType.bip44).first;
    }
  }

  String walletName(WalletType type) => walletNameStr(type);

  bool isSelected(WalletType type) {
    final walletType = this.walletType;
    return walletType == type;
  }
}

const emptyWords = [
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '',
];
