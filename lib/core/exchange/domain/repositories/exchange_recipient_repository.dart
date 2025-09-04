import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';

abstract class ExchangeRecipientRepository {
  Future<List<Recipient>> listRecipients({bool fiatOnly = true});
  Future<Recipient> createFiatRecipient(NewRecipient recipient);
  Future<List<CadBiller>> listCadBillers({required String searchTerm});
}
