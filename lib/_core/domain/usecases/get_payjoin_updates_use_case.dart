import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';

class GetPayjoinUpdatesUseCase {
  final PayjoinService _payjoinService;

  const GetPayjoinUpdatesUseCase({required PayjoinService payjoinService})
      : _payjoinService = payjoinService;

  Stream<Payjoin> execute({List<String>? ids}) {
    try {
      return _payjoinService.payjoins.where(
        (payjoin) {
          if (ids == null) {
            return true;
          }
          return ids.contains(payjoin.id);
        },
      );
    } catch (e) {
      throw PayjoinUpdatesException(e.toString());
    }
  }
}

class PayjoinUpdatesException implements Exception {
  final String message;

  PayjoinUpdatesException(this.message);
}
