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

class UserProfile {
  final String firstName;
  final String lastName;

  const UserProfile({required this.firstName, required this.lastName});

  UserProfile copyWith({String? firstName, String? lastName}) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          firstName == other.firstName &&
          lastName == other.lastName;

  @override
  int get hashCode => firstName.hashCode ^ lastName.hashCode;
}

class UserBalance {
  final double amount;
  final String currencyCode;

  const UserBalance({required this.amount, required this.currencyCode});

  UserBalance copyWith({double? amount, String? currencyCode}) {
    return UserBalance(
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBalance &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => amount.hashCode ^ currencyCode.hashCode;
}

class UserDca {
  final bool isActive;
  final String? frequency;
  final double? amount;
  final String? address;

  const UserDca({
    required this.isActive,
    this.frequency,
    this.amount,
    this.address,
  });

  UserDca copyWith({
    bool? isActive,
    String? frequency,
    double? amount,
    String? address,
  }) {
    return UserDca(
      isActive: isActive ?? this.isActive,
      frequency: frequency ?? this.frequency,
      amount: amount ?? this.amount,
      address: address ?? this.address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDca &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          frequency == other.frequency &&
          amount == other.amount &&
          address == other.address;

  @override
  int get hashCode =>
      isActive.hashCode ^
      frequency.hashCode ^
      amount.hashCode ^
      address.hashCode;
}

class UserAutoBuyAddresses {
  final String? bitcoin;
  final String? lightning;
  final String? liquid;

  const UserAutoBuyAddresses({this.bitcoin, this.lightning, this.liquid});

  UserAutoBuyAddresses copyWith({
    String? bitcoin,
    String? lightning,
    String? liquid,
  }) {
    return UserAutoBuyAddresses(
      bitcoin: bitcoin ?? this.bitcoin,
      lightning: lightning ?? this.lightning,
      liquid: liquid ?? this.liquid,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAutoBuyAddresses &&
          runtimeType == other.runtimeType &&
          bitcoin == other.bitcoin &&
          lightning == other.lightning &&
          liquid == other.liquid;

  @override
  int get hashCode => bitcoin.hashCode ^ lightning.hashCode ^ liquid.hashCode;
}

class UserAutoBuy {
  final bool isActive;
  final UserAutoBuyAddresses addresses;

  const UserAutoBuy({required this.isActive, required this.addresses});

  UserAutoBuy copyWith({bool? isActive, UserAutoBuyAddresses? addresses}) {
    return UserAutoBuy(
      isActive: isActive ?? this.isActive,
      addresses: addresses ?? this.addresses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAutoBuy &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          addresses == other.addresses;

  @override
  int get hashCode => isActive.hashCode ^ addresses.hashCode;
}

class UserSummary {
  final int userNumber;
  final List<String> groups;
  final UserProfile profile;
  final String email;
  final List<UserBalance> balances;
  final String? language;
  final String? currency;
  final UserDca dca;
  final UserAutoBuy autoBuy;

  const UserSummary({
    required this.userNumber,
    required this.groups,
    required this.profile,
    required this.email,
    required this.balances,
    this.language,
    this.currency,
    required this.dca,
    required this.autoBuy,
  });

  UserSummary copyWith({
    int? userNumber,
    List<String>? groups,
    UserProfile? profile,
    String? email,
    List<UserBalance>? balances,
    String? language,
    String? currency,
    UserDca? dca,
    UserAutoBuy? autoBuy,
  }) {
    return UserSummary(
      userNumber: userNumber ?? this.userNumber,
      groups: groups ?? this.groups,
      profile: profile ?? this.profile,
      email: email ?? this.email,
      balances: balances ?? this.balances,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      dca: dca ?? this.dca,
      autoBuy: autoBuy ?? this.autoBuy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSummary &&
          runtimeType == other.runtimeType &&
          userNumber == other.userNumber &&
          groups == other.groups &&
          profile == other.profile &&
          email == other.email &&
          balances == other.balances &&
          language == other.language &&
          currency == other.currency &&
          dca == other.dca &&
          autoBuy == other.autoBuy;

  @override
  int get hashCode =>
      userNumber.hashCode ^
      groups.hashCode ^
      profile.hashCode ^
      email.hashCode ^
      balances.hashCode ^
      language.hashCode ^
      currency.hashCode ^
      dca.hashCode ^
      autoBuy.hashCode;

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
