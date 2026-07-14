import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';

/// Server-authoritative permanent-name identity used by the POS UI.
///
/// [supported] is true only for the exact `permanent_names_v1` capability.
/// The optional shared [alias] is reconstructed from authenticated server
/// state and is never persisted by the POS feature.
class PosPermanentName {
  final bool supported;
  final String? nym;
  final String? alias;

  const PosPermanentName._({required this.supported, this.nym, this.alias});

  const PosPermanentName.unsupported() : this._(supported: false);

  const PosPermanentName.unclaimed() : this._(supported: true);

  const PosPermanentName.claimed({required String nym, String? alias})
    : this._(supported: true, nym: nym, alias: alias);
}

/// Reads capability before ownership so old or inconsistent servers cannot
/// expose permanent-alias or POS availability controls.
class GetPosPermanentNameUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final BullnymFacade _bullnym;
  final LightningAddressFacade _lightningAddress;

  const GetPosPermanentNameUsecase({
    required this._bullnym,
    required this._lightningAddress,
  });

  Future<PosPermanentName> execute() async {
    final version = await _bullnym.getVersion();
    switch (version) {
      case Err(:final failure):
        throw PosException.fromBullnym(failure);
      case Ok(:final value) when !value.supportsPermanentNamesV1:
        return const PosPermanentName.unsupported();
      case Ok():
        break;
    }

    final LightningAddressStatus registration;
    try {
      registration = await _lightningAddress.lookupWalletOwnedRegistration();
    } on LightningAddressException catch (error) {
      if (error.code == _nymNotFoundCode) {
        return const PosPermanentName.unclaimed();
      }
      throw posExceptionFromLightningAddress(error);
    } catch (_) {
      throw const PosException.unexpected();
    }

    final permanentName = registration.permanentNameStatus;
    if (permanentName == null || permanentName.nym != registration.nym) {
      throw const PosException.invalidServerResponse();
    }
    return PosPermanentName.claimed(
      nym: permanentName.nym,
      alias: permanentName.alias,
    );
  }
}
