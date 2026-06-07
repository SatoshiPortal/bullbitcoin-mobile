import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/register_bullnym_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';

export 'package:bb_mobile/features/bullnym/application/application_errors.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';

class BullnymFacade {
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;

  const BullnymFacade({
    required this._register,
    required this._deleteRegistration,
    required this._lookupRegistration,
  });

  Future<BullnymRegisterResult> register({
    required NostrKeychainHandle handle,
    required String nym,
    required String ctDescriptor,
  }) {
    return _register.execute(
      handle: handle,
      nym: nym,
      ctDescriptor: ctDescriptor,
    );
  }

  Future<BullnymDeleteResult> deleteRegistration({
    required NostrKeychainHandle handle,
    required String nym,
  }) {
    return _deleteRegistration.execute(handle: handle, nym: nym);
  }

  Future<BullnymLookupResult> lookupRegistration({required String npubHex}) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }

  @override
  String toString() => 'BullnymFacade';
}
