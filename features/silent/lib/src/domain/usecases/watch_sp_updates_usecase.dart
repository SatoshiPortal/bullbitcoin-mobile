import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/entities/sp_update.dart';

/// Exposes the repository's cross-feature update stream (balance changes,
/// setup created/revoked) through the application boundary, so the facade
/// (and thus other features) never touch the repository directly.
class WatchSpUpdatesUsecase {
  final SpAccountRepository _repository;

  WatchSpUpdatesUsecase({required this._repository});

  Stream<SilentUpdate> execute() => _repository.updates;
}
