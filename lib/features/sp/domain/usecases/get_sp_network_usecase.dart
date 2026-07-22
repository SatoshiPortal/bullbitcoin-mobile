import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';

/// Reads the live session's network for the send flow's wrong-network address
/// guard. Returns null when no session is established; an FFI read failure
/// throws so the caller can fail closed instead of skipping the check.
class GetSpNetworkUsecase {
  final SpAccountRepository _repository;

  GetSpNetworkUsecase({required this._repository});

  SpNetwork? execute() => _repository.network();
}
