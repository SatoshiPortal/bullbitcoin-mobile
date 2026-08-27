import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

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
    final String derivationPath;
    try {
      final settings = await _settingsRepository.fetch();
      final network = Network.fromEnvironment(
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
      final descriptor = Descriptor.fromStrings(
        fingerprint: masterFingerprint,
        path: derivationPath,
        xpub: xpub,
      );
      final watchOnly = Satoshifier.watchOnlyDescriptor(descriptor: descriptor);

      if (watchOnly is! WatchOnlyDescriptor) {
        return const Err(LedgerUnexpectedFailure('unexpected descriptor type'));
      }

      return Ok(
        WatchOnlyWalletEntity.descriptor(
          watchOnlyDescriptor: watchOnly,
          signer: SignerEntity.remote,
          label: label,
          signerDevice: device.deviceType,
        ),
      );
    } catch (e) {
      return Err(LedgerUnexpectedFailure('failed to build descriptor: $e'));
    }
  }
}
