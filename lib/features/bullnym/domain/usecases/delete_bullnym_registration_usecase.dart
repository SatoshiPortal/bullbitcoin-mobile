import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:meta/meta.dart';

import 'register_bullnym_usecase.dart';

class DeleteBullnymRegistrationUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const DeleteBullnymRegistrationUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<void, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required String nym,
  }) async {
    final timestamp = _nowSecs();
    final signatureResult = await signBullpayAction(
      signer: signer,
      action: bullpayActionDelete,
      nymOrEmpty: nym,
      payloadFields: const [],
      timestampSecs: timestamp,
    );
    final String signatureHex;
    switch (signatureResult) {
      case Ok(:final value):
        signatureHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    return _client.deleteRegistration(
      BullnymDeleteRegistrationRequest(
        nym: nym,
        npubHex: signer.npubHex,
        signatureHex: signatureHex,
        timestamp: timestamp,
      ),
    );
  }
}
