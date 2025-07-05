import 'package:bb_mobile/features/template/data/template_repository.dart';

class CollectIpAddressUsecase {
  final TemplateRepository _repository;

  CollectIpAddressUsecase({required TemplateRepository repository})
    : _repository = repository;

  Future<void> call() async {
    try {
      await _repository.getIpAddressAndWriteToFile();
    } catch (e) {
      throw Exception('Template feature operation failed: $e');
    }
  }
}
