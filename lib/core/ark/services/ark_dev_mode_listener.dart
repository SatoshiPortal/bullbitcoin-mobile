import 'dart:async';

import 'package:bb_mobile/core/ark/usecases/revoke_ark_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ArkDevModeListener {
  final SettingsRepository _settingsRepository;
  final RevokeArkUsecase _revokeArkUsecase;
  StreamSubscription? _subscription;

  ArkDevModeListener({
    required SettingsRepository settingsRepository,
    required RevokeArkUsecase revokeArkUsecase,
  })  : _settingsRepository = settingsRepository,
        _revokeArkUsecase = revokeArkUsecase;

  void start() {
    _subscription = _settingsRepository.devModeChangeStream.listen((isEnabled) {
      if (!isEnabled) {
        _handleDevModeDisabled();
      }
    });
  }

  Future<void> _handleDevModeDisabled() async {
    try {
      await _revokeArkUsecase.execute();
      log.info('Ark successfully revoked due to dev mode being disabled');
    } catch (e) {
      log.severe('Failed to revoke Ark when dev mode was disabled: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
