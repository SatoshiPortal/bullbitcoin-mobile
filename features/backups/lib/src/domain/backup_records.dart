import 'package:bull_recoverbull/storage.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

BitcoinNetwork backupNetwork(Environment environment) => switch (environment) {
  Environment.mainnet => BitcoinNetwork.mainnet,
  Environment.testnet => BitcoinNetwork.testnet,
  Environment.regtest => BitcoinNetwork.regtest,
};

typedef BackupRecords = RecoverBullWalletBackups Function(Network network);

DateTime? backupDate(int? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
