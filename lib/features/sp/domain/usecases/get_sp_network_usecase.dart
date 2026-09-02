import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';

/// Reads the live session's network for the send flow's wrong-network address
/// guard. `Ok(null)` means no session is established; an FFI read failure comes
/// back as an `Err` so the caller can fail closed instead of skipping the check.
class GetSpNetworkUsecase {
  final SpAccountRepository _repository;

  GetSpNetworkUsecase({required this._repository});

  Result<BitcoinNetwork?, SpFailure> execute() => _repository.network();
}
