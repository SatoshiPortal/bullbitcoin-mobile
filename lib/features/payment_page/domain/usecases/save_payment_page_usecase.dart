import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/prepare_payment_page_wallet_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';

/// The Donation Page save orchestrator (§3.6/§4.18).
///
/// Order: validate locally → resolve nym + signer → prepare wallet 102 (ALWAYS,
/// so the descriptor is ALWAYS sent — KR-1) → signed PUT with kind=payment_page
/// and enabled=true → best-effort backup publish when the wallet was newly
/// created (AD-3 post-commitment). Failures are wrapped as localPreparation
/// (pre-commitment, retryable, wallet rollback owned by prepare) or submission
/// (the signed PUT may have reached the server on a transport failure).
class SavePaymentPageUsecase {
  final ResolvePaymentPageIdentityUsecase _resolveIdentity;
  final PreparePaymentPageWalletUsecase _prepareWallet;
  final BullnymFacade _bullnym;
  final GetPaidSettingsFacade _getPaidSettings;

  const SavePaymentPageUsecase({
    required this._resolveIdentity,
    required this._prepareWallet,
    required this._bullnym,
    required this._getPaidSettings,
  });

  Future<PaymentPage> execute({
    required String header,
    required String description,
    required String displayCurrency,
    String website = '',
    String twitter = '',
    String instagram = '',
    bool publishBackupSnapshot = true,
  }) async {
    // Local pre-filter (UX; the server remains the authority). A validation
    // failure never touches the wire or the wallet.
    SavePaymentPageCommand(
      header: header,
      description: description,
      displayCurrency: displayCurrency,
      website: website,
      twitter: twitter,
      instagram: instagram,
    ).validate();

    var walletCreated = false;
    var walletPrepared = false;
    try {
      final ResolvedPaymentPageIdentity identity;
      final String ctDescriptor;
      try {
        identity = await _resolveIdentity.execute();
        final preparedWallet = await _prepareWallet.execute();
        // KR-1: the descriptor is ALWAYS the prepared wallet's non-empty
        // external public descriptor — never empty, never absent.
        ctDescriptor = preparedWallet.ctDescriptor;
        walletCreated = preparedWallet.created;
        walletPrepared = true;
      } on PaymentPageException catch (e) {
        throw PaymentPageSaveException.localPreparation(cause: e);
      }

      try {
        final view = await _bullnym.saveDonationPage(
          signer: identity.signer,
          nym: identity.nym,
          ctDescriptor: ctDescriptor,
          header: header,
          description: description,
          displayCurrency: displayCurrency,
          website: website,
          twitter: twitter,
          instagram: instagram,
          enabled: true,
          kind: bullnymDonationPageKindPaymentPage,
        );
        return PaymentPage.fromBullnym(view);
      } on BullnymException catch (e) {
        throw PaymentPageSaveException.submission(
          cause: PaymentPageException.fromBullnym(e),
        );
      } on PaymentPageException catch (e) {
        throw PaymentPageSaveException.submission(cause: e);
      }
    } finally {
      // Post-commitment (AD-3): the manifest record is durable once the wallet
      // was created, so the new 102 record must ride the next backup snapshot.
      // Best-effort — never changes this flow's outcome, never throws (the
      // publish facade is best-effort, but guard here too so a publish failure
      // can never mask the save's own result — §7.6).
      if (walletPrepared && walletCreated && publishBackupSnapshot) {
        try {
          await _getPaidSettings.publishBackupSnapshotIfEnabled();
        } catch (e, stack) {
          log.warning(
            'Payment Page backup snapshot publish failed',
            error: e,
            trace: stack,
          );
        }
      }
    }
  }
}
