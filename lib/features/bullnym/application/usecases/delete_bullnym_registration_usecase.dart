import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/application/application_errors.dart';
import 'package:bb_mobile/features/bullnym/application/ports/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';

import 'register_bullnym_usecase.dart';

class DeleteBullnymRegistrationUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const DeleteBullnymRegistrationUsecase({
    required this._client,
    this._nowSecs = currentBullpayTimestampSecs,
  });

  Future<void> execute({
    required NostrKeychainHandle handle,
    required String nym,
  }) {
    final timestamp = _nowSecs();
    try {
      return _client.deleteRegistration(
        BullnymDeleteRegistrationRequest(
          nym: nym,
          npubHex: handle.publicKeyHex,
          signatureHex: signBullpayAction(
            handle: handle,
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
    } catch (e) {
      throw BullnymException.signingFailed(e);
    }
  }
}
