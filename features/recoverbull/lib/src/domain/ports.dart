import 'package:meta/meta.dart';
import 'entity/recoverbull_attempt_alert.dart';

enum RecoverBullNetwork { mainnet, testnet }

@immutable
final class RecoverBullTorSettings {
  final bool useTorProxy;
  final int torProxyPort;

  const RecoverBullTorSettings({
    required this.useTorProxy,
    required this.torProxyPort,
  });
}

abstract interface class RecoverBullSettingsPort {
  Future<RecoverBullTorSettings> fetch();
}

@immutable
final class RecoverBullWalletValue {
  final String id;
  final String masterFingerprint;
  final RecoverBullNetwork network;
  final bool isPhysicalBackupTested;
  final DateTime? latestPhysicalBackup;

  const RecoverBullWalletValue({
    required this.id,
    required this.masterFingerprint,
    required this.network,
    required this.isPhysicalBackupTested,
    this.latestPhysicalBackup,
  });
}

abstract interface class RecoverBullWalletRepositoryPort {
  Future<List<RecoverBullWalletValue>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    Object? environment,
  });
}

abstract interface class RecoverBullSeedPort {
  Future<({List<int> bytes, List<String> mnemonicWords})> getSeed(
    String masterFingerprint,
  );
}

abstract interface class RecoverBullDefaultWalletsPort {
  Future<List<RecoverBullWalletValue>> execute({
    required List<String> mnemonicWords,
  });
}

abstract interface class RecoverBullLifecyclePort {
  Future<void> markStored();
  Future<void> markVerified();
}

abstract interface class RecoverBullAttemptAlertPort {
  void publish(RecoverbullAttemptAlert alert);
}
