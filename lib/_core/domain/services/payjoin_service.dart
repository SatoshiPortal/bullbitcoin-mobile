import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinService {
  Stream<Payjoin> get payjoins;
  Future<Payjoin> createPayjoinReceive();
  Future<Payjoin> createPayjoinSend();
}
