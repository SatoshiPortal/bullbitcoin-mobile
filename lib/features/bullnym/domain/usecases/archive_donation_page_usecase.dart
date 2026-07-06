import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';

class ArchiveDonationPageUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const ArchiveDonationPageUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  Future<BullnymDonationPage> execute({
    required BullnymAuthSigner signer,
    required String nym,
    required String kind,
  }) async {
    final timestamp = _nowSecs();
    try {
      validateBullnymNpubHex(signer.npubHex);
      // §3.8 archive signed order: [kind] only.
      final signatureHex = await signBullpayAction(
        signer: signer,
        action: bullpayActionDonationPageArchive,
        nymOrEmpty: nym,
        payloadFields: [kind],
        timestampSecs: timestamp,
      );
      return _client.archiveDonationPage(
        BullnymArchiveDonationPageRequest(
          nym: nym,
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
