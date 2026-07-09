import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:meta/meta.dart';

class SignPsbtBitBoxUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  SignPsbtBitBoxUsecase({
    required this._repository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<String, BitBoxFailure>> execute(
    BitBoxDeviceEntity device, {
    required String? psbt,
    required String? derivationPath,
    required ScriptType scriptType,
  }) async {
    if (psbt == null || derivationPath == null) {
      return const Err(
        InvalidParametersBitBoxFailure(
          'sign requested without psbt/derivationPath',
        ),
      );
    }

    final bool isTestnet;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;
    } catch (e, st) {
      log.severe(
        message: 'BitBox sign: settings fetch failed',
        error: e,
        trace: st,
      );
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }

    return _repository.signPsbt(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    );
  }
}
