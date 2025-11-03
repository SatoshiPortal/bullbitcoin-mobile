import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';

class DelegatingRecipientsGateway implements RecipientsGatewayPort {
  final RecipientsGatewayPort _bullbitcoinApiClient;
  final RecipientsGatewayPort _bullBitcoinTestnetApiClient;

  DelegatingRecipientsGateway({
    required RecipientsGatewayPort bullbitcoinApiClient,
    required RecipientsGatewayPort bullBitcoinTestnetApiClient,
  }) : _bullbitcoinApiClient = bullbitcoinApiClient,
       _bullBitcoinTestnetApiClient = bullBitcoinTestnetApiClient;

  @override
  Future<Recipient> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) {
    return isTestnet
        ? _bullBitcoinTestnetApiClient.saveRecipient(
          recipientDetails,
          isFiatRecipient: isFiatRecipient,
          isTestnet: isTestnet,
        )
        : _bullbitcoinApiClient.saveRecipient(
          recipientDetails,
          isFiatRecipient: isFiatRecipient,
          isTestnet: isTestnet,
        );
  }

  @override
  Future<List<Recipient>> listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
  }) {
    return isTestnet
        ? _bullBitcoinTestnetApiClient.listRecipients(
          fiatOnly: fiatOnly,
          isTestnet: isTestnet,
        )
        : _bullbitcoinApiClient.listRecipients(
          fiatOnly: fiatOnly,
          isTestnet: isTestnet,
        );
  }

  @override
  Future<String> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) {
    return isTestnet
        ? _bullBitcoinTestnetApiClient.checkSinpe(
          phoneNumber: phoneNumber,
          isTestnet: isTestnet,
        )
        : _bullbitcoinApiClient.checkSinpe(
          phoneNumber: phoneNumber,
          isTestnet: isTestnet,
        );
  }

  @override
  Future<List<CadBiller>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) {
    return isTestnet
        ? _bullBitcoinTestnetApiClient.listCadBillers(
          searchTerm: searchTerm,
          isTestnet: isTestnet,
        )
        : _bullbitcoinApiClient.listCadBillers(
          searchTerm: searchTerm,
          isTestnet: isTestnet,
        );
  }
}
