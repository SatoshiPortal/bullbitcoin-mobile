import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_summary.freezed.dart';
part 'user_summary.g.dart';

enum ExchangeLanguage {
  en('EN'),
  fr('FR'),
  es('ES'),
  it('IT');

  const ExchangeLanguage(this._lang);
  final String _lang;

  String get code => _lang;

  String get displayName {
    switch (this) {
      case ExchangeLanguage.en:
        return 'English';
      case ExchangeLanguage.fr:
        return 'French';
      case ExchangeLanguage.es:
        return 'Spanish';
      case ExchangeLanguage.it:
        return 'Italian';
    }
  }
}

@freezed
sealed class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String firstName,
    required String lastName,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
sealed class UserBalance with _$UserBalance {
  const factory UserBalance({
    required double amount,
    required String currencyCode,
  }) = _UserBalance;

  factory UserBalance.fromJson(Map<String, dynamic> json) =>
      _$UserBalanceFromJson(json);
}

@freezed
sealed class UserDca with _$UserDca {
  const factory UserDca({
    required bool isActive,
    String? frequency,
    double? amount,
    String? address,
  }) = _UserDca;

  factory UserDca.fromJson(Map<String, dynamic> json) =>
      _$UserDcaFromJson(json);
}

@freezed
sealed class UserAutoBuyAddresses with _$UserAutoBuyAddresses {
  const factory UserAutoBuyAddresses({
    String? bitcoin,
    String? lightning,
    String? liquid,
  }) = _UserAutoBuyAddresses;

  factory UserAutoBuyAddresses.fromJson(Map<String, dynamic> json) =>
      _$UserAutoBuyAddressesFromJson(json);
}

@freezed
sealed class UserAutoBuy with _$UserAutoBuy {
  const factory UserAutoBuy({
    required bool isActive,
    required UserAutoBuyAddresses addresses,
  }) = _UserAutoBuy;

  factory UserAutoBuy.fromJson(Map<String, dynamic> json) =>
      _$UserAutoBuyFromJson(json);
}

@freezed
sealed class UserSummary with _$UserSummary {
  const factory UserSummary({
    required int userNumber,
    required List<String> groups,
    required UserProfile profile,
    required String email,
    required List<UserBalance> balances,
    String? language,
    String? currency,
    required UserDca dca,
    required UserAutoBuy autoBuy,
  }) = _UserSummary;

  factory UserSummary.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryFromJson(json);

  const UserSummary._();

  List<UserBalance> get displayBalances {
    // Filter balances above 0
    final balancesAboveZero = balances.where((b) => b.amount > 0).toList();

    // If no balances above 0, show the user's default currency
    if (balancesAboveZero.isEmpty) {
      final defaultCurrency =
          currency != null && currency!.isNotEmpty ? currency! : 'CAD';
      return [UserBalance(amount: 0, currencyCode: defaultCurrency)];
    }

    return balancesAboveZero;
  }

  bool get isFullyVerifiedKycLevel => groups.contains('KYC_IDENTITY_VERIFIED');
  bool get isLightKycLevel => groups.contains('KYC_LIGHT_VERIFICATION');
  bool get isLimitedKycLevel => groups.contains('KYC_LIMITED_VERIFICATION');
}
