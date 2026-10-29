import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

typedef MnemonicWalletPreview = ({BigInt satoshis, int transactions});

/// Electrum discovery requires an explicit source choice. Private imports never use an address-history lookup, including for script-type detection.
class DiscoverMnemonicWalletsUsecase {
  final CheckWalletStatusUsecase _check;

  DiscoverMnemonicWalletsUsecase({required this._check});

  Future<void> execute({
    required bip39.Mnemonic mnemonic,
    required BitcoinSyncSource source,
    required bool sourceConfirmed,
    required bool Function() isActive,
    required void Function(ScriptType, MnemonicWalletPreview) onDiscovered,
  }) async {
    if (!sourceConfirmed ||
        source != BitcoinSyncSource.electrum ||
        !isActive()) {
      return;
    }
    await Future.wait([
      for (final script in [
        ScriptType.bip84,
        ScriptType.bip49,
        ScriptType.bip44,
      ])
        _preview(mnemonic, script, source, isActive, onDiscovered),
    ]);
  }

  Future<void> _preview(
    bip39.Mnemonic mnemonic,
    ScriptType script,
    BitcoinSyncSource source,
    bool Function() isActive,
    void Function(ScriptType, MnemonicWalletPreview) onDiscovered,
  ) async {
    if (!isActive()) return;
    try {
      final preview = await _check(
        mnemonic: mnemonic,
        scriptType: script,
        bitcoinSyncSource: source,
      );
      if (isActive()) onDiscovered(script, preview);
    } on Exception {
      // A failed preview must not reveal private imports through a fallback or prevent another explicitly requested Electrum preview from completing.
    }
  }
}
