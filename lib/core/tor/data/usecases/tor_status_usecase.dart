import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';

class TorStatusUsecase {
  final TorRepository _torRepository;

  TorStatusUsecase(this._torRepository);

  Future<TorStatus> execute() async {
    try {
      return _torRepository.status;
    } catch (e) {
      throw Exception('$TorStatusUsecase: $e');
    }
  }
}
