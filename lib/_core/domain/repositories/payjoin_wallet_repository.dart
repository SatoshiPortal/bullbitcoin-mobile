import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinWalletRepository {
  Future<Payjoin> receivePayjoin();
  Future<Payjoin> sendPayjoin();
}
