import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';
import 'package:meta/meta.dart';

class ArchiveDonationPageUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const ArchiveDonationPageUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required String nym,
    required String kind,
  }) async {
    final timestamp = _nowSecs();
    // §3.8 archive signed order: [kind] only.
    final signatureResult = await signBullpayAction(
      signer: signer,
      action: bullpayActionDonationPageArchive,
      nymOrEmpty: nym,
      payloadFields: [kind],
      timestampSecs: timestamp,
    );
    final String signatureHex;
    switch (signatureResult) {
      case Ok(:final value):
        signatureHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    return _client.archiveDonationPage(
      BullnymArchiveDonationPageRequest(
        nym: nym,
        kind: kind,
        npubHex: signer.npubHex,
        signatureHex: signatureHex,
        timestamp: timestamp,
      ),
    );
  }
}
