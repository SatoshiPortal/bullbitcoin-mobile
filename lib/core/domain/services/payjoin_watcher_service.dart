import 'package:bb_mobile/core/domain/entities/payjoin.dart';

abstract class PayjoinWatcherService {
  Stream<Payjoin> get payjoins;
}
