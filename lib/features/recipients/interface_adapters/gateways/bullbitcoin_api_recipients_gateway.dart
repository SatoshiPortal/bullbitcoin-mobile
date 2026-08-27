import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/cad_biller_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_model.dart';
import 'package:dio/dio.dart';

class BullbitcoinApiRecipientsGateway implements RecipientsGatewayPort {
  final Dio _authenticatedApiClient;
  final String _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  BullbitcoinApiRecipientsGateway({required this._authenticatedApiClient});

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
        'params': {'element': detailsModel.toJson()},
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
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
        message: 'Error parsing RecipientModel.fromJson',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<({List<Recipient> recipients, int totalRecipients})> listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) async {
    final filters = <String, dynamic>{
      if (recipientTypes != null && recipientTypes.isNotEmpty)
        'recipientTypeFiat': recipientTypes.map((t) => t.value).toList(),
      'isOwner': ?isOwner,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': fiatOnly ? 'listRecipientsFiat' : 'listRecipients',
        'params': {
          'paginator': {'page': page, 'pageSize': pageSize},
          if (filters.isNotEmpty) 'filters': filters,
        },
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to list fiat recipients');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw Exception('Failed to list fiat recipients: $error');
    }

    final result = resp.data['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw Exception('Failed to list fiat recipients: missing result');
    }

    final totalElementsRaw = result['totalElements'];
    if (totalElementsRaw is! num) {
      throw Exception('Failed to list fiat recipients: invalid totalElements');
    }
    final totalElements = totalElementsRaw.toInt();
    final elements = result['elements'] as List<dynamic>?;
    if (elements == null) {
      return (recipients: <Recipient>[], totalRecipients: totalElements);
    }

    final recipients = elements
        .map((e) {
          // Wrap each transformation in try/catch so a single malformed element
          // doesn't fail the entire list. Nulls are filtered out below.
          // This also helps when the api supports recipient types that the app
          // doesn't support yet, which without does would cause the user not
          // to see any recipients at all.
          try {
            log.info('Parsing recipient: $e');
            return RecipientModel.fromJson(e as Map<String, dynamic>).toDomain;
          } catch (err, stackTrace) {
            log.severe(
              message: 'Error parsing recipient element',
              error: err,
              trace: stackTrace,
            );
            return null;
          }
        })
        .whereType<Recipient>()
        .toList();
    return (recipients: recipients, totalRecipients: totalElements);
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

    return elements
        .map((e) {
          // Wrap each transformation in try/catch so a single malformed element
          // doesn't fail the entire list. Nulls are filtered out below.
          // This also helps when the api supports recipient types that the app
          // doesn't support yet, which without does would cause the user not
          // to see any recipients at all.
          try {
            return CadBillerModel.fromJson(e as Map<String, dynamic>).toDomain;
          } catch (err, stackTrace) {
            log.severe(
              message: 'Error parsing CAD biller element',
              error: err,
              trace: stackTrace,
            );
            return null;
          }
        })
        .whereType<CadBiller>()
        .toList();
  }
}
