import 'package:bb_mobile/features/template/data/template_repository.dart';
import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';

class CollectAndCacheIpUsecase {
  final TemplateRepository _repository;

  CollectAndCacheIpUsecase({required TemplateRepository repository})
    : _repository = repository;

  Future<IpAddressEntity?> call() async {
    try {
      return await _repository.getIpAddressAndWriteToFile();
    } catch (e) {
      throw '$CollectAndCacheIpUsecase operation failed: $e';
    }
  }
}
