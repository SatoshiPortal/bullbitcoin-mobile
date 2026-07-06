import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';
import 'package:bb_mobile/features/pos/domain/pos_validation.dart';
import 'package:bb_mobile/features/pos/domain/usecases/prepare_pos_wallet_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';

/// The Point of Sale provision/edit orchestrator (§3.6/§4.20).
///
/// Order: validate locally → resolve nym + signer → prepare wallet 103 (ALWAYS,
/// so the 103 descriptor is ALWAYS sent - KR-1) → signed PUT with kind=pos,
/// label in the `header` slot, description/socials empty, enabled=true → then a
/// best-effort backup publish when the wallet was newly created (AD-3
/// post-commitment). Unlike the page, the server has NO empty-descriptor
/// fallback for kind=pos, so an empty descriptor both cannot be constructed here
/// (the `EmptyPosDescriptor` guard) AND is hard-rejected by the server: POS
/// sales settle to 103, never 101/102. Failures are wrapped as localPreparation
/// (pre-commitment, retryable, wallet rollback owned by prepare) or submission
/// (the signed PUT may have reached the server on a transport failure).
class ProvisionPosUsecase {
  final ResolvePosIdentityUsecase _resolveIdentity;
  final PreparePosWalletUsecase _prepareWallet;
  final BullnymFacade _bullnym;
  final GetPaidSettingsFacade _getPaidSettings;
  final String _terminalBaseUrl;

  const ProvisionPosUsecase({
    required this._resolveIdentity,
    required this._prepareWallet,
    required this._bullnym,
    required this._getPaidSettings,
    required this._terminalBaseUrl,
  });

  Future<PosTerminal> execute({
    required String label,
    required String displayCurrency,
    bool publishBackupSnapshot = true,
  }) async {
    // Local pre-filter (UX; the server remains the authority). A validation
    // failure never touches the wire or the wallet.
    PosProvisionCommand(label: label, displayCurrency: displayCurrency)
        .validate();

    var walletCreated = false;
    var walletPrepared = false;
    try {
      final ResolvedPosIdentity identity;
      final String ctDescriptor;
      try {
        identity = await _resolveIdentity.execute();
        final preparedWallet = await _prepareWallet.execute();
        // KR-1: the descriptor is ALWAYS the prepared 103 wallet's non-empty
        // external public descriptor - never empty, never absent. This runtime
        // guard makes the invariant explicit and fails BEFORE signing/wire so
        // POS sales can never route anywhere but wallet 103. There is NO other
        // save call site, so a descriptorless kind=pos save cannot be
        // constructed by any caller.
        ctDescriptor = preparedWallet.ctDescriptor;
        if (ctDescriptor.isEmpty) {
          throw const PosException.localPreparationFailed(
            code: 'EmptyPosDescriptor',
            retryable: false,
          );
        }
        walletCreated = preparedWallet.created;
        walletPrepared = true;
      } on PosException catch (e) {
        throw PosProvisionException.localPreparation(cause: e);
      }

      try {
        final view = await _bullnym.saveDonationPage(
          signer: identity.signer,
          nym: identity.nym,
          ctDescriptor: ctDescriptor,
          header: label,
          description: '',
          displayCurrency: displayCurrency,
          website: '',
          twitter: '',
          instagram: '',
          enabled: true,
          kind: bullnymDonationPageKindPos,
        );
        return PosTerminal.fromBullnym(view, baseUrl: _terminalBaseUrl);
      } on BullnymException catch (e) {
        throw PosProvisionException.submission(
          cause: PosException.fromBullnym(e),
        );
      } on PosException catch (e) {
        throw PosProvisionException.submission(cause: e);
      }
    } finally {
      // Post-commitment (AD-3): the manifest record is durable once the wallet
      // was created, so the new 103 record must ride the next backup snapshot.
      // Best-effort - never changes this flow's outcome, never throws (guard
      // here too so a publish failure can never mask the save's own result -
      // §7.9).
      if (walletPrepared && walletCreated && publishBackupSnapshot) {
        try {
          await _getPaidSettings.publishBackupSnapshotIfEnabled();
        } catch (e, stack) {
          log.warning(
            'POS backup snapshot publish failed',
            error: e,
            trace: stack,
          );
        }
      }
    }
  }
}
