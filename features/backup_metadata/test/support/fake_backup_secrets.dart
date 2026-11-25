import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:primitives/primitives.dart';

/// The journal key of the tests: a fixed raw SQLCipher key.
Future<String?> testJournalKey() async => "x'${'ab' * 32}'";

/// A Secrets port with a movable view and a recorded restore.
final class FakeBackupSecrets implements BackupSecretsPort {
  String scope;
  List<BackupDerivation> registry;
  final List<BackupContent> restored = [];
  SecretsRestoreReport report = const SecretsRestoreReport(
    walletsMatched: 0,
    walletsUnmatched: 0,
    walletLabelsApplied: 0,
    walletBirthdaysApplied: 0,
    derivationsAdded: 0,
    derivationsUpdated: 0,
  );

  FakeBackupSecrets({this.scope = 'scope', this.registry = const []});

  @override
  Future<Result<String, BackupMetadataFailure>> viewScope() async => Ok(scope);

  @override
  Future<Result<List<BackupDerivation>, BackupMetadataFailure>> derivations(
    BackupGroup group,
  ) async => Ok(registry);

  @override
  Future<Result<SecretsRestoreReport, BackupMetadataFailure>> restore(
    BackupGroup group,
    BackupContent content,
  ) async {
    restored.add(content);
    return Ok(report);
  }
}
