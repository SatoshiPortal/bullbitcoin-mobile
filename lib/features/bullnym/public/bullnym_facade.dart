import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
import 'package:bb_mobile/features/bullnym/frameworks/bullnym_http_client.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_constants.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_errors.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
export 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart'
    show
        buildBullpaySchnorrMessage,
        bullpayActionDelete,
        bullpayActionRegister,
        bullpayWireDomain;

class BullnymFacade {
  final BullnymHttpClient _client;

  BullnymFacade({BullnymHttpClient? client})
    : _client = client ?? BullnymHttpClient();

  Future<BullnymRegisterResponseDto> register({
    required NostrKeychainHandle handle,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
    int? timestampSecs,
  }) {
    return _client.register(
      handle: handle,
      nym: nym,
      ctDescriptor: ctDescriptor,
      verificationNpubHex: verificationNpubHex,
      timestampSecs: timestampSecs,
    );
  }

  Future<BullnymDeleteResponseDto> deleteRegistration({
    required NostrKeychainHandle handle,
    required String nym,
    int? timestampSecs,
  }) {
    return _client.deleteRegistration(
      handle: handle,
      nym: nym,
      timestampSecs: timestampSecs,
    );
  }

  Future<BullnymLookupResponseDto> lookupRegistration({
    required String npubHex,
  }) {
    return _client.lookupRegistration(npubHex: npubHex);
  }
}
