import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Presentation cubit for the SP send flow: commit a recipient, set the amount
/// and feerate, simulate, then sign and broadcast. Split out of SpCubit so the
/// send flow owns its own state and re-entrancy guard. Reads network/balance
/// through use cases for the up-front validation checks.
class SpSendCubit extends Cubit<SpSendState> {
  final PrepareSpPaymentUsecase prepareSpPaymentUsecase;
  final SendSpPaymentUsecase sendSpPaymentUsecase;
  final GetSpNetworkUsecase getSpNetworkUsecase;
  final GetSpBalanceUsecase getSpBalanceUsecase;

  SpSendCubit({
    required this.prepareSpPaymentUsecase,
    required this.sendSpPaymentUsecase,
    required this.getSpNetworkUsecase,
    required this.getSpBalanceUsecase,
  }) : super(const SpSendState());

  // Detects whether `input` is a silent payment address (sp1.../tsp1...) or
  // standard. Sets state.recipient; full checksum/format validation is deferred
  // to the Rust side in prepare(). One early UX check here: a silent payment
  // address whose network prefix doesn't match the wallet's network is rejected
  // up front (so the Continue tap surfaces the error instead of advancing to
  // the amount page only to fail at prepare).
  void previewRecipient(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(recipient: null, error: null));
      return;
    }
    final kind = classifySpAddress(trimmed);
    final isSp = kind.isSilentPayment;

    if (isSp) {
      final SpNetwork? network;
      try {
        network = getSpNetworkUsecase.execute();
      } catch (e) {
        // A read failure is not "network unknown": fail closed rather than skip
        // the wrong-network check and risk sending to the wrong chain.
        log.warning('SpSendCubit.previewRecipient: network read failed: $e');
        emit(
          state.copyWith(
            recipient: null,
            error: SpUnexpected('SP network read failed: $e'),
          ),
        );
        return;
      }
      if (network != null && !_allowedNetworks(kind).contains(network)) {
        emit(
          state.copyWith(
            recipient: null,
            error: const SpAddressNetworkMismatch(),
          ),
        );
        return;
      }
    }

    final recipient = isSp
        ? SpRecipientSp(
            address: trimmed,
            amountSat: state.amountSat ?? BigInt.zero,
            isMax: state.isMax,
          )
        : SpRecipientStandard(
            address: trimmed,
            amountSat: state.amountSat ?? BigInt.zero,
            isMax: state.isMax,
          );
    emit(state.copyWith(recipient: recipient, error: null));
  }

  void setAmount(BigInt sats) {
    emit(state.copyWith(amountSat: sats));
  }

  /// Validates [sats] against the available balance and stores it. Emits an
  /// inline error and returns false when the amount is non-positive or exceeds
  /// the available balance, so the UI can block advancing. Rust `prepare()`
  /// remains the authority on fee-inclusive feasibility and coin selection.
  bool setValidatedAmount(BigInt sats) {
    if (sats <= BigInt.zero) {
      emit(state.copyWith(error: const SpAmountBelowMinimum()));
      return false;
    }
    final available = _availableBalance();
    if (available != null && sats > available) {
      emit(state.copyWith(error: const SpAmountExceedsBalance()));
      return false;
    }
    emit(state.copyWith(amountSat: sats, error: null));
    return true;
  }

  void setFeerate(int feerate) {
    emit(state.copyWith(feerate: feerate));
  }

  /// Toggle send-max. When on, bwk drains all spendable coins on prepare and
  /// computes the amount (no manual amount needed).
  void setMax(bool isMax) {
    emit(state.copyWith(isMax: isMax, error: null));
  }

  Future<void> prepare() async {
    if (state.isLoading) return;
    final recipient = state.recipient;
    final amount = state.amountSat;
    // In max mode bwk computes the amount, so a manual amount is not required.
    if (recipient == null || (amount == null && !state.isMax)) {
      emit(
        state.copyWith(
          error: const SpUnexpected('SP prepare: recipient and amount required'),
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, txSimulation: null, error: null));
    final recipientPrepared = _withAmount(
      recipient,
      amount ?? BigInt.zero,
      state.isMax,
    );
    final result = await prepareSpPaymentUsecase.execute(
      recipients: [recipientPrepared],
      feerateSatVb: BigInt.from(state.feerate),
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        // Reflect the simulated output amount (the computed value when max).
        final outputAmount = value.outputs.isNotEmpty
            ? _amountOf(value.outputs.first)
            : amount;
        emit(
          state.copyWith(
            isLoading: false,
            txSimulation: value,
            recipient: recipientPrepared,
            amountSat: outputAmount,
          ),
        );
      case Err(:final failure):
        log.warning('SpSendCubit.prepare: ${failure.logMessage}');
        emit(state.copyWith(isLoading: false, error: failure));
    }
  }

  Future<void> signAndBroadcast() async {
    // Re-entrancy guard: the finalize -> sign -> broadcast sequence is
    // irreversible; a second concurrent invocation would produce a second
    // signed tx spending the same coins. Dedicated flag, not isLoading.
    if (state.isBroadcasting) return;
    final recipient = state.recipient;
    final amount = state.amountSat;
    final simulation = state.txSimulation;
    if (recipient == null || amount == null) {
      emit(
        state.copyWith(
          error: const SpUnexpected('SP send: recipient and amount required'),
        ),
      );
      return;
    }
    // Confirm is only reachable after prepare() succeeded. A missing
    // simulation means the flow was driven outside the documented path, so
    // refuse rather than rebuilding a tx the user never saw.
    if (simulation == null) {
      emit(
        state.copyWith(
          error: const SpUnexpected('SP send: missing simulation'),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isBroadcasting: true,
        isLoading: true,
        txid: '',
        error: null,
      ),
    );
    // Pinned to the confirmed simulation; the use case (via the FFI) fails
    // loudly if the coin store drifted, so we never broadcast a tx whose
    // inputs differ from what was shown on the Confirm page. The txid is
    // logged inside the repository before returning so it survives even an
    // emit-after-close race.
    final result = await sendSpPaymentUsecase.execute(draft: simulation);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        // Clear the send-flow inputs on success so a back-nav to the confirm
        // page can't re-enter signAndBroadcast against a stale simulation.
        emit(
          state.copyWith(
            isBroadcasting: false,
            isLoading: false,
            txid: value,
            recipient: null,
            amountSat: null,
            txSimulation: null,
          ),
        );
      case Err(:final failure):
        log.warning('SpSendCubit.signAndBroadcast: ${failure.logMessage}');
        emit(
          state.copyWith(
            isBroadcasting: false,
            isLoading: false,
            error: failure,
          ),
        );
    }
  }

  SpRecipient _withAmount(SpRecipient recipient, BigInt amount, bool isMax) =>
      switch (recipient) {
        SpRecipientSp(:final address, :final label) => SpRecipientSp(
          address: address,
          amountSat: amount,
          label: label,
          isMax: isMax,
        ),
        SpRecipientStandard(:final address) => SpRecipientStandard(
          address: address,
          amountSat: amount,
          isMax: isMax,
        ),
      };

  BigInt _amountOf(SpRecipient recipient) => recipient.amountSat;

  // Networks a silent payment address of the given kind may be sent to. The
  // tsp1 hrp is shared by testnet and signet, so both are accepted for it.
  Set<SpNetwork> _allowedNetworks(SpAddressKind kind) => switch (kind) {
    SpAddressKind.silentPaymentMainnet => const {SpNetwork.bitcoin},
    SpAddressKind.silentPaymentRegtest => const {SpNetwork.regtest},
    SpAddressKind.silentPaymentTestnet => const {
      SpNetwork.testnet,
      SpNetwork.signet,
    },
    SpAddressKind.bitcoin || SpAddressKind.unrecognized => const {},
  };

  void resetSendFlow() {
    emit(
      state.copyWith(
        recipient: null,
        amountSat: null,
        isMax: false,
        txSimulation: null,
        txid: '',
        error: null,
      ),
    );
  }

  // Snapshot balance for the amount ceiling check. A null result (no session,
  // or the scan holds the inner lock) skips the ceiling; Rust prepare() stays
  // the authority on feasibility.
  BigInt? _availableBalance() {
    try {
      return getSpBalanceUsecase.execute().totalUnifiedSat;
    } catch (e) {
      log.warning('SpSendCubit: balance read failed: $e');
      return null;
    }
  }
}
