import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_state.freezed.dart';

enum ImportTypes { xpub, coldcard, words12, words24, notSelected }

enum ImportSteps {
  selectCreateType,
  selectImportType,
  import12Words,
  import24Words,
  importXpub,
  scanningNFC,
  scanningWallets,
  advancedOptions,
  // selectColdCard,
  // coldcardFile,
  // coldcardNFC,
  selectWalletFormat,
}

@freezed
class ImportState with _$ImportState {
  const factory ImportState({
    /**
     * 
     * SENSITIVE
     * 
     */
    @Default([]) List<({String word, bool tapped})> words12,
    @Default([]) List<({String word, bool tapped})> words24,
    @Default('') String passPhrase,
    /**
     * 
     * SENSITIVE
     * 
     */
    @Default('') String xpub,
    @Default('') String tempXpub,
    @Default('') String fingerprint,
    @Default(ImportSteps.selectCreateType) ImportSteps importStep,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default(ImportTypes.notSelected) ImportTypes importType,
    List<Wallet>? walletDetails,
    @Default('') String customDerivation,
    @Default(0) int accountNumber,
    String? walletLabel,
    String? manualPublicDescriptor,
    String? manualPublicChangeDescriptor,
    String? manualCombinedPublicDescriptor,
    @Default(false) bool importing,
    @Default('') String errImporting,
    @Default(false) bool loadingFile,
    @Default('') String errLoadingFile,
    @Default(false) bool savingWallet,
    @Default('') String errSavingWallet,
    Wallet? savedWallet,
    ColdCard? coldCard,
    @Default(false) bool mainWallet,
  }) = _ImportState;
  const ImportState._();

  bool is12() => importType == ImportTypes.words12;

  bool enableImportButton() {
    return xpub.isNotEmpty && !importing;
  }

  bool enableRecoverButton() {
    bool enable = true;

    for (final word in words12) {
      if (word.word.isEmpty) enable = false;
    }
    for (final word in words24) {
      if (word.word.isEmpty) enable = false;
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
      case ImportSteps.import12Words:
        return 'Import 12 Words';
      case ImportSteps.import24Words:
        return 'Import 24 Words';
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
      case ImportSteps.selectWalletFormat:
        return 'Select Wallet Format';
    }
  }

  Wallet? getWalletDetails(ScriptType scriptType) {
    final walletDetails = this.walletDetails;

    if (!showWalletPurpose(scriptType)) return null;

    try {
      switch (scriptType) {
        case ScriptType.bip84:
          return walletDetails?.where((e) => e.scriptType == ScriptType.bip84).first;
        case ScriptType.bip49:
          return walletDetails?.where((e) => e.scriptType == ScriptType.bip49).first;
        case ScriptType.bip44:
          return walletDetails?.where((e) => e.scriptType == ScriptType.bip44).first;
      }
    } catch (e) {
      return null;
    }
  }

  bool showWalletPurpose(ScriptType scriptType) {
    final pub = tempXpub;

    if (pub.startsWith('x') || pub.startsWith('t')) return true;
    if (pub.startsWith('z') && scriptType == ScriptType.bip84) return true;
    if (pub.startsWith('y') && scriptType == ScriptType.bip49) return true;
    if (pub.startsWith('u') && scriptType == ScriptType.bip84) return true;
    if (pub.startsWith('v') && scriptType == ScriptType.bip44) return true;

    return false;
  }

  Wallet? getSelectWalletDetails() {
    final scriptType = this.scriptType;
    final walletDetails = this.walletDetails;

    switch (scriptType) {
      case ScriptType.bip84:
        return walletDetails?.firstWhere((e) => e.scriptType == ScriptType.bip84);
      case ScriptType.bip49:
        return walletDetails?.firstWhere((e) => e.scriptType == ScriptType.bip49);
      case ScriptType.bip44:
        return walletDetails?.firstWhere((e) => e.scriptType == ScriptType.bip44);
    }
  }

  // @override
  String walletName(ScriptType scriptType) => scriptTypeString(scriptType);

  bool isSelected(ScriptType type) => type == scriptType;
}

final emptyWords12 = [
  for (int i = 0; i < 12; i++) (word: '', tapped: false),
];

final emptyWords24 = [
  for (int i = 0; i < 24; i++) (word: '', tapped: false),
];
