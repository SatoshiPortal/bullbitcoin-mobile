import 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpFacade;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Ok;

class CheckSilentPaymentSendUsecase {
  final SpFacade _spFacade;

  const CheckSilentPaymentSendUsecase({required this._spFacade});

  Future<bool> execute() async {
    try {
      if (!await _spFacade.isFeatureEnabled()) return false;
      return switch (await _spFacade.isSetUp()) {
        Ok(:final value) => value,
        _ => false,
      };
    } catch (e) {
      log.warning('Scan anything: SP gate unavailable (${e.runtimeType})');
      return false;
    }
  }
}
