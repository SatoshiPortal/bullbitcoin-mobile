import 'package:exchange/exchange.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// Maps the `bbx_api` user summary to the app entity.
UserSummary userSummaryFromBbxApi(bbx.UserSummary s) => UserSummary(
  userNumber: s.userNumber,
  userId: s.userId,
  groups: s.groups,
  profile: UserProfile(
    firstName: s.profile.firstName,
    lastName: s.profile.lastName,
  ),
  email: s.email,
  balances: [
    for (final b in s.balances)
      UserBalance(amount: b.amount, currencyCode: b.currencyCode),
  ],
  language: s.language,
  currency: s.currency,
  dca: _dca(s.dca),
  autoBuy: UserAutoBuy(
    isActive: s.autoBuy.isActive,
    addresses: UserAutoBuyAddresses(
      bitcoin: s.autoBuy.addresses.bitcoin,
      lightning: s.autoBuy.addresses.lightning,
      liquid: s.autoBuy.addresses.liquid,
    ),
  ),
  emailNotificationsEnabled: s.emailNotificationsEnabled,
  payjoinReceiveEnabled: s.payjoinReceiveEnabled,
  kycDocumentStatus: switch (s.kycDocumentStatus) {
    final kyc? => UserKycDocumentStatus(
      secureFileUpload: _kycStatus(kyc.secureFileUpload),
      documents: UserKycDocuments(
        id: _kycStatus(kyc.documents.id),
        proofOfResidence: _kycStatus(kyc.documents.proofOfResidence),
        selfie: _kycStatus(kyc.documents.selfie),
      ),
    ),
    null => null,
  },
);

UserDca _dca(bbx.UserDca dca) => UserDca(
  isActive: dca.isActive,
  frequency: switch (dca.frequency?.toLowerCase()) {
    'hourly' => DcaBuyFrequency.hourly,
    'daily' => DcaBuyFrequency.daily,
    'weekly' => DcaBuyFrequency.weekly,
    'monthly' => DcaBuyFrequency.monthly,
    _ => null,
  },
  // A DCA currency this build doesn't support must not fail the whole user
  // summary (balances, stats and preferences come with it).
  currency: switch (dca.currencyCode) {
    final String code => FiatCurrency.tryFromCode(code),
    null => null,
  },
  amount: dca.amount,
  network: switch (dca.recipientType) {
    'OUT_BITCOIN_ADDRESS' => DcaNetwork.bitcoin,
    'OUT_LIGHTNING_ADDRESS' => DcaNetwork.lightning,
    'OUT_LIQUID_ADDRESS' => DcaNetwork.liquid,
    _ => null,
  },
  address: dca.address,
);

KycDocumentStatus _kycStatus(String status) => switch (status.toUpperCase()) {
  'ACCEPTED' => KycDocumentStatus.accepted,
  'UNDER_REVIEW' => KycDocumentStatus.underReview,
  'REJECTED' => KycDocumentStatus.rejected,
  _ => KycDocumentStatus.notUploaded,
};
