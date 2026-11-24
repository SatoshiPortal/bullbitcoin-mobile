import 'package:primitives/primitives.dart' show ScriptType;
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:wallet_import/src/domain/scan_mnemonic_usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

/// What the chain scan before import reports for one script type.
///
/// Its description names the outcome and the failure type only.
@freezed
sealed class ScriptTypeScan with _$ScriptTypeScan {
  const factory ScriptTypeScan.loading() = ScriptTypeScanLoading;
  const factory ScriptTypeScan.found({
    required BigInt satoshis,
    required int transactions,
  }) = ScriptTypeScanFound;
  const factory ScriptTypeScan.empty() = ScriptTypeScanEmpty;
  const factory ScriptTypeScan.failed(ImportMnemonicScanFailure failure) =
      ScriptTypeScanFailed;

  /// A wallet without any transaction is empty; one with history is found, even at zero balance.
  factory ScriptTypeScan.fromResult(MnemonicScan scan) => scan.transactions == 0
      ? const ScriptTypeScan.empty()
      : ScriptTypeScan.found(
          satoshis: scan.satoshis,
          transactions: scan.transactions,
        );
}

@freezed
sealed class ImportMnemonicState with _$ImportMnemonicState {
  const factory ImportMnemonicState({
    @Default(null) Mnemonic? mnemonic,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default(false) bool isLoading,
    @Default(false) bool imported,
    @Default(ScriptTypeScan.loading()) ScriptTypeScan bip44Scan,
    @Default(ScriptTypeScan.loading()) ScriptTypeScan bip49Scan,
    @Default(ScriptTypeScan.loading()) ScriptTypeScan bip84Scan,
    @Default(null) ImportMnemonicFailure? failure,
  }) = _ImportMnemonicState;

  const ImportMnemonicState._();

  ScriptTypeScan scanOf(ScriptType scriptType) => switch (scriptType) {
    ScriptType.bip84 => bip84Scan,
    ScriptType.bip49 => bip49Scan,
    ScriptType.bip44 => bip44Scan,
  };

  /// Says whether a mnemonic and a wallet are set, never their words, passphrase, label or descriptors.
  @override
  String toString() =>
      'ImportMnemonicState(mnemonic: ${mnemonic == null ? 'none' : 'set'}, '
      'scriptType: $scriptType, isLoading: $isLoading, '
      'wallet: ${imported ? 'set' : 'none'}, bip44Scan: $bip44Scan, '
      'bip49Scan: $bip49Scan, bip84Scan: $bip84Scan, failure: $failure)';
}
