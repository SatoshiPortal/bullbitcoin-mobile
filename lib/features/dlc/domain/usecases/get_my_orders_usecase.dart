import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class GetMyOrdersUsecase {
  GetMyOrdersUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<List<DlcOrder>> execute() => _dlcRepository.getMyOrders();
}
