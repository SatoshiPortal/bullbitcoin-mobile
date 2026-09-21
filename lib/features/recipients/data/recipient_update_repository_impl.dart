import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/models/recipient_update_model.dart';
import 'package:bb_mobile/features/recipients/data/recipient_update_datasource.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipient_update_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bull_logger/bull_logger.dart';

final class RecipientUpdateRepositoryImpl implements RecipientUpdateRepository {
  const RecipientUpdateRepositoryImpl(this._datasource);

  final RecipientUpdateDatasource _datasource;

  @override
  Future<Result<void, RecipientsFailure>> update(
    String recipientId,
    RecipientDetails recipientDetails, {
    required bool isTestnet,
  }) {
    final model = RecipientUpdateModel.fromDetails(
      recipientId,
      recipientDetails,
    );
    return _update(model, isTestnet: isTestnet);
  }

  @override
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails(
    InteracSecurityDetails details, {
    required bool isTestnet,
  }) {
    final model = RecipientUpdateModel.fromInteracSecurityDetails(details);
    return _update(model, isTestnet: isTestnet);
  }

  Future<Result<void, RecipientsFailure>> _update(
    RecipientUpdateModel model, {
    required bool isTestnet,
  }) async {
    try {
      final response = await _datasource.update(
        model.element,
        isTestnet: isTestnet,
      );
      final error = response['error'];
      if (error != null) {
        final fields = _validationFieldNames(error);
        if (fields.isNotEmpty) {
          return Err(
            RecipientsInvalidFieldsFailure(
              fields,
              'Recipient update validation failed',
            ),
          );
        }
        throw Exception('Failed to update recipient');
      }
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to update recipient',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(
        RecipientsUnexpectedFailure('Failed to update recipient'),
      );
    }
  }
}

Set<String> _validationFieldNames(Object? error) {
  if (error is! Map) return const {};
  final candidates = <Object?>[
    error['fields'],
    if (error['data'] case final Map data) ...[
      data['fields'],
      data['errors'],
      if (data['apiError'] case final Map apiError) apiError['fields'],
    ],
  ];
  for (final candidate in candidates) {
    final fields = _flattenValidationFieldNames(candidate);
    if (fields.isNotEmpty) return fields;
  }
  return const {};
}

Set<String> _flattenValidationFieldNames(Object? value) {
  if (value is! Map) return const {};
  if (value['element'] case final Map element) {
    return element.keys.map((key) => key.toString()).toSet();
  }
  return value.keys.map((key) => key.toString()).toSet();
}
