class UserSummaryModel {
  final int userNumber;
  final List<String> groups;
  final UserProfileModel profile;
  final String email;
  final List<UserBalanceModel> balances;
  final String? language;
  final String? currency;
  final UserDcaModel dca;
  final UserAutoBuyModel autoBuy;

  UserSummaryModel({
    required this.userNumber,
    required this.groups,
    required this.profile,
    required this.email,
    required this.balances,
    required this.language,
    this.currency,
    required this.dca,
    required this.autoBuy,
  });

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryModel(
      userNumber: json['userNumber'] as int,
      groups: (json['groups'] as List).map((e) => e as String).toList(),
      profile: UserProfileModel.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      email: json['email'] as String,
      balances:
          (json['balances'] as List)
              .map((e) => UserBalanceModel.fromJson(e as Map<String, dynamic>))
              .toList(),
      language: json['language'] as String?,
      currency: json['currency'] as String?,
      dca: UserDcaModel.fromJson(json['dca'] as Map<String, dynamic>),
      autoBuy: UserAutoBuyModel.fromJson(
        json['autoBuy'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'userNumber': userNumber,
    'groups': groups,
    'profile': profile.toJson(),
    'email': email,
    'balances': balances.map((e) => e.toJson()).toList(),
    'language': language,
    'currency': currency,
    'dca': dca.toJson(),
    'autoBuy': autoBuy.toJson(),
  };
}

class UserProfileModel {
  final String firstName;
  final String lastName;

  UserProfileModel({required this.firstName, required this.lastName});

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
  };
}

class UserBalanceModel {
  final double amount;
  final String currencyCode;

  UserBalanceModel({required this.amount, required this.currencyCode});

  factory UserBalanceModel.fromJson(Map<String, dynamic> json) {
    return UserBalanceModel(
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currencyCode': currencyCode,
  };
}

class UserDcaModel {
  final bool isActive;
  final String? frequency;
  final double? amount;
  final String? address;

  UserDcaModel({
    required this.isActive,
    this.frequency,
    this.amount,
    this.address,
  });

  factory UserDcaModel.fromJson(Map<String, dynamic> json) {
    return UserDcaModel(
      isActive: json['isActive'] as bool,
      frequency: json['frequency'] as String?,
      amount:
          json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'frequency': frequency,
    'amount': amount,
    'address': address,
  };
}

class UserAutoBuyAddressesModel {
  final String? bitcoin;
  final String? lightning;
  final String? liquid;

  UserAutoBuyAddressesModel({this.bitcoin, this.lightning, this.liquid});

  factory UserAutoBuyAddressesModel.fromJson(Map<String, dynamic> json) {
    return UserAutoBuyAddressesModel(
      bitcoin: json['bitcoin'] as String?,
      lightning: json['lightning'] as String?,
      liquid: json['liquid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'bitcoin': bitcoin,
    'lightning': lightning,
    'liquid': liquid,
  };
}

class UserAutoBuyModel {
  final bool isActive;
  final UserAutoBuyAddressesModel addresses;

  UserAutoBuyModel({required this.isActive, required this.addresses});

  factory UserAutoBuyModel.fromJson(Map<String, dynamic> json) {
    return UserAutoBuyModel(
      isActive: json['isActive'] as bool,
      addresses: UserAutoBuyAddressesModel.fromJson(
        json['addresses'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'addresses': addresses.toJson(),
  };
}
