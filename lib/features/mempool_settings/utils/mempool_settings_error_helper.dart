import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:flutter/widgets.dart';

String getMempoolSettingsErrorMessage(
  BuildContext context,
  MempoolSettingsState state, {
  String? fallback,
}) {
  if (state.setServerError != null) {
    return switch (state.setServerError!) {
      SetCustomMempoolServerError.sameAsDefault =>
        context.loc.mempoolErrorSameAsDefault,
      SetCustomMempoolServerError.validationFailed =>
        _getValidationErrorMessage(context, state.validationErrorType),
      SetCustomMempoolServerError.saveFailed =>
        context.loc.mempoolCustomServerSaveFailed,
      SetCustomMempoolServerError.unexpected =>
        context.loc.mempoolErrorUnexpected,
    };
  }
  return state.errorMessage ?? fallback ?? '';
}

String _getValidationErrorMessage(
  BuildContext context,
  MempoolValidationErrorType? errorType,
) {
  if (errorType == null) {
    return context.loc.mempoolErrorConnectionFailed;
  }
  return switch (errorType) {
    MempoolValidationErrorType.connectionTimeout =>
      context.loc.mempoolErrorConnectionTimeout,
    MempoolValidationErrorType.hostNotFound =>
      context.loc.mempoolErrorHostNotFound,
    MempoolValidationErrorType.torNotRunning =>
      context.loc.mempoolErrorTorNotRunning,
    MempoolValidationErrorType.connectionError =>
      context.loc.mempoolErrorConnectionFailed,
    MempoolValidationErrorType.notMempoolServer =>
      context.loc.mempoolErrorNotMempoolServer,
    MempoolValidationErrorType.serverUnavailable =>
      context.loc.mempoolErrorServerUnavailable,
    MempoolValidationErrorType.serverError =>
      context.loc.mempoolErrorServerError,
    MempoolValidationErrorType.invalidResponse =>
      context.loc.mempoolErrorInvalidResponse,
    MempoolValidationErrorType.unexpected =>
      context.loc.mempoolErrorUnexpected,
  };
}
