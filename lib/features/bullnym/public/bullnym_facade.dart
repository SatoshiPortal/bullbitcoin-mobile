import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

class BullnymFacade {
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;

  BullnymFacade({
    required BullnymClientPort client,
    int Function() nowSecs = currentBullpayTimestampSecs,
  }) : _register = RegisterBullnymUsecase(client, nowSecs),
       _deleteRegistration = DeleteBullnymRegistrationUsecase(client, nowSecs),
       _lookupRegistration = LookupBullnymRegistrationUsecase(client);

  Future<BullnymRegisterResult> register({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
  }) {
    return _register.execute(
      signer: signer,
      nym: nym,
      ctDescriptor: ctDescriptor,
    );
  }

  Future<void> deleteRegistration({
    required BullnymAuthSigner signer,
    required String nym,
  }) {
    return _deleteRegistration.execute(signer: signer, nym: nym);
  }

  Future<BullnymLookupResult> lookupRegistration({required String npubHex}) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }

  @override
  String toString() => 'BullnymFacade';
}
