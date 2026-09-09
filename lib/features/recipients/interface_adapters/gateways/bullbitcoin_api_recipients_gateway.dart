import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/cad_biller_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

class BullbitcoinApiRecipientsGateway implements RecipientsGatewayPort {
  final Dio _authenticatedApiClient;
  final String _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  BullbitcoinApiRecipientsGateway({required this._authenticatedApiClient});

  // These methods ignore `isTestnet` because this instance is bound to one environment
  // and the Dio client is already authenticated via interceptor.
  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    try {
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

      final rejection = _rejectionOf(resp);
      if (rejection != null) {
        _logRejection('create fiat recipient', rejection);
        return const Err(RecipientsSaveFailure());
      }

      final result = resp.data['result']['element'] as Map<String, dynamic>;
      return Ok(RecipientModel.fromJson(result).toDomain);
    } on Object catch (e, st) {
      return Err(
        _failureFrom(e, st, 'create fiat recipient', RecipientsSaveFailure.new),
      );
    }
  }

  @override
  Future<
    Result<
      ({List<Recipient> recipients, int totalRecipients}),
      RecipientsFailure
    >
  >
  listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) async {
    try {
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

      final rejection = _rejectionOf(resp);
      if (rejection != null) {
        _logRejection('list fiat recipients', rejection);
        return const Err(RecipientsLoadFailure());
      }

      final result = resp.data['result'] as Map<String, dynamic>?;
      final totalElementsRaw = result?['totalElements'];
      if (result == null || totalElementsRaw is! num) {
        log.warning(
          'Malformed listRecipients response: '
          '${result == null ? 'missing result' : 'invalid totalElements'}',
        );
        return const Err(RecipientsLoadFailure());
      }

      final totalElements = totalElementsRaw.toInt();
      final elements = result['elements'] as List<dynamic>?;
      if (elements == null) {
        return Ok((recipients: <Recipient>[], totalRecipients: totalElements));
      }

      final recipients = elements
          .map((e) {
            // A single malformed element must not fail the whole list: the
            // API can return recipient types this app build does not know
            // yet, and dropping one row is better than showing none. Nulls
            // are filtered out below.
            try {
              return RecipientModel.fromJson(
                e as Map<String, dynamic>,
              ).toDomain;
            } catch (err) {
              // warning, not severe: severe uploads the exception to the
              // crash reporter, and a parse error over a recipient payload
              // can quote the account details it choked on.
              log.warning('Skipping unparseable recipient element: $err');
              return null;
            }
          })
          .whereType<Recipient>()
          .toList();
      return Ok((recipients: recipients, totalRecipients: totalElements));
    } on Object catch (e, st) {
      return Err(
        _failureFrom(e, st, 'list fiat recipients', RecipientsLoadFailure.new),
      );
    }
  }

  @override
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) async {
    try {
      final resp = await _authenticatedApiClient.post(
        _recipientsPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'checkSinpe',
          'params': {'phoneNumber': phoneNumber},
        },
      );

      final rejection = _rejectionOf(resp);
      if (rejection != null) {
        _logRejection('check SINPE', rejection);
        return const Err(RecipientsSinpeLookupFailure());
      }

      final result = resp.data['result'] as Map<String, dynamic>;
      return Ok(result['ownerName'] as String);
    } on Object catch (e, st) {
      return Err(
        _failureFrom(e, st, 'check SINPE', RecipientsSinpeLookupFailure.new),
      );
    }
  }

  @override
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) async {
    try {
      final resp = await _authenticatedApiClient.post(
        _recipientsPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'listAplBillers',
          'params': {
            'filters': {'search': searchTerm},
          },
        },
      );

      final rejection = _rejectionOf(resp);
      if (rejection != null) {
        _logRejection('list CAD billers', rejection);
        return const Err(RecipientsCadBillerSearchFailure());
      }

      final elements = resp.data['result']['elements'] as List<dynamic>?;
      if (elements == null) return const Ok(<CadBiller>[]);

      final billers = elements
          .map((e) {
            // Same per-element tolerance as listRecipients.
            try {
              return CadBillerModel.fromJson(
                e as Map<String, dynamic>,
              ).toDomain;
            } catch (err) {
              log.warning('Skipping unparseable CAD biller element: $err');
              return null;
            }
          })
          .whereType<CadBiller>()
          .toList();
      return Ok(billers);
    } on Object catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'list CAD billers',
          RecipientsCadBillerSearchFailure.new,
        ),
      );
    }
  }

  /// Why the API refused, or null when the response is usable.
  ///
  /// Covers both refusal shapes in one place: a non-200 status, and a 200
  /// carrying a JSON-RPC `error` object. The returned string is for logs
  /// only — the `error` object holds server internals.
  String? _rejectionOf(Response<dynamic> resp) {
    if (resp.statusCode != 200) return 'HTTP ${resp.statusCode}';
    final error = resp.data is Map ? resp.data['error'] : null;
    return error == null ? null : 'JSON-RPC error: $error';
  }

  void _logRejection(String operation, String rejection) {
    // warning, not severe: the JSON-RPC error object is server-supplied and
    // can echo the recipient payload that was rejected, so it stays on-device.
    log.warning('API refused to $operation — $rejection');
  }

  /// Maps a thrown error to a typed failure, logging the raw reason here at
  /// the boundary. [onApiFailure] builds the operation-specific failure used
  /// for anything that is not a connectivity problem.
  RecipientsFailure _failureFrom(
    Object e,
    StackTrace st,
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
  ) {
    if (e is DioException) {
      final isConnectivity = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => true,
        _ => false,
      };
      if (isConnectivity) {
        log.warning('Could not reach the API to $operation: ${e.type}');
        return const RecipientsNetworkFailure();
      }
    }
    // warning, not severe: a Dio error carries the request body, and for this
    // API that body is the recipient's bank details.
    log.warning('Failed to $operation', error: e, trace: st);
    return onApiFailure();
  }
}
