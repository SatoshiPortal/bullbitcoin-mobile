import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_state.freezed.dart';

@freezed
abstract class ExchangeState with _$ExchangeState {
  const factory ExchangeState({
    UserSummary? userSummary,
    ExchangeFailure? getUserSummaryFailure,
    ExchangeFailure? saveApiKeyFailure,
    ExchangeFailure? savePreferencesFailure,
    ExchangeFailure? stopDcaFailure,
    ExchangeFailure? logoutFailure,
    String? selectedLanguage,
    String? selectedCurrency,
    bool? selectedEmailNotifications,
    @Default(false) bool isSaving,
    @Default([]) List<Announcement> announcements,
    @Default(false) bool loadingAnnouncements,
  }) = _ExchangeState;

  const ExchangeState._();

  bool get isFetchingUserSummary =>
      userSummary == null && getUserSummaryFailure == null;
  bool get notLoggedIn => !hasUser;
  bool get hasUser => userSummary != null;

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel ?? false;
  bool get isLightKycLevel => userSummary?.isLightKycLevel ?? false;
  bool get isLimitedKycLevel => userSummary?.isLimitedKycLevel ?? false;

  List<UserBalance> get displayBalances {
    // Filter balances above 0
    final balancesAboveZero =
        userSummary?.balances.where((b) => b.amount > 0).toList() ?? [];

    // If no balances above 0, show the user's default currency
    if (balancesAboveZero.isEmpty) {
      // Return an empty list if currency is null, else
      if (userSummary?.currency == null) {
        return [];
      }
      return [UserBalance(amount: 0, currencyCode: userSummary!.currency!)];
    }

    return balancesAboveZero;
  }

  UserDca? get dca => userSummary?.dca;
}
