import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';
import 'package:bb_mobile/features/pos/presentation/pos_state.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the Point of Sale provisioning screen. Reaches other features only
/// through the [PosFacade] and the [LightningAddressFacade] (the DG-P6 nym
/// step). An [_operationId] guard makes double-taps and stale async completions
/// inert. Holds NO secrets and NO descriptor.
class PosCubit extends Cubit<PosState> {
  static const _nymNotFoundCode = 'NymNotFound';

  final PosFacade _facade;
  final LightningAddressFacade _lightningAddress;
  final GetGetPaidWalletBehaviorsUsecase _getWalletBehaviors;
  final UpdateWalletBehaviorUsecase _updateWalletBehavior;
  int _operationId = 0;

  PosCubit({
    required this._facade,
    required this._lightningAddress,
    required this._getWalletBehaviors,
    required this._updateWalletBehavior,
  }) : super(const PosState());

  Future<void> load() async {
    if (state.submitting) return;
    final op = ++_operationId;
    emit(
      state.copyWith(
        status: PosStatus.loading,
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
            status: PosStatus.needsNym,
            walletBehavior: walletBehavior,
            clearWalletBehavior: walletBehavior == null,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: PosStatus.loadFailed,
          failure: posExceptionFromLightningAddress(e),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    } catch (e, stack) {
      log.warning('Point of Sale nym probe failed', error: e, trace: stack);
      if (_isStale(op)) return;
      emit(
        state.copyWith(
          status: PosStatus.loadFailed,
          failure: const PosException.unexpected(),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }

    // Currencies degrade to the fallback rather than blocking the screen.
    var currencies = const <DisplayCurrency>[];
    var currenciesUnavailable = false;
    try {
      currencies = await _facade.supportedCurrencies();
    } catch (e, stack) {
      log.warning(
        'Point of Sale currency fetch failed',
        error: e,
        trace: stack,
      );
      currenciesUnavailable = true;
    }
    if (_isStale(op)) return;

    final PosTerminal? terminal;
    try {
      terminal = await _facade.find(nym: nym);
    } catch (e, stack) {
      log.warning('Point of Sale probe failed', error: e, trace: stack);
      if (_isStale(op)) return;
      emit(
        state.copyWith(
          status: PosStatus.loadFailed,
          nym: nym,
          failure: _asPosException(e),
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }
    if (_isStale(op)) return;

    if (terminal == null) {
      emit(
        state.copyWith(
          status: PosStatus.create,
          nym: nym,
          currencies: currencies,
          currenciesUnavailable: currenciesUnavailable,
          displayCurrency: _defaultCurrency(currencies),
          label: '',
          clearTerminal: true,
          clearFailure: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: terminal.isArchived ? PosStatus.archived : PosStatus.edit,
        nym: nym,
        terminal: terminal,
        currencies: currencies,
        currenciesUnavailable: currenciesUnavailable,
        label: terminal.label,
        displayCurrency: terminal.displayCurrency,
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
        'Point of Sale currency retry failed',
        error: e,
        trace: stack,
      );
    }
  }

  void nymDraftChanged(String value) =>
      emit(state.copyWith(nymDraft: value, clearFailure: true));

  void labelChanged(String value) => emit(
    state.copyWith(
      label: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PosField.label,
    ),
  );

  void displayCurrencyChanged(String value) => emit(
    state.copyWith(
      displayCurrency: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == PosField.displayCurrency,
    ),
  );

  /// DG-P6: register the nym (and wallet 101) through the shared Lightning
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
        'Point of Sale nym registration failed',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(state.copyWith(submitting: false, failure: _asPosException(e)));
    }
  }

  Future<void> provision() async {
    if (state.submitting) return;
    final command = state.command;
    final invalidField = command.firstInvalidField();
    if (invalidField != null) {
      emit(
        state.copyWith(
          failure: PosException.invalidInput(code: invalidField.name),
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
      final terminal = await _facade.provision(command);
      if (isClosed || _isStale(op)) return;
      // Provisioning creates wallet 103, so refresh its resolved behavior.
      final walletBehavior = await _resolveWalletBehavior();
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(
          submitting: false,
          status: terminal.isArchived ? PosStatus.archived : PosStatus.edit,
          terminal: terminal,
          label: terminal.label,
          displayCurrency: terminal.displayCurrency,
          clearFailure: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    } on PosProvisionException catch (e) {
      if (isClosed || _isStale(op)) return;
      emit(
        state.copyWith(
          submitting: false,
          failure: e,
          submissionUncertain: e.submissionMayBeUncertain,
        ),
      );
    } catch (e, stack) {
      log.warning('Point of Sale provision failed', error: e, trace: stack);
      if (isClosed || _isStale(op)) return;
      emit(state.copyWith(submitting: false, failure: _asPosException(e)));
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
      log.warning('Point of Sale archive failed', error: e, trace: stack);
      if (isClosed || _isStale(op)) return;
      emit(state.copyWith(submitting: false, failure: _asPosException(e)));
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
        'Point of Sale wallet behavior update failed',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(walletBehavior: previous, walletBehaviorSaving: false),
      );
    }
  }

  // Read-only resolution of the reserved wallet (103); null until it exists.
  Future<GetPaidWalletBehavior?> _resolveWalletBehavior() async {
    try {
      final behaviors = await _getWalletBehaviors.execute(
        only: GetPaidWalletProduct.pos,
      );
      return behaviors.isEmpty ? null : behaviors.first;
    } catch (e, stack) {
      log.warning(
        'Failed to load Point of Sale wallet behavior',
        error: e,
        trace: stack,
      );
      return null;
    }
  }

  bool _isStale(int op) => isClosed || op != _operationId;

  String _defaultCurrency(List<DisplayCurrency> currencies) {
    if (currencies.any((c) => c.code == posFallbackCurrency)) {
      return posFallbackCurrency;
    }
    if (currencies.isNotEmpty) return currencies.first.code;
    return posFallbackCurrency;
  }

  PosException _asPosException(Object error) {
    if (error is PosException) return error;
    if (error is LightningAddressException) {
      return posExceptionFromLightningAddress(error);
    }
    return const PosException.unexpected();
  }
}
