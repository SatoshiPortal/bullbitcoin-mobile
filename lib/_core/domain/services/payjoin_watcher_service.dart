import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinWatcherService {
  Stream<Payjoin> get payjoins;
}
