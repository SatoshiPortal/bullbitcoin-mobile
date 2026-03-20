import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class CheckDlcConnectionUsecase {
  CheckDlcConnectionUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<DlcConnectionStatus> execute() => _dlcRepository.checkConnectionStatus();
}
