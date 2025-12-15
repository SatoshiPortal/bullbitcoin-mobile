import 'package:bb_mobile/core_deprecated/entities/signer_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

class GetLedgerWatchOnlyWalletUsecase {
  final LedgerDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  GetLedgerWatchOnlyWalletUsecase({
    required LedgerDeviceRepository repository,
    required SettingsRepository settingsRepository,
  }) : _repository = repository,
       _settingsRepository = settingsRepository;

  Future<WatchOnlyWalletEntity> execute({
    required String label,
    required LedgerDeviceEntity device,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    final settings = await _settingsRepository.fetch();
    final network = Network.fromEnvironment(
      isTestnet: settings.environment.isTestnet,
      isLiquid: false,
    );

    final derivationPath =
        "m/${scriptType.purpose}'/${network.coinType}'/$account'";

    final masterFingerprint = await _repository.getMasterFingerprint(device);
    final xpub = await _repository.getXpub(
      device,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );

    final descriptor = Descriptor.fromStrings(
      fingerprint: masterFingerprint,
      path: derivationPath,
      xpub: xpub,
    );

    final watchOnly = Satoshifier.watchOnlyDescriptor(descriptor: descriptor);

    if (watchOnly is! WatchOnlyDescriptor) {
      throw Exception(
        'Failed to parse descriptor: got ${watchOnly.runtimeType}',
      );
    }

    final watchOnlyWallet = WatchOnlyWalletEntity.descriptor(
      watchOnlyDescriptor: watchOnly,
      signer: SignerEntity.remote,
      label: label,
      signerDevice: device.deviceType,
    );

    return watchOnlyWallet;
  }
}
