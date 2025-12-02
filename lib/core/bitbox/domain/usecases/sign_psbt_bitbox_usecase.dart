import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class SignPsbtBitBoxUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  SignPsbtBitBoxUsecase({
    required BitBoxDeviceRepository repository,
    required SettingsRepository settingsRepository,
  })  : _repository = repository,
        _settingsRepository = settingsRepository;

  Future<String> execute(
    BitBoxDeviceEntity device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    return await _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }
}
