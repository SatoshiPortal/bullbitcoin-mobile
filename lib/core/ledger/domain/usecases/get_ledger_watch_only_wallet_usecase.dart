import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart';

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
  }) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final derivationPath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";

    final masterFingerprint = await _repository.getMasterFingerprint(device);
    final xpub = await _repository.getXpub(
      device,
      derivationPath: derivationPath,
    );

    final descriptor = _constructDescriptor(
      masterFingerprint: masterFingerprint,
      xpub: xpub,
      derivationPath: derivationPath,
    );

    final watchOnly = await Satoshifier.parse(descriptor);

    if (watchOnly is! WatchOnlyDescriptor) {
      throw Exception(
        'Failed to parse descriptor: got ${watchOnly.runtimeType}',
      );
    }

    final watchOnlyWallet = WatchOnlyWalletEntity.descriptor(
      watchOnlyDescriptor: watchOnly,
      signer: SignerEntity.remote,
      label: label,
      signerDevice: SignerDeviceEntity.ledger,
    );

    return watchOnlyWallet;
  }

  String _constructDescriptor({
    required String masterFingerprint,
    required String xpub,
    required String derivationPath,
  }) {
    final pathParts = derivationPath.split('/');
    final convertedPath = pathParts
        .skip(1)
        .map((part) {
          if (part.endsWith("'")) {
            return '${part.substring(0, part.length - 1)}h';
          }
          return part;
        })
        .join('/');

    return 'wpkh([$masterFingerprint/$convertedPath]$xpub/0/*)';
  }
}
