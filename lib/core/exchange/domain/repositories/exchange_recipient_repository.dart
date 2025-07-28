import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';

abstract class ExchangeRecipientRepository {
  Future<List<Recipient>> listRecipients({bool fiatOnly = true});
}
