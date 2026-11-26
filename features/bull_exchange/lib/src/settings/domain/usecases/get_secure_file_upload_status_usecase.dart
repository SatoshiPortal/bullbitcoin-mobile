import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/secure_file_upload.dart';
import '../exchange_settings_failure.dart';

class GetSecureFileUploadStatusUsecase {
  final Exchange _exchange;

  const GetSecureFileUploadStatusUsecase({required this._exchange});

  @useResult
  Future<Result<SecureFileUpload, ExchangeSettingsFailure>> execute() async =>
      (await _exchange.getUserSummary())
          .map(
            (summary) => SecureFileUpload(
              userId: summary.userId,
              status: summary.kycDocumentStatus?.secureFileUpload,
            ),
          )
          .mapErr(
            (_) => const ExchangeSettingsUploadStatusUnavailableFailure(),
          );
}
