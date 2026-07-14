import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

/// Keeps developer-created BIP39 children out of reserved product indices.
class DeriveNextUnreservedBip85MnemonicUsecase {
  final DeriveNextBip85MnemonicFromDefaultWalletUsecase _deriveNext;
  final Bip85RegistryFacade _registry;

  const DeriveNextUnreservedBip85MnemonicUsecase({
    required this._deriveNext,
    required this._registry,
  });

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  execute({
    bip39.MnemonicLength length = bip39.MnemonicLength.words12,
    String? alias,
  }) {
    return _deriveNext.execute(
      length: length,
      alias: alias,
      excludedIndices: _registry.reservedWalletSeedIndices,
    );
  }
}
