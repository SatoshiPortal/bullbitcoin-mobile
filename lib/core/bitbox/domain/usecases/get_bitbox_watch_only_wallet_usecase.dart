import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

class GetBitBoxWatchOnlyWalletUsecase {
  final BitBoxDeviceRepository _repository;
  final SettingsRepository _settingsRepository;

  GetBitBoxWatchOnlyWalletUsecase({
    required this._repository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<WatchOnlyWalletEntity, BitBoxFailure>> execute({
    required String label,
    required BitBoxDeviceEntity device,
    SignerDeviceEntity? deviceType,
    ScriptType scriptType = ScriptType.bip84,
    int account = 0,
  }) async {
    final bool isTestnet;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;
    } catch (e, st) {
      log.severe(
        message: 'BitBox import: settings fetch failed',
        error: e,
        trace: st,
      );
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }

    final network = Network.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    final derivationPath =
        "m/${scriptType.purpose}'/${network.coinType}'/$account'";

    final String masterFingerprint;
    switch (await _repository.getMasterFingerprint(device)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        masterFingerprint = value;
    }

    final String xpub;
    switch (await _repository.getXpub(
      device,
      derivationPath: derivationPath,
      scriptType: scriptType,
      isTestnet: isTestnet,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        xpub = value;
    }

    try {
      final descriptor = Descriptor.fromStrings(
        fingerprint: masterFingerprint,
        path: derivationPath,
        xpub: xpub,
      );

      final watchOnly = Satoshifier.watchOnlyDescriptor(descriptor: descriptor);
      if (watchOnly is! WatchOnlyDescriptor) {
        return Err(
          BitBoxUnexpectedFailure(
            'Failed to parse descriptor: got ${watchOnly.runtimeType}',
          ),
        );
      }

      return Ok(
        WatchOnlyWalletEntity.descriptor(
          watchOnlyDescriptor: watchOnly,
          signer: SignerEntity.remote,
          label: label,
          signerDevice: deviceType,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'BitBox import: descriptor build failed',
        error: e,
        trace: st,
      );
      return Err(BitBoxUnexpectedFailure(e.toString()));
    }
  }
}
