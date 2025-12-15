import 'package:bb_mobile/core_deprecated/errors/exchange_errors.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_state.freezed.dart';

@freezed
abstract class ExchangeState with _$ExchangeState {
  const factory ExchangeState({
    UserSummary? userSummary,
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    SaveExchangeApiKeyException? saveApiKeyException,
    DeleteExchangeApiKeyException? deleteApiKeyException,
    String? selectedLanguage,
    String? selectedCurrency,
    @Default(false) bool isSaving,
  }) = _ExchangeState;

  const ExchangeState._();

  bool get isFetchingUserSummary =>
      userSummary == null &&
      getUserSummaryException == null &&
      apiKeyException == null;
  bool get notLoggedIn => apiKeyException != null || !hasUser;
  bool get hasUser => userSummary != null;

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel ?? false;
  bool get isLightKycLevel => userSummary?.isLightKycLevel ?? false;
  bool get isLimitedKycLevel => userSummary?.isLimitedKycLevel ?? false;

  List<UserBalance> get balances =>
      userSummary?.balances.where((b) => b.amount > 0).toList() ?? [];

  UserDca? get dca => userSummary?.dca;
}
