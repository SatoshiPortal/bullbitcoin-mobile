class UserPreferencePayload {
  final String? laguage;
  final String? currencyCode;
  final String? dcaEnabled;
  final String? autoBuyEnabled;

  UserPreferencePayload({
    this.laguage,
    this.currencyCode,
    this.dcaEnabled,
    this.autoBuyEnabled,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {};

    data['LANGUAGE'] = laguage;
    data['DEFAULT_FIAT_CURRENCY_CODE'] = currencyCode;
    if (dcaEnabled != null) {
      data['DCA_ENABLED'] = dcaEnabled;
    }
    if (autoBuyEnabled != null) {
      data['AUTO_BUY_ENABLED'] = autoBuyEnabled;
    }

    data.removeWhere((key, value) => value == null);
    return data;
  }
}
