import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';

abstract class PayjoinWatcherService {
  Stream<Payjoin> get payjoins;
}
