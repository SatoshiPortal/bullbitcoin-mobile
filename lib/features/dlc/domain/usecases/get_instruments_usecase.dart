import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class GetInstrumentsUsecase {
  GetInstrumentsUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<List<DlcInstrument>> execute() => _dlcRepository.getInstruments();
}
