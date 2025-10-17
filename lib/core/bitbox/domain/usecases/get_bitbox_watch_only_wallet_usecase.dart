import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

class GetBitBoxWatchOnlyWalletUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  GetBitBoxWatchOnlyWalletUsecase({
    required BitBoxDeviceRepository repository,
    required SettingsRepository settingsRepository,
  }) : _repository = repository,
       _settingsRepository = settingsRepository;

  Future<WatchOnlyWalletEntity> execute({
    required String label,
    required BitBoxDeviceEntity device,
    SignerDeviceEntity? deviceType,
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
      isTestnet: settings.environment.isTestnet,
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
      signerDevice: deviceType
    );

    return watchOnlyWallet;
  }
}
