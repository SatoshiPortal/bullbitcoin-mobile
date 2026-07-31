import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/broadcast_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_own_change_addresses_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/parse_sweep_address_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/preview_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/sign_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Debounce before pricing a typed custom rate — one build per pause, not per
/// keystroke.
const _customFeeDebounce = Duration(milliseconds: 600);

/// Presentation for the sweep flow. Holds the allocation form, delegates every
/// decision to a use-case, and keeps no business rule of its own.
///
/// Also the driving adapter for the shared fee modal in `core/widgets/fees/`
/// ([FeeModalViewState] + [FeeModalActions]), so the sweep prices its fees with
/// the same component and the same real-PSBT numbers as send, sell and swap.
class SweepCubit extends Cubit<SweepState>
    implements FeeModalViewState, FeeModalActions {
  final GetSweepFeesUsecase _getFees;
  final PreviewSweepFeesUsecase _previewFees;
  final ParseSweepAddressUsecase _parseAddress;
  final GetOwnChangeAddressesUsecase _getOwnChangeAddresses;
  final BuildSweepPsbtUsecase _buildPsbt;
  final SignSweepPsbtUsecase _signPsbt;
  final BroadcastSweepPsbtUsecase _broadcast;
  final GetWalletUsecase _getWallet;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrency;
  final SettingsRepository _settingsRepository;

  Timer? _customFeeDebounceTimer;

  /// Guards against a slow preview for a rate the user has already replaced
  /// landing after a newer one and staging the wrong PSBT for broadcast.
  int _previewEpoch = 0;

  SweepCubit({
    required String walletId,
    required Network network,
    required List<WalletUtxo> inputs,
    required GetSweepFeesUsecase getSweepFeesUsecase,
    required PreviewSweepFeesUsecase previewSweepFeesUsecase,
    required ParseSweepAddressUsecase parseSweepAddressUsecase,
    required GetOwnChangeAddressesUsecase getOwnChangeAddressesUsecase,
    required BuildSweepPsbtUsecase buildSweepPsbtUsecase,
    required SignSweepPsbtUsecase signSweepPsbtUsecase,
    required BroadcastSweepPsbtUsecase broadcastSweepPsbtUsecase,
    required GetWalletUsecase getWalletUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required this._settingsRepository,
  }) : _getFees = getSweepFeesUsecase,
       _previewFees = previewSweepFeesUsecase,
       _parseAddress = parseSweepAddressUsecase,
       _getOwnChangeAddresses = getOwnChangeAddressesUsecase,
       _buildPsbt = buildSweepPsbtUsecase,
       _signPsbt = signSweepPsbtUsecase,
       _broadcast = broadcastSweepPsbtUsecase,
       _getWallet = getWalletUsecase,
       _convertSatsToCurrency = convertSatsToCurrencyAmountUsecase,
       super(SweepState(walletId: walletId, network: network, inputs: inputs));

  @override
  Future<void> close() {
    _customFeeDebounceTimer?.cancel();
    return super.close();
  }

  // ── Startup ───────────────────────────────────────────────────────────────

  /// Loads everything the form needs: fee presets, the fiat hint for the fee
  /// modal, and the wallet's own empty change addresses.
  Future<void> init() async {
    emit(state.copyWith(loadingFees: true));

    final fees = await _getFees.execute();
    if (isClosed) return;
    switch (fees) {
      case Ok(:final value):
        emit(state.copyWith(feePresets: value, loadingFees: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, loadingFees: false));
    }

    // Both are decoration: a missing fiat rate only hides a hint, and a missing
    // change-address list only hides a shortcut. Neither blocks the sweep, so
    // neither is surfaced as a failure.
    await _loadFiatHint();
    await loadOwnChangeAddresses();
  }

  Future<void> _loadFiatHint() async {
    try {
      final settings = await _settingsRepository.fetch();
      final rate = await _convertSatsToCurrency.execute(
        amountSat: BigInt.from(100000000),
        currencyCode: settings.currencyCode,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          exchangeRate: rate,
          fiatCurrencyCode: settings.currencyCode,
        ),
      );
    } catch (e) {
      log.info('Sweep: no fiat hint available ($e)');
    }
  }

  Future<void> loadOwnChangeAddresses() async {
    final result = await _getOwnChangeAddresses.execute(
      walletId: state.walletId,
    );
    if (isClosed) return;
    if (result case Ok(:final value)) {
      emit(state.copyWith(ownChangeAddresses: value));
    }
  }

  // ── Allocation form ───────────────────────────────────────────────────────

  void addRecipient() {
    emit(
      state.copyWith(
        allocations: [
          ...state.allocations,
          const SweepAllocation(address: ''),
        ],
        quote: null,
        failure: null,
      ),
    );
  }

  void removeRecipient(int index) {
    if (state.allocations.length <= 1) return;
    final next = [...state.allocations]..removeAt(index);
    emit(state.copyWith(allocations: next, quote: null, failure: null));
  }

  void addressChanged(int index, String address) {
    _updateRow(index, (row) => row.copyWith(address: address));
  }

  /// [amountSat] is null when the field is empty. Setting an amount clears the
  /// row's remainder flag — a row is either pinned or takes the rest.
  void amountChanged(int index, BigInt? amountSat) {
    _updateRow(
      index,
      (row) => row.copyWith(
        amountSat: amountSat,
        clearAmount: amountSat == null,
        takesRemainder: false,
      ),
    );
  }

  /// Makes [index] the row that absorbs the remainder, clearing the flag
  /// everywhere else — only one output can drain it.
  void takeRemainder(int index) {
    final next = <SweepAllocation>[];
    for (var i = 0; i < state.allocations.length; i++) {
      final row = state.allocations[i];
      next.add(
        i == index
            ? row.copyWith(takesRemainder: true, clearAmount: true)
            : row.copyWith(takesRemainder: false),
      );
    }
    emit(state.copyWith(allocations: next, quote: null, failure: null));
  }

  /// Gives the remainder back to the wallet's own change output.
  void releaseRemainder(int index) {
    _updateRow(index, (row) => row.copyWith(takesRemainder: false));
  }

  void _updateRow(int index, SweepAllocation Function(SweepAllocation) update) {
    if (index < 0 || index >= state.allocations.length) return;
    final next = [...state.allocations];
    next[index] = update(next[index]);
    emit(state.copyWith(allocations: next, quote: null, failure: null));
  }

  // ── Review ────────────────────────────────────────────────────────────────

  /// Resolves the typed addresses, validates the plan and builds the unsigned
  /// transaction. Moves to [SweepStep.review] on success.
  Future<void> review() async {
    final fee = state.selectedFee;
    if (fee == null) {
      emit(state.copyWith(failure: const SweepFeesUnavailableFailure()));
      return;
    }

    emit(
      state.copyWith(
        building: true,
        failure: null,
        quote: null,
        // A new plan invalidates every price: the cache is keyed on the shape
        // of the transaction, and that shape just changed.
        feePreviewCache: const BitcoinFeePreviewCache(),
      ),
    );

    final List<SweepAllocation> allocations;
    switch (await _resolveAddresses()) {
      case Ok(:final value):
        allocations = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(building: false, failure: failure));
        return;
    }
    if (isClosed) return;
    emit(state.copyWith(allocations: allocations));

    final SweepPlan plan;
    switch (SweepPlan.validate(
      inputs: state.inputs,
      allocations: allocations,
    )) {
      case Ok(:final value):
        plan = value;
      case Err(:final failure):
        emit(state.copyWith(building: false, failure: failure));
        return;
    }

    final quote = await _buildPsbt.execute(
      walletId: state.walletId,
      plan: plan,
      networkFee: fee,
    );
    if (isClosed) return;

    switch (quote) {
      case Ok(:final value):
        emit(
          state.copyWith(
            building: false,
            quote: value,
            step: SweepStep.review,
            // Seed the cache slot for the rate we just built, so reopening the
            // fee modal doesn't re-price what is already priced.
            feePreviewCache: state.feePreviewCache.withSlot(
              state.selectedFeeOption,
              BitcoinFeePreviewSlot(
                feeSat: value.feeSat.toInt(),
                unsignedPsbt: value.unsignedPsbt,
                txSize: value.txSize,
              ),
            ),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(building: false, failure: failure));
    }
  }

  /// Normalises every row's address, prefilling an amount when the user pasted
  /// a BIP21 URI that carried one.
  Future<Result<List<SweepAllocation>, SweepFailure>>
  _resolveAddresses() async {
    final resolved = <SweepAllocation>[];
    for (final row in state.allocations) {
      final parsed = await _parseAddress.execute(
        input: row.address,
        network: state.network,
      );
      switch (parsed) {
        case Ok(:final value):
          final keepAmount = row.takesRemainder || row.amountSat != null;
          resolved.add(
            row.copyWith(
              address: value.address,
              amountSat: keepAmount ? row.amountSat : value.amountSat,
            ),
          );
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(resolved);
  }

  void backToAllocation() {
    emit(state.copyWith(step: SweepStep.allocate, quote: null, failure: null));
  }

  // ── Fee selection (shared modal) ──────────────────────────────────────────

  /// Re-prices the sweep under review at [fee], reusing a cached build when one
  /// exists for that slot.
  Future<void> _applyFee(FeeSelection selection, NetworkFee fee) async {
    final plan = state.quote?.plan;
    if (plan == null) return;

    final cached = state.feePreviewCache.slotFor(selection);
    if (cached.isCacheReady) {
      emit(
        state.copyWith(
          selectedFeeOption: selection,
          customFee: selection == FeeSelection.custom ? fee : state.customFee,
          quote: SweepQuote(
            plan: plan,
            networkFee: fee,
            unsignedPsbt: cached.unsignedPsbt!,
            txSize: cached.txSize!,
            feeSat: BigInt.from(cached.feeSat!),
          ),
        ),
      );
      return;
    }

    emit(state.copyWith(selectedFeeOption: selection, building: true));
    final result = await _buildPsbt.execute(
      walletId: state.walletId,
      plan: plan,
      networkFee: fee,
    );
    if (isClosed) return;

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            building: false,
            quote: value,
            feePreviewCache: state.feePreviewCache.withSlot(
              selection,
              BitcoinFeePreviewSlot(
                feeSat: value.feeSat.toInt(),
                unsignedPsbt: value.unsignedPsbt,
                txSize: value.txSize,
              ),
            ),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(building: false, failure: failure));
    }
  }

  Future<void> feeOptionSelected(FeeSelection selection) async {
    final fee = switch (selection) {
      FeeSelection.fastest => state.feePresets?.fastest,
      FeeSelection.economic => state.feePresets?.economic,
      FeeSelection.slow => state.feePresets?.slow,
      FeeSelection.custom => state.customFee,
    };
    if (fee == null) return;

    // Record the choice first, and unconditionally: the selection is also
    // meaningful before a quote exists (it is the rate `review()` will build
    // with). Only the re-pricing below needs a plan.
    emit(
      state.copyWith(
        selectedFeeOption: selection,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
    await _applyFee(selection, fee);
  }

  /// Builds one PSBT per preset so every tile shows its real fee.
  Future<void> loadFeePresetPreviews() async {
    final plan = state.quote?.plan;
    final presets = state.feePresets;
    if (plan == null || presets == null) return;

    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(presetsLoading: true),
      ),
    );

    final slots = await _previewFees.presets(
      walletId: state.walletId,
      plan: plan,
      presets: presets,
    );
    if (isClosed) return;

    var cache = state.feePreviewCache;
    for (final entry in slots.entries) {
      // Never clobber a slot that already holds a build with an empty one.
      if (entry.value.isCacheReady || !cache.slotFor(entry.key).isCacheReady) {
        cache = cache.withSlot(entry.key, entry.value);
      }
    }
    emit(
      state.copyWith(feePreviewCache: cache.copyWith(presetsLoading: false)),
    );
  }

  /// Debounced pricing of a typed custom rate.
  Future<void> previewCustomFee(NetworkFee fee) async {
    final plan = state.quote?.plan;
    if (plan == null) return;

    _customFeeDebounceTimer?.cancel();
    final epoch = ++_previewEpoch;
    emit(
      state.copyWith(
        feePreviewCache: state.feePreviewCache.copyWith(customLoading: true),
      ),
    );

    _customFeeDebounceTimer = Timer(_customFeeDebounce, () async {
      final slot = await _previewFees.one(
        walletId: state.walletId,
        plan: plan,
        networkFee: fee,
      );
      if (isClosed || epoch != _previewEpoch) return;
      emit(
        state.copyWith(
          feePreviewCache: state.feePreviewCache
              .withSlot(FeeSelection.custom, slot)
              .copyWith(customLoading: false),
        ),
      );
    });
  }

  // ── FeeModalViewState + FeeModalActions ───────────────────────────────────
  // The shared modal in lib/core/widgets/fees/ depends on these two ports; the
  // bodies only delegate, so the port surface stays a stable contract.

  static FeeModalSnapshot _modalSnapshotFrom(SweepState s) => FeeModalSnapshot(
    feePresets: s.feePresets,
    customFee: s.customFee,
    selectedFeeOption: s.selectedFeeOption,
    feePreviewCache: s.feePreviewCache,
    exchangeRate: s.exchangeRate,
    fiatCurrencyCode: s.fiatCurrencyCode,
    txSize: s.quote?.txSize ?? 140,
  );

  @override
  FeeModalSnapshot get snapshot => _modalSnapshotFrom(state);

  @override
  Stream<FeeModalSnapshot> get snapshots => stream.map(_modalSnapshotFrom);

  @override
  void requestPresetPreviews() => unawaited(loadFeePresetPreviews());

  @override
  void requestCustomFeePreview(NetworkFee fee) =>
      unawaited(previewCustomFee(fee));

  @override
  void selectFeeOption(FeeSelection selection) =>
      unawaited(feeOptionSelected(selection));

  /// Eager arm: show the typed rate as selected without rebuilding yet, keeping
  /// the pre-arm selection so a dismissal without a valid rate rolls back.
  @override
  void armCustomFee(NetworkFee fee) {
    // The typed rate changed, so the cached custom build is for the old rate.
    // Bump the epoch too: a preview for the previous rate may still be in
    // flight and must not land on the new one.
    _previewEpoch++;
    final cleared = state.feePreviewCache.withSlot(
      FeeSelection.custom,
      const BitcoinFeePreviewSlot(),
    );
    emit(
      state.copyWith(
        armPriorSelection: state.armPriorSelection ?? state.selectedFeeOption,
        armPriorCustomFee: state.armPriorSelection == null
            ? state.customFee
            : state.armPriorCustomFee,
        selectedFeeOption: FeeSelection.custom,
        customFee: fee,
        feePreviewCache: cleared,
      ),
    );
  }

  @override
  void disarmCustomFee() {
    final prior = state.armPriorSelection;
    if (prior == null) return;
    emit(
      state.copyWith(
        selectedFeeOption: prior,
        customFee: state.armPriorCustomFee,
        armPriorSelection: null,
        armPriorCustomFee: null,
      ),
    );
  }

  /// Called when the fee modal is dismissed. Commits the typed rate when it
  /// clears the relay floor, otherwise rolls back to the pre-arm selection.
  @override
  void finalizeArmedCustomFee() {
    final prior = state.armPriorSelection;
    if (prior == null) return;

    final typed = state.customFee;
    final floor = state.feePresets?.minRelay.satPerKwu;
    final acceptable =
        typed != null &&
        typed.aboveMinRelay(txSize: state.quote?.txSize, floorSatPerKwu: floor);

    emit(state.copyWith(armPriorSelection: null, armPriorCustomFee: null));

    if (!acceptable) {
      emit(
        state.copyWith(
          selectedFeeOption: prior,
          customFee: state.armPriorCustomFee,
          failure: const SweepFeeTooLowFailure(),
        ),
      );
      return;
    }
    unawaited(_applyFee(FeeSelection.custom, typed));
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  /// Signs and broadcasts the quote under review.
  Future<void> confirm() async {
    final quote = state.quote;
    if (quote == null) {
      emit(state.copyWith(failure: const SweepBuildFailure('no quote')));
      return;
    }
    if (state.broadcasting || state.txId != null) {
      log.warning('Sweep already broadcasting or broadcast; ignoring confirm');
      return;
    }

    emit(state.copyWith(broadcasting: true, failure: null));

    final String signedPsbt;
    switch (await _signPsbt.execute(
      walletId: state.walletId,
      unsignedPsbt: quote.unsignedPsbt,
    )) {
      case Ok(:final value):
        signedPsbt = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(broadcasting: false, failure: failure));
        return;
    }
    if (isClosed) return;

    final broadcast = await _broadcast.execute(signedPsbt: signedPsbt);
    if (isClosed) return;

    switch (broadcast) {
      case Ok(:final value):
        emit(
          state.copyWith(
            broadcasting: false,
            txId: value,
            step: SweepStep.success,
          ),
        );
        // Pull the wallet forward so the Coins list and balance reflect the
        // spend without waiting for the next periodic sync.
        unawaited(
          _getWallet.execute(state.walletId, sync: true).catchError((Object e) {
            log.warning('Failed to sync the wallet after a sweep: $e');
            return null;
          }),
        );
      case Err(:final failure):
        emit(state.copyWith(broadcasting: false, failure: failure));
    }
  }

  /// Clears a transient failure once the UI has shown it.
  void clearFailure() {
    if (state.failure != null) emit(state.copyWith(failure: null));
  }
}
