import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';

typedef BullnymNowSecs = int Function();

class RegisterBullnymUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const RegisterBullnymUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  Future<BullnymRegisterResult> execute({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
  }) async {
    final timestamp = _nowSecs();
    try {
      validateBullnymNpubHex(signer.npubHex);
      return _client.register(
        BullnymRegisterRequest(
          nym: nym,
          ctDescriptor: ctDescriptor,
          npubHex: signer.npubHex,
          signatureHex: await signBullpayAction(
            signer: signer,
            action: bullpayActionRegister,
            nymOrEmpty: nym,
            payloadFields: [ctDescriptor],
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
