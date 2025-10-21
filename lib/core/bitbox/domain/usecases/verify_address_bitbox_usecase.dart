import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class VerifyAddressBitBoxUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  VerifyAddressBitBoxUsecase({
    required BitBoxDeviceRepository repository,
    required SettingsRepository settingsRepository,
  }) : _repository = repository,
       _settingsRepository = settingsRepository;

  Future<bool> execute({
    required BitBoxDeviceEntity device,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;
    
    return await _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath.replaceAll('h', "'"),
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }
}
