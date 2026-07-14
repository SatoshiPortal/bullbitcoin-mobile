import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';
import 'package:meta/meta.dart';

class SaveDonationPageUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const SaveDonationPageUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
    BullnymAliasIntent aliasIntent = const BullnymAliasIntent.preserve(),
  }) async {
    final timestamp = _nowSecs();
    // Signed order: the seven mandatory fields, ct_descriptor, kind, then an
    // alias only for the first claim. Preserve is byte-for-byte the old layout.
    final payloadFields = [
      header,
      description,
      displayCurrency,
      website,
      twitter,
      instagram,
      enabled ? '1' : '0',
      ctDescriptor,
      kind,
    ];
    switch (aliasIntent) {
      case BullnymAliasPreserve():
        break;
      case BullnymAliasClaim(:final alias):
        payloadFields.add(alias.value);
    }
    final signatureResult = await signBullpayAction(
      signer: signer,
      action: bullpayActionDonationPageSave,
      nymOrEmpty: nym,
      payloadFields: payloadFields,
      timestampSecs: timestamp,
    );
    final String signatureHex;
    switch (signatureResult) {
      case Ok(:final value):
        signatureHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    return _client.saveDonationPage(
      BullnymSaveDonationPageRequest(
        nym: nym,
        ctDescriptor: ctDescriptor,
        header: header,
        description: description,
        displayCurrency: displayCurrency,
        website: website,
        twitter: twitter,
        instagram: instagram,
        enabled: enabled,
        kind: kind,
        aliasIntent: aliasIntent,
        npubHex: signer.npubHex,
        signatureHex: signatureHex,
        timestamp: timestamp,
      ),
    );
  }
}
