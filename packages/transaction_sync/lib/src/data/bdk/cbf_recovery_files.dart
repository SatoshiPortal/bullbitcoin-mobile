import 'dart:io';

import '../../domain/wallet_source_configuration.dart';

/// Public recovery index only. The source wallet remains the history authority.
String cbfRecoveryFilePath(BdkCbfConfiguration configuration) =>
    '${configuration.databaseFilePath}.cbf-${configuration.scanPolicyFingerprint}';

Future<void> deleteCbfRecoveryFiles(String databaseFilePath) async {
  final source = File(databaseFilePath);
  if (!source.parent.existsSync()) return;
  final prefix = '${source.path}.cbf-';
  await for (final file in source.parent.list()) {
    if (file is File && file.path.startsWith(prefix)) await file.delete();
  }
}
