import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:signers/storage.dart';

import 'wallet_details.dart';
import 'wallet_details_failure.dart';

class ReadWalletDetailsUsecase {
  final SecretsInventory _inventory;
  final SignerDevices _devices;

  const ReadWalletDetailsUsecase(this._inventory, this._devices);

  @useResult
  Future<Result<WalletDetails, WalletDetailsFailure>> execute(
    String walletId,
  ) async {
    final RegisteredWallet row;
    switch (await _inventory.findWallet(walletId)) {
      case Ok(value: final found?):
        row = found;
      case Ok():
        return const Err(WalletDetailsNotFoundFailure());
      case Err(:final failure):
        return Err(WalletDetailsUnavailableFailure('${failure.runtimeType}'));
    }
    final WalletRegistration wallet;
    switch (await _inventory.readWallet(walletId)) {
      case Ok(:final value):
        wallet = value;
      case Err(failure: WalletRegistrationNotFoundFailure()):
        return const Err(WalletDetailsNotFoundFailure());
      case Err(:final failure):
        return Err(WalletDetailsUnavailableFailure('${failure.runtimeType}'));
    }
    final SignerDevice? device;
    switch (await _devices.read(walletId)) {
      case Ok(:final value):
        device = value;
      case Err(:final failure):
        return Err(WalletDetailsUnavailableFailure('${failure.runtimeType}'));
    }
    return Ok(
      WalletDetails(
        id: wallet.id,
        label: wallet.label,
        isDefault: wallet.isDefault,
        network: wallet.network,
        scriptType: wallet.scriptType,
        masterFingerprint: row.masterFingerprint,
        xpub: row.xpub,
        externalDescriptor: row.externalDescriptor,
        signer: switch (wallet.signer) {
          WalletSigner.local => SignerEntity.local,
          WalletSigner.remote => SignerEntity.remote,
          WalletSigner.none => SignerEntity.none,
        },
        signerDevice: device,
      ),
    );
  }
}
