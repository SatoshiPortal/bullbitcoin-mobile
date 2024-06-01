import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'hardware_import_state.freezed.dart';

@freezed
class HardwareImportState with _$HardwareImportState {
  const factory HardwareImportState({
    @Default('') String inputText,
    @Default(ScriptType.bip84) ScriptType selectScriptType,
    @Default('') String label,
    Wallet? tempWallet,
    List<Wallet>? walletDetails,
    ColdCard? tempColdCard,
    //
    @Default(false) bool scanningInput,
    @Default('') String errScanningInput,
    @Default(false) bool coldCardDetected,
    @Default(false) bool savingWallet,
    @Default('') String errSavingWallet,
    @Default('') String errLabel,
    @Default(false) bool savedWallet,
  }) = _HardwareImportState;
  const HardwareImportState._();

  Wallet? getSelectWalletDetails() {
    final scriptType = selectScriptType;
    final walletDetails = this.walletDetails;

    switch (scriptType) {
      case ScriptType.bip84:
        return walletDetails
            ?.firstWhere((e) => e.scriptType == ScriptType.bip84);
      case ScriptType.bip49:
        return walletDetails
            ?.firstWhere((e) => e.scriptType == ScriptType.bip49);
      case ScriptType.bip44:
        return walletDetails
            ?.firstWhere((e) => e.scriptType == ScriptType.bip44);
    }
  }

  bool inputScreen() {
    if (inputText.isNotEmpty && walletDetails != null) return true;
    return false;
  }

  List<ScriptType> getWalletScripts() =>
      walletDetails?.map((e) => e.scriptType).toList() ?? [];
}
