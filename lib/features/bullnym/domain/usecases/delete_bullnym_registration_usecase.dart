import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';

import 'register_bullnym_usecase.dart';

class DeleteBullnymRegistrationUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const DeleteBullnymRegistrationUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  Future<void> execute({
    required BullnymAuthSigner signer,
    required String nym,
  }) async {
    final timestamp = _nowSecs();
    try {
      validateBullnymNpubHex(signer.npubHex);
      return _client.deleteRegistration(
        BullnymDeleteRegistrationRequest(
          nym: nym,
          npubHex: signer.npubHex,
          signatureHex: await signBullpayAction(
            signer: signer,
            action: bullpayActionDelete,
            nymOrEmpty: nym,
            payloadFields: const [],
            timestampSecs: timestamp,
          ),
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
