import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/secure_file_upload.dart';

class GetSecureFileUploadStatusUsecase {
  final Exchange _exchange;

  const GetSecureFileUploadStatusUsecase({required this._exchange});

  /// The upload status of [session]'s account; without a session, or for a
  /// session that is no longer current, the status is unavailable.
  @useResult
  Future<Result<SecureFileUpload, ExchangeFailure>> execute(
    ExchangeSession? session,
  ) async => switch (session) {
    null => const Err(ExchangeUploadStatusUnavailableFailure()),
    final ExchangeSession session => _read(session),
  };

  Future<Result<SecureFileUpload, ExchangeFailure>> _read(
    ExchangeSession session,
  ) async => (await _exchange.getSessionUserSummary(session))
      .map(
        (summary) => SecureFileUpload(
          userId: summary.userId,
          status: summary.kycDocumentStatus?.secureFileUpload,
        ),
      )
      .mapErr((_) => const ExchangeUploadStatusUnavailableFailure());
}
