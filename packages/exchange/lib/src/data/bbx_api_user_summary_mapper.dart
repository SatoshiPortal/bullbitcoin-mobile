import 'package:bbx_api/bbx_api.dart' as bbx;

import '../domain/catalog/exchange_catalog.dart';
import '../domain/entities/user_summary.dart';
import 'btc_network_wire.dart';
import 'dca_frequency_wire.dart';
import 'unknown_server_value.dart';

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
  frequency: dcaFrequencyFromWire(dca.frequency),
  // A DCA currency this build doesn't support must not fail the whole user
  // summary (balances, stats and preferences come with it).
  currency: switch (dca.currencyCode == null
      ? null
      : ExchangeCatalog.parse(dca.currencyCode!)) {
    KnownCurrency(:final currency) => currency,
    UnknownCurrency() || null => null,
  },
  amount: dca.amount,
  // An unknown rail leaves the summary's DCA network empty, as an unknown
  // currency does.
  network: switch (dca.recipientType == null
      ? null
      : BtcNetworkWire.parseRecipientType(dca.recipientType!)) {
    KnownBtcNetwork(:final network) => network,
    UnknownBtcNetwork() || null => null,
  },
  address: dca.address,
);

KycDocumentStatus _kycStatus(String status) =>
    kycDocumentStatusFromWire(status);

/// The one mapper from the server's KYC document status (API-Users
/// `KycStatusEndUser`), case-insensitive as before. An unknown value is
/// [KycDocumentStatus.unknown] (it used to read as not uploaded) and is
/// logged once.
KycDocumentStatus kycDocumentStatusFromWire(String? raw) => serverValue(
  'KYC document status',
  raw?.toUpperCase(),
  values: KycDocumentStatus.values,
  wire: (status) => status.value,
  unknown: KycDocumentStatus.unknown,
);
