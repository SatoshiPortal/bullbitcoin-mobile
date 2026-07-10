import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_state.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the Donation Page editor. Reaches other features only through the
/// [PaymentPageFacade] and the [LightningAddressFacade] (the DG-6 nym step). An
/// [_operationId] guard makes double-taps and stale async completions inert.
class PaymentPageCubit extends Cubit<PaymentPageState> {
  static const _nymNotFoundCode = 'NymNotFound';

  final PaymentPageFacade _facade;
  final LightningAddressFacade _lightningAddress;
  final GetGetPaidWalletBehaviorsUsecase _getWalletBehaviors;
  final UpdateWalletBehaviorUsecase _updateWalletBehavior;
  int _operationId = 0;

  PaymentPageCubit({
    required this._facade,
    required this._lightningAddress,
    required this._getWalletBehaviors,
    required this._updateWalletBehavior,
  }) : super(const PaymentPageState());

  Future<void> load() async {
    if (state.submitting) return;
    final op = ++_operationId;
    emit(
      state.copyWith(
        status: PaymentPageStatus.loading,
        clearFailure: true,
        submissionUncertain: false,
      ),
    );

    // Resolve the reserved wallet locally FIRST (label-match, no server) so the
    // behavior controls stay reachable even when the server load below fails.
    final walletBehavior = await _resolveWalletBehavior();
    if (_isStale(op)) return;

    final String nym;
    try {
      final status = await _lightningAddress.lookupWalletOwnedRegistration();
      nym = status.nym;
    } on LightningAddressException catch (e) {
      if (_isStale(op)) return;
      if (e.code == _nymNotFoundCode) {
        emit(
          state.copyWith(
            status: PaymentPageStatus.needsNym,
            walletBehavior: walletBehavior,
            clearWalletBehavior: walletBehavior == null,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: PaymentPageStatus.loadFailed,
          failure: paymentPageExceptionFromLightningAddress(e),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    } catch (e, stack) {
      log.warning('Donation Page nym probe failed', error: e, trace: stack);
      if (_isStale(op)) return;
      emit(
        state.copyWith(
          status: PaymentPageStatus.loadFailed,
          failure: const PaymentPageException.unexpected(),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }

    // Currencies degrade to the fallback rather than blocking the editor.
    var currencies = const <DisplayCurrency>[];
    var currenciesUnavailable = false;
    try {
      currencies = await _facade.supportedCurrencies();
    } catch (e, stack) {
      log.warning(
        'Donation Page currency fetch failed',
        error: e,
        trace: stack,
      );
      currenciesUnavailable = true;
    }
    if (_isStale(op)) return;

    final PaymentPage? page;
    try {
      page = await _facade.find(nym: nym);
    } catch (e, stack) {
      log.warning('Donation Page probe failed', error: e, trace: stack);
      if (_isStale(op)) return;
      emit(
        state.copyWith(
          status: PaymentPageStatus.loadFailed,
          nym: nym,
          failure: _asPaymentPageException(e),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }
    if (_isStale(op)) return;

    if (page == null) {
      emit(
        state.copyWith(
          status: PaymentPageStatus.create,
          nym: nym,
          currencies: currencies,
          currenciesUnavailable: currenciesUnavailable,
          displayCurrency: _defaultCurrency(currencies),
          header: '',
          description: '',
          website: '',
          twitter: '',
          instagram: '',
          clearPage: true,
          clearFailure: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: page.isArchived
            ? PaymentPageStatus.archived
            : PaymentPageStatus.edit,
        nym: nym,
        page: page,
        currencies: currencies,
        currenciesUnavailable: currenciesUnavailable,
        header: page.header,
        description: page.description,
        displayCurrency: page.displayCurrency,
        website: page.website ?? '',
        twitter: page.twitter ?? '',
        instagram: page.instagram ?? '',
        clearFailure: true,
        walletBehavior: walletBehavior,
        clearWalletBehavior: walletBehavior == null,
      ),
    );
  }

  Future<void> retryCurrencies() async {
    try {
      final currencies = await _facade.supportedCurrencies();
      if (isClosed) return;
      emit(
        state.copyWith(
          currencies: currencies,
          currenciesUnavailable: false,
          displayCurrency: state.displayCurrency.isEmpty
              ? _defaultCurrency(currencies)
              : state.displayCurrency,
        ),
      );
    } catch (e, stack) {
      log.warning(
        'Donation Page currency retry failed',
        error: e,
        trace: stack,
      );
    }
  }

  void nymDraftChanged(String value) =>
      emit(state.copyWith(nymDraft: value, clearFailure: true));

  void headerChanged(String value) => emit(
    state.copyWith(
      header: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.header,
    ),
  );

  void descriptionChanged(String value) => emit(
    state.copyWith(
      description: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.description,
    ),
  );

  void displayCurrencyChanged(String value) => emit(
    state.copyWith(
      displayCurrency: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.displayCurrency,
    ),
  );

  void websiteChanged(String value) => emit(
    state.copyWith(
      website: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.website,
    ),
  );

  void twitterChanged(String value) => emit(
    state.copyWith(
      twitter: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.twitter,
    ),
  );

  void instagramChanged(String value) => emit(
    state.copyWith(
      instagram: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PaymentPageField.instagram,
    ),
  );

  /// DG-6: register the nym (and wallet 101) through the shared Lightning
  /// Address facade, then reload into the create form.
  Future<void> createNym() async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearFailure: true));
    try {
      await _lightningAddress.registerWalletOwned(nym: state.nymDraft.trim());
      if (isClosed) return;
      emit(state.copyWith(submitting: false));
      await load();
    } catch (e, stack) {
      log.warning(
        'Donation Page nym registration failed',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(submitting: false, failure: _asPaymentPageException(e)),
      );
    }
  }

  Future<void> save() async {
    if (state.submitting) return;

    // Normalize the website + social handles at submit time and reflect the
    // result back into form state (the user sees `aa.com` become
    // `https://aa.com`, and `@name` become `name`) BEFORE validating.
    final normalizedWebsite = normalizePaymentPageUrl(state.website);
    final normalizedTwitter = stripHandleAt(state.twitter);
    final normalizedInstagram = stripHandleAt(state.instagram);
    if (normalizedWebsite != state.website ||
        normalizedTwitter != state.twitter ||
        normalizedInstagram != state.instagram) {
      emit(
        state.copyWith(
          website: normalizedWebsite,
          twitter: normalizedTwitter,
          instagram: normalizedInstagram,
        ),
      );
    }

    final command = state.command;
    final invalidField = command.firstInvalidField();
    if (invalidField != null) {
      emit(
        state.copyWith(
          failure: PaymentPageException.invalidInput(code: invalidField.name),
          invalidField: invalidField,
        ),
      );
      return;
    }

    final op = ++_operationId;
    emit(
      state.copyWith(
        submitting: true,
        clearFailure: true,
        clearInvalidField: true,
        submissionUncertain: false,
      ),
    );
    try {
      final page = await _facade.save(command);
      if (isClosed || _isStale(op)) return;
      // Saving provisions wallet 102, so refresh its resolved behavior.
      final walletBehavior = await _resolveWalletBehavior();
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(
          submitting: false,
          status: page.isArchived
              ? PaymentPageStatus.archived
              : PaymentPageStatus.edit,
          page: page,
          header: page.header,
          description: page.description,
          displayCurrency: page.displayCurrency,
          website: page.website ?? '',
          twitter: page.twitter ?? '',
          instagram: page.instagram ?? '',
          clearFailure: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    } on PaymentPageSaveException catch (e) {
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(
          submitting: false,
          failure: e,
          submissionUncertain: e.submissionMayBeUncertain,
        ),
      );
    } catch (e, stack) {
      log.warning('Donation Page save failed', error: e, trace: stack);
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(submitting: false, failure: _asPaymentPageException(e)),
      );
    }
  }

  Future<void> archive() async {
    if (state.submitting) return;
    final op = ++_operationId;
    emit(state.copyWith(submitting: true, clearFailure: true));
    try {
      await _facade.archive();
      if (isClosed || _isStale(op)) return;
      emit(state.copyWith(submitting: false));
      await load();
    } catch (e, stack) {
      log.warning('Donation Page archive failed', error: e, trace: stack);
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(submitting: false, failure: _asPaymentPageException(e)),
      );
    }
  }

  /// Updates the reserved wallet's auto-sweep / hide-on-home behavior with the
  /// same optimistic-emit / revert-on-failure / saving-guard posture BTCPay
  /// uses (`BtcpayPairingCubit.updateWalletBehavior`).
  Future<void> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    if (state.walletBehaviorSaving) return;
    final previous = state.walletBehavior;
    if (previous == null || previous.walletId != walletId) return;
    emit(
      state.copyWith(
        walletBehavior: previous.copyWith(
          hideOnHome: hideOnHome,
          autoSweepEnabled: autoSweepEnabled,
        ),
        walletBehaviorSaving: true,
      ),
    );
    try {
      await _updateWalletBehavior.execute(
        walletId: walletId,
        hideOnHome: hideOnHome,
        autoSweepEnabled: autoSweepEnabled,
      );
      if (isClosed) return;
      final refreshed = await _resolveWalletBehavior();
      if (isClosed) return;
      emit(
        state.copyWith(
          walletBehavior: refreshed,
          clearWalletBehavior: refreshed == null,
          walletBehaviorSaving: false,
        ),
      );
    } catch (e, stack) {
      log.warning(
        'Donation Page wallet behavior update failed',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(walletBehavior: previous, walletBehaviorSaving: false),
      );
    }
  }

  // Read-only resolution of the reserved wallet (102); null until it exists.
  Future<GetPaidWalletBehavior?> _resolveWalletBehavior() async {
    try {
      final behaviors = await _getWalletBehaviors.execute(
        only: GetPaidWalletProduct.paymentPage,
      );
      return behaviors.isEmpty ? null : behaviors.first;
    } catch (e, stack) {
      log.warning(
        'Failed to load Donation Page wallet behavior',
        error: e,
        trace: stack,
      );
      return null;
    }
  }

  bool _isStale(int op) => isClosed || op != _operationId;

  String _defaultCurrency(List<DisplayCurrency> currencies) {
    if (currencies.any((c) => c.code == paymentPageFallbackCurrency)) {
      return paymentPageFallbackCurrency;
    }
    if (currencies.isNotEmpty) return currencies.first.code;
    return paymentPageFallbackCurrency;
  }

  PaymentPageException _asPaymentPageException(Object error) {
    if (error is PaymentPageException) return error;
    if (error is LightningAddressException) {
      return paymentPageExceptionFromLightningAddress(error);
    }
    return const PaymentPageException.unexpected();
  }
}
