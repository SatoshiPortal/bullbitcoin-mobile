import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';

class SaveDonationPageUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const SaveDonationPageUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  Future<BullnymDonationPage> execute({
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
  }) async {
    final timestamp = _nowSecs();
    try {
      validateBullnymNpubHex(signer.npubHex);
      // §3.8 signed order: the seven mandatory fields, then ct_descriptor, then
      // kind LAST. pos_mode is never sent, so it is never signed.
      final signatureHex = await signBullpayAction(
        signer: signer,
        action: bullpayActionDonationPageSave,
        nymOrEmpty: nym,
        payloadFields: [
          header,
          description,
          displayCurrency,
          website,
          twitter,
          instagram,
          enabled ? '1' : '0',
          ctDescriptor,
          kind,
        ],
        timestampSecs: timestamp,
      );
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
          npubHex: signer.npubHex,
          signatureHex: signatureHex,
          timestamp: timestamp,
        ),
      );
    } on BullnymException {
      rethrow;
    } catch (_) {
      throw const BullnymException.signingFailed();
    }
  }
}
