import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// The tip the scan can reach, as indexed by the session's Blindbit server.
///
/// Separate from the wallet snapshot and from `LoadSpWalletDataUsecase`: it is
/// one HTTP read with a bounded wait, so a dead server reports
/// [SilentBackendUnreachable] instead of hanging the caller. Kept out of the
/// data load so the wallet screen never waits on a second round trip.
class GetSpScanServerTipUsecase {
  /// A Blindbit server that does not answer within this window is treated as
  /// unreachable: the scan cannot make progress past it anyway.
  static const Duration timeout = Duration(seconds: 10);

  final SpAccountRepository _repository;

  GetSpScanServerTipUsecase({required this._repository});

  @useResult
  Future<Result<int, SilentFailure>> execute() =>
      _repository.currentBlockHeight().timeout(
        timeout,
        onTimeout: () => const Err(
          SilentBackendUnreachable('SP scan server tip read timed out'),
        ),
      );
}
