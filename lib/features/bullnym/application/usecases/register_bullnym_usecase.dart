import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/application/application_errors.dart';
import 'package:bb_mobile/features/bullnym/application/ports/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';

typedef BullnymNowSecs = int Function();

class RegisterBullnymUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const RegisterBullnymUsecase({
    required this._client,
    this._nowSecs = currentBullpayTimestampSecs,
  });

  Future<BullnymRegisterResult> execute({
    required NostrKeychainHandle handle,
    required String nym,
    required String ctDescriptor,
  }) {
    final timestamp = _nowSecs();
    try {
      return _client.register(
        BullnymRegisterRequest(
          nym: nym,
          ctDescriptor: ctDescriptor,
          npubHex: handle.publicKeyHex,
          signatureHex: signBullpayAction(
            handle: handle,
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
    } catch (e) {
      throw BullnymException.signingFailed(e);
    }
  }
}
