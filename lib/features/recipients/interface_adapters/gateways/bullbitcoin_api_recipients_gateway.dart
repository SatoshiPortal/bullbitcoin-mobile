import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/cad_biller_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_model.dart';
import 'package:dio/dio.dart';

class BullbitcoinApiRecipientsGateway implements RecipientsGatewayPort {
  final Dio _authenticatedApiClient;
  final String _recipientsPath = '/ak/api-recipients';

  BullbitcoinApiRecipientsGateway({required Dio authenticatedApiClient})
    : _authenticatedApiClient = authenticatedApiClient;

  // These methods ignore `isTestnet` because this instance is bound to one environment
  // and the Dio client is already authenticated via interceptor.
  @override
  Future<Recipient> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    final detailsModel = RecipientDetailsModel.fromDomain(recipientDetails);

    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createRecipientFiat',
        'params': detailsModel.toJson(),
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to create fiat recipient');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to create fiat recipient: $error');
    }

    try {
      final result = resp.data['result']['element'] as Map<String, dynamic>;
      return RecipientModel.fromJson(result).toDomain;
    } catch (e, stackTrace) {
      log.severe(
        'Error parsing RecipientModel.fromJson: $e',
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<Recipient>> listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
  }) async {
    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': fiatOnly ? 'listRecipientsFiat' : 'listRecipients',
        'params': {
          'paginator': {'page': 1, 'pageSize': 50},
        },
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to list fiat recipients');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to list fiat recipients: $error');
    }

    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];

    try {
      return elements
          .map((e) => RecipientModel.fromJson(e as Map<String, dynamic>).toDomain)
          .toList();
    } catch (e, stackTrace) {
      log.severe(
        'Error parsing recipients list: $e',
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<String> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) async {
    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'checkSinpe',
        'params': {'phoneNumber': phoneNumber},
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to check SINPE');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to check SINPE: $error');
    }

    final result = resp.data['result'] as Map<String, dynamic>;
    final ownerName = result['ownerName'] as String;

    return ownerName;
  }

  @override
  Future<List<CadBiller>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) async {
    final params = <String, dynamic>{
      'filters': {'search': searchTerm},
    };

    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listAplBillers',
        'params': params,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to list CAD billers');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to list CAD billers: $error');
    }

    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];

    try {
      return elements
          .map((e) => CadBillerModel.fromJson(e as Map<String, dynamic>).toDomain)
          .toList();
    } catch (e, stackTrace) {
      log.severe(
        'Error parsing CAD billers list: $e',
        trace: stackTrace,
      );
      rethrow;
    }
  }
}
