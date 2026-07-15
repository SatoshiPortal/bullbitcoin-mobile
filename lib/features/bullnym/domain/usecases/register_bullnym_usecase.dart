import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:meta/meta.dart';

typedef BullnymNowSecs = int Function();

class RegisterBullnymUsecase {
  final BullnymClientPort _client;
  final BullnymNowSecs _nowSecs;

  const RegisterBullnymUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymRegisterResult, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  }) async {
    switch (validateBullnymNpubHex(verificationNpubHex)) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }
    if (verificationNpubHex == signer.npubHex) {
      return const Err(
        BullnymFailure.invalidInput(
          'Bullnym authentication and verification keys must be distinct',
        ),
      );
    }
    final timestamp = _nowSecs();
    final signatureResult = await signBullpayAction(
      signer: signer,
      action: bullpayActionRegister,
      nymOrEmpty: nym,
      payloadFields: [ctDescriptor, verificationNpubHex],
      timestampSecs: timestamp,
    );
    final String signatureHex;
    switch (signatureResult) {
      case Ok(:final value):
        signatureHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    return _client.register(
      BullnymRegisterRequest(
        nym: nym,
        ctDescriptor: ctDescriptor,
        verificationNpubHex: verificationNpubHex,
        npubHex: signer.npubHex,
        signatureHex: signatureHex,
        timestamp: timestamp,
      ),
    );
  }
}
