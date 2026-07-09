import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class VerifyAddressBitBoxUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  VerifyAddressBitBoxUsecase({
    required this._repository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<bool, BitBoxFailure>> execute({
    required BitBoxDeviceEntity device,
    required String? address,
    required String? derivationPath,
    required ScriptType scriptType,
  }) async {
    if (address == null || derivationPath == null) {
      return const Err(
        InvalidParametersBitBoxFailure(
          'verify requested without address/derivationPath',
        ),
      );
    }

    final bool isTestnet;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;
    } catch (e, st) {
      log.severe(
        message: 'BitBox verify: settings fetch failed',
        error: e,
        trace: st,
      );
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }

    switch (await _repository.verifyAddress(
      device,
      address: address,
      derivationPath: derivationPath.replaceAll('h', "'"),
      scriptType: scriptType,
      isTestnet: isTestnet,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return value
            ? const Ok(true)
            : const Err(InvalidResponseBitBoxFailure());
    }
  }
}
