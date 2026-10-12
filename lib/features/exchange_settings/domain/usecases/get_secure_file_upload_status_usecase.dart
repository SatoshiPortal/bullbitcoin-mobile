import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/secure_file_upload.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetSecureFileUploadStatusUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetSecureFileUploadStatusUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  @useResult
  Future<Result<SecureFileUpload, ExchangeSettingsFailure>> execute() async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      return Ok(
        SecureFileUpload(
          userId: summary.userId,
          status: summary.kycDocumentStatus?.secureFileUpload,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'getExchangeUserSummary failed', error: e, trace: st);
      return Err(
        ExchangeSettingsUploadStatusUnavailableFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
