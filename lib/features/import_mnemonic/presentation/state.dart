import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

typedef Mnemonic = ({
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
    @Default(null) ImportMnemonicFailure? failure,
    // Whether the compact-block-filter choice is offered at all — the same
    // build/developer-mode gate as `WalletOptionsScreen`'s per-wallet tile
    // (see `CheckCompactBlockFiltersAvailableUsecase`). Electrum is always
    // offered and needs no such gate.
    @Default(false) bool isCbfAvailable,
    @Default(BitcoinSyncBackend.electrum) BitcoinSyncBackend syncBackend,
    // The user-picked wallet birthday, only consulted when [syncBackend] is
    // `BitcoinSyncBackend.compactBlockFilters`. `null` means "the earliest
    // possible date" (this network's genesis block) — the picker's own
    // default, and the only choice that can never fail to resolve (see
    // `ImportWalletUsecase.execute`'s `birthday` param).
    @Default(null) DateTime? birthday,
  }) = _ImportMnemonicState;
}
