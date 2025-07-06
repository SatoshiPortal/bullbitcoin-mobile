import 'package:bb_mobile/features/template/data/template_repository.dart';
import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';

class GetCachedIpUsecase {
  final TemplateRepository _repository;

  GetCachedIpUsecase({required TemplateRepository repository})
    : _repository = repository;

  Future<IpAddressEntity?> call() async {
    try {
      return await _repository.getCachedIpAddress();
    } catch (e) {
      throw '$GetCachedIpUsecase operation failed: $e';
    }
  }
}
