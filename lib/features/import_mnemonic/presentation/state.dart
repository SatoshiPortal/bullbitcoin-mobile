import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

typedef Mnemonic =
    ({
      String label,
      String passphrase,
      List<String> words,
      bip39.Language language,
    });

@freezed
sealed class ImportMnemonicState with _$ImportMnemonicState {
  const factory ImportMnemonicState({
    @Default(null) Mnemonic? mnemonic,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default(false) bool isLoading,
    @Default(null) Wallet? wallet,
    @Default(null) ({BigInt satoshis, int transactions})? bip44Status,
    @Default(null) ({BigInt satoshis, int transactions})? bip49Status,
    @Default(null) ({BigInt satoshis, int transactions})? bip84Status,
    @Default(false) bool hasCheckedWallets,
    Exception? error,
  }) = _ImportMnemonicState;
}
