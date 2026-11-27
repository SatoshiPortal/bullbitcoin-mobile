import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:primitives/primitives.dart';

/// The journal key of the tests: a fixed raw SQLCipher key.
Future<String?> testJournalKey() async => "x'${'ab' * 32}'";

/// A session that a test can end.
final class FakeSession implements BackupSessionRef {
  @override
  final String view;

  bool current = true;

  FakeSession(this.view);

  @override
  bool get isCurrent => current;
}

/// A Secrets port with a movable session and a recorded restore.
final class FakeBackupSecrets implements BackupSecretsPort {
  FakeSession live;
  List<BackupDerivation> registry;

  /// Wallet identifiers Secrets would call not exclusive.
  Set<String> shared;
  final List<BackupContent> restored = [];
  bool failRestore = false;

  /// Runs after the restore wrote, before it returns.
  void Function()? onRestore;
  SecretsRestoreReport report = const SecretsRestoreReport(
    walletsMatched: 0,
    walletsUnmatched: 0,
    walletLabelsApplied: 0,
    walletBirthdaysApplied: 0,
    derivationsAdded: 0,
    derivationsUpdated: 0,
  );

  FakeBackupSecrets({
    String view = 'scope',
    this.registry = const [],
    this.shared = const {},
  }) : live = FakeSession(view);

  /// Ends the live session and opens another one, on [view] or the same view.
  void reopen([String? view]) {
    live.current = false;
    live = FakeSession(view ?? live.view);
  }

  /// Ends the live session for good, as a lock does.
  void lock() => live.current = false;

  @override
  Future<Result<BackupSessionRef, BackupMetadataFailure>> session() async =>
      live.current ? Ok(live) : const Err(BackupMetadataNotReadyFailure());

  /// Every wallet is exclusive but [shared] ones. The fake group's wallet is
  /// named 'wallet'.
  @override
  Future<Result<Map<String, bool>, BackupMetadataFailure>> exclusivity(
    BackupSessionRef session,
    BitcoinNetwork network,
  ) async => Ok({
    for (final id in {...walletIds, ...shared}) id: !shared.contains(id),
  });

  /// The wallets the fake names in its answer.
  Set<String> walletIds = {'wallet', 'bitcoin', 'testnet', 'liquid-only'};

  @override
  Future<Result<List<BackupDerivation>, BackupMetadataFailure>> derivations(
    BackupSessionRef session,
    BackupGroup group,
  ) async => Ok(registry);

  @override
  Future<Result<SecretsRestoreReport, BackupMetadataFailure>> restore(
    BackupSessionRef session,
    BackupGroup group,
    BackupContent content,
  ) async {
    restored.add(content);
    onRestore?.call();
    if (failRestore) return const Err(BackupMetadataUnexpectedFailure());
    return Ok(report);
  }
}
