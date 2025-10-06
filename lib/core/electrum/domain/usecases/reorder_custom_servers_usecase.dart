import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ReorderCustomServersUsecase {
  final ElectrumServerRepository _repository;

  const ReorderCustomServersUsecase({
    required ElectrumServerRepository repository,
  }) : _repository = repository;

  Future<void> execute({
    required Network network,
    required int oldIndex,
    required int newIndex,
  }) async {
    await _repository.reorderCustomServers(
      network: network,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  }
}
