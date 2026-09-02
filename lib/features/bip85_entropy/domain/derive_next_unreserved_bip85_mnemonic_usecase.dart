import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class DeriveNextUnreservedBip85MnemonicUsecase {
  final DeriveNextBip85MnemonicFromDefaultWalletUsecase _deriveNext;

  const DeriveNextUnreservedBip85MnemonicUsecase(this._deriveNext);

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  execute({
    bip39.MnemonicLength length = bip39.MnemonicLength.words12,
    String? alias,
  }) => _deriveNext.execute(
    length: length,
    alias: alias,
    excludedIndices: Bip85Reservations.reservedWalletSeedIndices,
  );
}
