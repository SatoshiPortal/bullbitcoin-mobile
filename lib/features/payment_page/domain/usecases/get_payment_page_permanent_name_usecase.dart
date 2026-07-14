import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';

/// Server-authoritative permanent-name identity used by the Payment Page UI.
///
/// [supported] is true only when `/version` advertises the exact
/// `permanent_names_v1` policy. A supported result may have no [nym] when this
/// wallet has not made its lifetime nym claim yet. [alias] is always read from
/// the authenticated owner lookup; it is never persisted by this feature.
class PaymentPagePermanentName {
  final bool supported;
  final String? nym;
  final String? alias;

  const PaymentPagePermanentName._({
    required this.supported,
    this.nym,
    this.alias,
  });

  const PaymentPagePermanentName.unsupported() : this._(supported: false);

  const PaymentPagePermanentName.unclaimed() : this._(supported: true);

  const PaymentPagePermanentName.claimed({required String nym, String? alias})
    : this._(supported: true, nym: nym, alias: alias);
}

/// Reads capability before ownership so an older or inconsistent server can
/// never enable permanent-alias or Payment Page availability controls.
class GetPaymentPagePermanentNameUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final BullnymFacade _bullnym;
  final LightningAddressFacade _lightningAddress;

  const GetPaymentPagePermanentNameUsecase({
    required this._bullnym,
    required this._lightningAddress,
  });

  Future<PaymentPagePermanentName> execute() async {
    final version = await _bullnym.getVersion();
    switch (version) {
      case Err(:final failure):
        throw PaymentPageException.fromBullnym(failure);
      case Ok(:final value) when !value.supportsPermanentNamesV1:
        return const PaymentPagePermanentName.unsupported();
      case Ok():
        break;
    }

    final LightningAddressStatus registration;
    try {
      registration = await _lightningAddress.lookupWalletOwnedRegistration();
    } on LightningAddressException catch (error) {
      if (error.code == _nymNotFoundCode) {
        return const PaymentPagePermanentName.unclaimed();
      }
      throw paymentPageExceptionFromLightningAddress(error);
    } catch (_) {
      throw const PaymentPageException.unexpected();
    }

    final permanentName = registration.permanentNameStatus;
    if (permanentName == null || permanentName.nym != registration.nym) {
      throw const PaymentPageException.invalidServerResponse();
    }
    return PaymentPagePermanentName.claimed(
      nym: permanentName.nym,
      alias: permanentName.alias,
    );
  }
}
