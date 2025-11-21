import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';

abstract class RecipientsGatewayPort {
  Future<Recipient> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  });
  Future<({List<Recipient> recipients, int totalRecipients})> listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
  });
  Future<List<CadBiller>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  });
  Future<String> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  });
}
