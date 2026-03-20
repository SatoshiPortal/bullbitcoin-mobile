import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class GetOrderbookUsecase {
  GetOrderbookUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<List<DlcOrder>> execute({DlcOptionType? filterType}) =>
      _dlcRepository.getOrderbook(filterType: filterType);
}
