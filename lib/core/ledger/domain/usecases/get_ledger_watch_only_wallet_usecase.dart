import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class GetLedgerWatchOnlyWalletUsecase {
  final LedgerDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  GetLedgerWatchOnlyWalletUsecase({
    required this._repository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<WatchOnlyWalletEntity, LedgerFailure>> execute({
    required String label,
    required LedgerDeviceEntity device,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    final Network network;
    final String derivationPath;
    try {
      final settings = await _settingsRepository.fetch();
      network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
      derivationPath =
          "m/${scriptType.purpose}'/${network.coinType}'/$account'";
    } catch (e) {
      return Err(LedgerUnexpectedFailure('failed to resolve settings: $e'));
    }

    final String masterFingerprint;
    switch (await _repository.getMasterFingerprint(device)) {
      case Ok(:final value):
        masterFingerprint = value;
      case Err(:final failure):
        return Err(failure);
    }

    final String xpub;
    switch (await _repository.getXpub(
      device,
      derivationPath: derivationPath,
      scriptType: scriptType,
    )) {
      case Ok(:final value):
        xpub = value;
      case Err(:final failure):
        return Err(failure);
    }

    try {
      final descriptor =
          DescriptorDerivation.derivePublicBitcoinMultipathDescriptorFromXpub(
            xpub,
            scriptType: scriptType,
            isTestnet: network.isTestnet,
            masterFingerprint: masterFingerprint,
            derivationPath: derivationPath,
          );

      return Ok(
        WatchOnlyWalletEntity.descriptor(
          descriptor: descriptor,
          network: network,
          scriptType: scriptType,
          signers: [
            WalletSigner(
              id: 'signer-0',
              signer: SignerEntity.remote,
              signerDevice: device.deviceType,
              descriptorKeys: [
                WalletDescriptorKey(
                  id: 'key-0',
                  signerId: 'signer-0',
                  masterFingerprint: masterFingerprint,
                  xpubFingerprint: Bip32Derivation.getBip32Xpub(
                    xpub,
                  ).fingerprintHex,
                  xpub: xpub,
                  derivationPath: derivationPath,
                ),
              ],
            ),
          ],
          label: label,
        ),
      );
    } catch (e) {
      return Err(LedgerUnexpectedFailure('failed to build descriptor: $e'));
    }
  }
}
