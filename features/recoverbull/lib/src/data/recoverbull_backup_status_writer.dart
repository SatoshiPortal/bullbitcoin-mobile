import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/recoverbull_network.dart';
import '../domain/recoverbull_lifecycle_port.dart';
import '../domain/repositories/recoverbull_repository.dart';

/// Advisory acknowledgements use the same repository as facade consumers.
/// A completed upload remains successful when the feature has been disposed.
final class RecoverBullBackupStatusWriter implements RecoverBullLifecyclePort {
  final RecoverBullRepository repository;
  final bool Function() isDisposed;
  final LogSink log;

  const RecoverBullBackupStatusWriter({
    required this.repository,
    required this.isDisposed,
    required this.log,
  });

  @override
  Future<void> markStored(RecoverBullNetwork network) async {
    if (isDisposed()) return;
    final result = await repository.markBackupStored(network);
    if (result case Err()) {
      log.warning('recoverbull.backup_status.stored_failed');
    }
  }

  @override
  Future<void> markVerified(RecoverBullNetwork network) async {
    if (isDisposed()) return;
    final result = await repository.markBackupVerified(network);
    if (result case Err()) {
      log.warning('recoverbull.backup_status.verified_failed');
    }
  }
}
