import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

typedef Mnemonic = ({String label, String passphrase, List<String> words});

@freezed
sealed class ImportMnemonicState with _$ImportMnemonicState {
  const factory ImportMnemonicState({
    @Default(null) Mnemonic? mnemonic,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default(false) bool isLoading,
    @Default(null) Wallet? wallet,
    Exception? error,
  }) = _ImportMnemonicState;
}
