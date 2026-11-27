import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:sync/sync.dart' show Coin;

/// How a sell or pay payin from an app wallet is built, chosen on the
/// review before the payin's Building state: the fee (a preset or a custom
/// rate / amount, priced by previews), replace-by-fee, the coins picked by
/// hand and whether a payjoin the order offers is used. A failed fee
/// estimate is its own state with Retry; Confirm needs [spendOptionsChosen].
@immutable
sealed class SpendOptionsState {
  const SpendOptionsState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is SpendOptionsState &&
      other.runtimeType == runtimeType &&
      _same(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType';
}

bool _same(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _outpoints(Iterable<Coin> coins) => ([
  for (final coin in coins) '${coin.outpoint.txId}:${coin.outpoint.vout}',
]..sort()).join(',');

/// An external payin: nothing is built in the app.
final class SpendOptionsNone extends SpendOptionsState {
  const SpendOptionsNone();

  @override
  List<Object?> get _props => const [];
}

/// A payin whose options are fixed (Liquid: the network minimum).
final class SpendOptionsFixed extends SpendOptionsState {
  final PayinSpendOptions options;

  const SpendOptionsFixed(this.options);

  @override
  List<Object?> get _props => [options];
}

/// Reading the network's fee estimates for [walletId]'s payin.
final class SpendFeesLoading extends SpendOptionsState {
  final String walletId;
  final int attempt;

  const SpendFeesLoading(this.walletId, this.attempt);

  @override
  List<Object?> get _props => [walletId, attempt];
}

/// The fee estimates could not be read: no fee is assumed, Confirm waits
/// for a Retry that reads them.
final class SpendFeesUnavailable extends SpendOptionsState {
  final String walletId;
  final int attempt;

  const SpendFeesUnavailable(this.walletId, this.attempt);

  @override
  List<Object?> get _props => [walletId, attempt];
}

/// Where the previews are priced: the quoted order's deposit and amount.
@immutable
final class SpendPreviewTarget {
  final String address;
  final int amountSat;

  const SpendPreviewTarget(this.address, this.amountSat);

  @override
  bool operator ==(Object other) =>
      other is SpendPreviewTarget &&
      other.address == address &&
      other.amountSat == amountSat;

  @override
  int get hashCode => Object.hash(address, amountSat);
}

/// The wallet's coins, read when the user opens the coin selection.
@immutable
sealed class SpendCoins {
  const SpendCoins();
}

final class SpendCoinsNotLoaded extends SpendCoins {
  const SpendCoinsNotLoaded();

  @override
  bool operator ==(Object other) => other is SpendCoinsNotLoaded;

  @override
  int get hashCode => (SpendCoinsNotLoaded).hashCode;
}

final class SpendCoinsLoading extends SpendCoins {
  const SpendCoinsLoading();

  @override
  bool operator ==(Object other) => other is SpendCoinsLoading;

  @override
  int get hashCode => (SpendCoinsLoading).hashCode;
}

final class SpendCoinsLoaded extends SpendCoins {
  final List<Coin> coins;

  const SpendCoinsLoaded(this.coins);

  @override
  bool operator ==(Object other) =>
      other is SpendCoinsLoaded && _outpoints(other.coins) == _outpoints(coins);

  @override
  int get hashCode => _outpoints(coins).hashCode;
}

final class SpendCoinsUnavailable extends SpendCoins {
  const SpendCoinsUnavailable();

  @override
  bool operator ==(Object other) => other is SpendCoinsUnavailable;

  @override
  int get hashCode => (SpendCoinsUnavailable).hashCode;
}

/// What was committed before the custom-fee field started typing: dismissing
/// the fee sheet with a value under the relay floor goes back to it.
@immutable
final class SpendCustomArm {
  final FeeSelection selection;
  final NetworkFee? customFee;

  const SpendCustomArm(this.selection, this.customFee);

  @override
  bool operator ==(Object other) =>
      other is SpendCustomArm &&
      other.selection == selection &&
      other.customFee == customFee;

  @override
  int get hashCode => Object.hash(selection, customFee);
}

/// The fee estimates are in; every option can be changed until Confirm.
final class SpendOptionsReady extends SpendOptionsState {
  final String walletId;
  final FeeOptions fees;
  final FeeSelection selection;
  final NetworkFee? customFee;
  final SpendCustomArm? arm;
  final bool replaceByFee;
  final bool payjoin;
  final SpendCoins coins;
  final List<Coin> selected;
  final SpendPreviewTarget? target;
  final BitcoinFeePreviewCache previews;

  /// Bumped whenever the previews stop describing the payin (target, RBF,
  /// coins); a preview answer of an older epoch is a stay.
  final int epoch;

  const SpendOptionsReady({
    required this.walletId,
    required this.fees,
    this.selection = FeeSelection.fastest,
    this.customFee,
    this.arm,
    this.replaceByFee = true,
    this.payjoin = true,
    this.coins = const SpendCoinsNotLoaded(),
    this.selected = const [],
    this.target,
    this.previews = BitcoinFeePreviewCache.empty,
    this.epoch = 0,
  });

  /// The fee the payin is built at, or null while custom has no value.
  NetworkFee? get selectedFee => switch (selection) {
    FeeSelection.fastest => fees.fastest,
    FeeSelection.economic => fees.economic,
    FeeSelection.slow => fees.slow,
    FeeSelection.custom => customFee,
  };

  /// The size the previews measured, for the fee sheet's rate maths.
  int get txSize =>
      previews.slotFor(selection).txSize ?? previews.fastest.txSize ?? 140;

  SpendOptionsReady copyWith({
    FeeSelection? selection,
    NetworkFee? Function()? customFee,
    SpendCustomArm? Function()? arm,
    bool? replaceByFee,
    bool? payjoin,
    SpendCoins? coins,
    List<Coin>? selected,
    SpendPreviewTarget? target,
    BitcoinFeePreviewCache? previews,
    int? epoch,
  }) => SpendOptionsReady(
    walletId: walletId,
    fees: fees,
    selection: selection ?? this.selection,
    customFee: customFee == null ? this.customFee : customFee(),
    arm: arm == null ? this.arm : arm(),
    replaceByFee: replaceByFee ?? this.replaceByFee,
    payjoin: payjoin ?? this.payjoin,
    coins: coins ?? this.coins,
    selected: selected ?? this.selected,
    target: target ?? this.target,
    previews: previews ?? this.previews,
    epoch: epoch ?? this.epoch,
  );

  @override
  List<Object?> get _props => [
    walletId,
    fees,
    selection,
    customFee,
    arm,
    replaceByFee,
    payjoin,
    coins,
    _outpoints(selected),
    target,
    previews,
    epoch,
  ];
}

@immutable
sealed class SpendOptionsEvent {
  const SpendOptionsEvent();
}

final class SpendFeesLoaded extends SpendOptionsEvent {
  final int attempt;
  final FeeOptions fees;

  const SpendFeesLoaded(this.attempt, this.fees);
}

final class SpendFeesFailed extends SpendOptionsEvent {
  final int attempt;

  const SpendFeesFailed(this.attempt);
}

final class SpendRetryPressed extends SpendOptionsEvent {
  const SpendRetryPressed();
}

/// The quote the previews price changed (a new order or a refresh).
final class SpendTargetSet extends SpendOptionsEvent {
  final SpendPreviewTarget target;

  const SpendTargetSet(this.target);
}

/// The fee sheet opened: price every preset.
final class SpendPresetPreviewsRequested extends SpendOptionsEvent {
  const SpendPresetPreviewsRequested();
}

/// The custom-fee field settled on [fee]: price it.
final class SpendCustomPreviewRequested extends SpendOptionsEvent {
  final NetworkFee fee;

  const SpendCustomPreviewRequested(this.fee);
}

final class SpendPresetsPreviewed extends SpendOptionsEvent {
  final int epoch;
  final Map<FeeSelection, BitcoinFeePreviewSlot> slots;

  const SpendPresetsPreviewed(this.epoch, this.slots);
}

final class SpendCustomPreviewed extends SpendOptionsEvent {
  final int epoch;
  final NetworkFee fee;
  final BitcoinFeePreviewSlot slot;

  const SpendCustomPreviewed(this.epoch, this.fee, this.slot);
}

/// A preset tile was picked.
final class SpendFeePicked extends SpendOptionsEvent {
  final FeeSelection selection;

  const SpendFeePicked(this.selection);
}

/// The custom-fee field holds [fee]: custom is selected, the previous
/// choice kept until the sheet closes.
final class SpendCustomFeeArmed extends SpendOptionsEvent {
  final NetworkFee fee;

  const SpendCustomFeeArmed(this.fee);
}

/// The custom-fee field was cleared.
final class SpendCustomFeeDisarmed extends SpendOptionsEvent {
  const SpendCustomFeeDisarmed();
}

/// The fee sheet closed without a preset: keep the typed fee when it clears
/// the relay floor, else go back to the previous choice.
final class SpendCustomFeeFinalized extends SpendOptionsEvent {
  const SpendCustomFeeFinalized();
}

final class SpendRbfChanged extends SpendOptionsEvent {
  final bool enabled;

  const SpendRbfChanged({required this.enabled});
}

final class SpendPayjoinChanged extends SpendOptionsEvent {
  final bool enabled;

  const SpendPayjoinChanged({required this.enabled});
}

/// The coin selection opened: read the wallet's coins.
final class SpendCoinsRequested extends SpendOptionsEvent {
  const SpendCoinsRequested();
}

final class SpendCoinsRead extends SpendOptionsEvent {
  /// Null when the wallet could not list them.
  final List<Coin>? coins;

  const SpendCoinsRead(this.coins);
}

/// The coins the user picked; empty lets the wallet choose.
final class SpendCoinsPicked extends SpendOptionsEvent {
  final List<Coin> coins;

  const SpendCoinsPicked(this.coins);
}

@immutable
sealed class SpendOptionsEffect {
  const SpendOptionsEffect();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other is SpendOptionsEffect &&
      other.runtimeType == runtimeType &&
      _same(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));

  @override
  String toString() => '$runtimeType(${_props.join(', ')})';
}

/// Read the fee estimates; answer [SpendFeesLoaded] / [SpendFeesFailed].
final class SpendLoadFees extends SpendOptionsEffect {
  final int attempt;

  const SpendLoadFees(this.attempt);

  @override
  List<Object?> get _props => [attempt];
}

/// List [walletId]'s coins; answer [SpendCoinsRead].
final class SpendLoadCoins extends SpendOptionsEffect {
  final String walletId;

  const SpendLoadCoins(this.walletId);

  @override
  List<Object?> get _props => [walletId];
}

/// What a preview builds (unsigned, never sent).
@immutable
final class SpendPreviewShape {
  final String walletId;
  final SpendPreviewTarget target;
  final bool replaceByFee;
  final Set<Outpoint> coins;

  const SpendPreviewShape(
    this.walletId,
    this.target,
    this.replaceByFee,
    this.coins,
  );

  @override
  bool operator ==(Object other) =>
      other is SpendPreviewShape &&
      other.walletId == walletId &&
      other.target == target &&
      other.replaceByFee == replaceByFee &&
      other.coins.length == coins.length &&
      other.coins.containsAll(coins);

  @override
  int get hashCode => Object.hash(walletId, target, replaceByFee, coins.length);
}

/// Price the presets; answer [SpendPresetsPreviewed] for [epoch].
final class SpendPreviewPresets extends SpendOptionsEffect {
  final int epoch;
  final FeeOptions fees;
  final SpendPreviewShape shape;

  const SpendPreviewPresets(this.epoch, this.fees, this.shape);

  @override
  List<Object?> get _props => [epoch, fees, shape];
}

/// Price [fee]; answer [SpendCustomPreviewed] for [epoch].
final class SpendPreviewCustom extends SpendOptionsEffect {
  final int epoch;
  final NetworkFee fee;
  final SpendPreviewShape shape;

  const SpendPreviewCustom(this.epoch, this.fee, this.shape);

  @override
  List<Object?> get _props => [epoch, fee, shape];
}

typedef SpendOptionsNext = StepNext<SpendOptionsState, SpendOptionsEffect>;

/// The options of a payin from [source].
SpendOptionsNext spendOptionsStart(PayinSource source) => switch (source) {
  PayinFromExternal() => const SpendOptionsNext(SpendOptionsNone()),
  // The ID-only preview owner cannot bind this selection. Do not prepare or
  // preview against a replacement wallet while the UI migration is pending.
  PayinFromAppWallet(witness: _?) => const SpendOptionsNext(SpendOptionsNone()),
  PayinFromAppWallet(:final walletId, rail: BtcNetwork.bitcoin) =>
    SpendOptionsNext(SpendFeesLoading(walletId, 1), const [SpendLoadFees(1)]),
  PayinFromAppWallet(rail: BtcNetwork.liquid) => const SpendOptionsNext(
    SpendOptionsFixed(PayinSpendOptions.liquid),
  ),
  // No app wallet pays Lightning; the payin refuses it.
  PayinFromAppWallet(rail: BtcNetwork.lightning) => const SpendOptionsNext(
    SpendOptionsNone(),
  ),
};

/// [spend] pointed at the quoted [order]'s on-chain deposit and amount
/// (its previews price that payin); a stay for any other rail.
SpendOptionsNext spendTargetFor(
  SpendOptionsState spend,
  Order order,
  PayinSource source,
) => switch (source.rail.rail.depositOf(order)) {
  DepositGiven(target: OnchainDeposit(:final address)) =>
    transitionSpendOptions(
      spend,
      SpendTargetSet(
        SpendPreviewTarget(address, (order.payinAmount * 100000000).round()),
      ),
    ),
  DepositGiven() ||
  DepositNotGiven() ||
  DepositOnOtherRail() => SpendOptionsNext.stay(spend),
};

/// What Confirm may build with.
@immutable
sealed class SpendChoice {
  const SpendChoice();
}

/// Ready: [options] is null for an external payin (nothing is built).
final class SpendChosen extends SpendChoice {
  final PayinSpendOptions? options;

  const SpendChosen(this.options);
}

/// The fees are still loading or unavailable, or custom has no value yet.
final class SpendNotChosen extends SpendChoice {
  const SpendNotChosen();
}

SpendChoice spendOptionsChosen(SpendOptionsState state) => switch (state) {
  SpendOptionsNone() => const SpendChosen(null),
  SpendOptionsFixed(:final options) => SpendChosen(options),
  SpendFeesLoading() || SpendFeesUnavailable() => const SpendNotChosen(),
  final SpendOptionsReady ready => switch (ready.selectedFee) {
    final fee? => SpendChosen(
      PayinSpendOptions(
        fee: payinFeeOf(fee),
        replaceByFee: ready.replaceByFee,
        coins: {for (final coin in ready.selected) coin.outpoint},
        payjoin: ready.payjoin,
      ),
    ),
    null => const SpendNotChosen(),
  },
};

SpendOptionsNext transitionSpendOptions(
  SpendOptionsState state,
  SpendOptionsEvent event,
) => switch (state) {
  SpendOptionsNone() || SpendOptionsFixed() => SpendOptionsNext.stay(state),
  SpendFeesLoading() => _loading(state, event),
  SpendFeesUnavailable() => _unavailable(state, event),
  SpendOptionsReady() => _ready(state, event),
};

SpendOptionsNext _loading(SpendFeesLoading state, SpendOptionsEvent event) {
  switch (event) {
    case SpendFeesLoaded(:final attempt, :final fees)
        when attempt == state.attempt:
      return SpendOptionsNext(
        SpendOptionsReady(walletId: state.walletId, fees: fees),
      );
    case SpendFeesFailed(:final attempt) when attempt == state.attempt:
      return SpendOptionsNext(
        SpendFeesUnavailable(state.walletId, state.attempt),
      );
    case SpendFeesLoaded() ||
        SpendFeesFailed() ||
        SpendRetryPressed() ||
        SpendTargetSet() ||
        SpendPresetPreviewsRequested() ||
        SpendCustomPreviewRequested() ||
        SpendPresetsPreviewed() ||
        SpendCustomPreviewed() ||
        SpendFeePicked() ||
        SpendCustomFeeArmed() ||
        SpendCustomFeeDisarmed() ||
        SpendCustomFeeFinalized() ||
        SpendRbfChanged() ||
        SpendPayjoinChanged() ||
        SpendCoinsRequested() ||
        SpendCoinsRead() ||
        SpendCoinsPicked():
      return SpendOptionsNext.stay(state);
  }
}

SpendOptionsNext _unavailable(
  SpendFeesUnavailable state,
  SpendOptionsEvent event,
) {
  switch (event) {
    case SpendRetryPressed():
      final attempt = state.attempt + 1;
      return SpendOptionsNext(SpendFeesLoading(state.walletId, attempt), [
        SpendLoadFees(attempt),
      ]);
    case SpendFeesLoaded() ||
        SpendFeesFailed() ||
        SpendTargetSet() ||
        SpendPresetPreviewsRequested() ||
        SpendCustomPreviewRequested() ||
        SpendPresetsPreviewed() ||
        SpendCustomPreviewed() ||
        SpendFeePicked() ||
        SpendCustomFeeArmed() ||
        SpendCustomFeeDisarmed() ||
        SpendCustomFeeFinalized() ||
        SpendRbfChanged() ||
        SpendPayjoinChanged() ||
        SpendCoinsRequested() ||
        SpendCoinsRead() ||
        SpendCoinsPicked():
      return SpendOptionsNext.stay(state);
  }
}

SpendPreviewShape? _shape(SpendOptionsReady state) => switch (state.target) {
  final target? => SpendPreviewShape(
    state.walletId,
    target,
    state.replaceByFee,
    {for (final coin in state.selected) coin.outpoint},
  ),
  null => null,
};

/// The previews of [state]'s shape: the presets, and the custom fee when
/// it is the selection.
SpendOptionsNext _repriced(SpendOptionsReady state) {
  final shape = _shape(state);
  if (shape == null) return SpendOptionsNext(state);
  final custom = state.selection == FeeSelection.custom
      ? state.customFee
      : null;
  return SpendOptionsNext(
    state.copyWith(
      previews: state.previews.copyWith(
        presetsLoading: true,
        customLoading: custom != null,
      ),
    ),
    [
      SpendPreviewPresets(state.epoch, state.fees, shape),
      if (custom != null) SpendPreviewCustom(state.epoch, custom, shape),
    ],
  );
}

/// [state] with a new payin shape: every preview is dropped and priced
/// again under a new epoch.
SpendOptionsNext _reshaped(SpendOptionsReady state) => _repriced(
  state.copyWith(
    previews: BitcoinFeePreviewCache.empty,
    epoch: state.epoch + 1,
  ),
);

SpendOptionsNext _ready(SpendOptionsReady state, SpendOptionsEvent event) {
  switch (event) {
    case SpendTargetSet(:final target):
      if (target == state.target) return SpendOptionsNext.stay(state);
      return _reshaped(state.copyWith(target: target));
    case SpendPresetPreviewsRequested():
      final shape = _shape(state);
      if (shape == null || state.previews.presetsLoading) {
        return SpendOptionsNext.stay(state);
      }
      return SpendOptionsNext(
        state.copyWith(previews: state.previews.copyWith(presetsLoading: true)),
        [SpendPreviewPresets(state.epoch, state.fees, shape)],
      );
    case SpendCustomPreviewRequested(:final fee):
      final shape = _shape(state);
      if (shape == null) return SpendOptionsNext.stay(state);
      return SpendOptionsNext(
        state.copyWith(previews: state.previews.copyWith(customLoading: true)),
        [SpendPreviewCustom(state.epoch, fee, shape)],
      );
    case SpendPresetsPreviewed(:final epoch, :final slots)
        when epoch == state.epoch:
      return SpendOptionsNext(
        state.copyWith(
          previews: state.previews.copyWith(
            fastest:
                slots[FeeSelection.fastest] ?? const BitcoinFeePreviewSlot(),
            economic:
                slots[FeeSelection.economic] ?? const BitcoinFeePreviewSlot(),
            slow: slots[FeeSelection.slow] ?? const BitcoinFeePreviewSlot(),
            presetsLoading: false,
          ),
        ),
      );
    case SpendCustomPreviewed(:final epoch, :final fee, :final slot)
        when epoch == state.epoch && fee == state.customFee:
      return SpendOptionsNext(
        state.copyWith(
          previews: state.previews
              .withSlot(FeeSelection.custom, slot)
              .copyWith(customLoading: false),
        ),
      );
    case SpendFeePicked(:final selection):
      if (selection == FeeSelection.custom && state.customFee == null) {
        return SpendOptionsNext.stay(state);
      }
      return SpendOptionsNext(
        state.copyWith(selection: selection, arm: () => null),
      );
    case SpendCustomFeeArmed(:final fee):
      return SpendOptionsNext(
        state.copyWith(
          selection: FeeSelection.custom,
          customFee: () => fee,
          arm: () =>
              state.arm ?? SpendCustomArm(state.selection, state.customFee),
          previews: state.previews.withSlot(
            FeeSelection.custom,
            const BitcoinFeePreviewSlot(),
          ),
        ),
      );
    case SpendCustomFeeDisarmed():
      final arm = state.arm;
      if (arm == null) return SpendOptionsNext.stay(state);
      return SpendOptionsNext(_rolledBack(state, arm));
    case SpendCustomFeeFinalized():
      final arm = state.arm;
      if (arm == null) return SpendOptionsNext.stay(state);
      final fee = state.customFee;
      if (fee != null &&
          fee.aboveMinRelay(
            txSize: state.txSize,
            floorSatPerKwu: state.fees.minRelay.satPerKwu,
          )) {
        final committed = state.copyWith(arm: () => null);
        return committed.previews.custom.feeSat == null
            ? _repriced(committed)
            : SpendOptionsNext(committed);
      }
      return SpendOptionsNext(_rolledBack(state, arm));
    case SpendRbfChanged(:final enabled):
      if (enabled == state.replaceByFee) return SpendOptionsNext.stay(state);
      return _reshaped(state.copyWith(replaceByFee: enabled));
    case SpendPayjoinChanged(:final enabled):
      if (enabled == state.payjoin) return SpendOptionsNext.stay(state);
      return SpendOptionsNext(state.copyWith(payjoin: enabled));
    case SpendCoinsRequested():
      return switch (state.coins) {
        SpendCoinsNotLoaded() || SpendCoinsUnavailable() => SpendOptionsNext(
          state.copyWith(coins: const SpendCoinsLoading()),
          [SpendLoadCoins(state.walletId)],
        ),
        SpendCoinsLoading() ||
        SpendCoinsLoaded() => SpendOptionsNext.stay(state),
      };
    case SpendCoinsRead(:final coins):
      if (state.coins is! SpendCoinsLoading) {
        return SpendOptionsNext.stay(state);
      }
      return SpendOptionsNext(
        state.copyWith(
          coins: coins == null
              ? const SpendCoinsUnavailable()
              : SpendCoinsLoaded([
                  for (final coin in coins)
                    if (!coin.frozen) coin,
                ]),
        ),
      );
    case SpendCoinsPicked(:final coins):
      if (_outpoints(coins) == _outpoints(state.selected)) {
        return SpendOptionsNext.stay(state);
      }
      return _reshaped(state.copyWith(selected: [...coins]));
    case SpendPresetsPreviewed() ||
        SpendCustomPreviewed() ||
        SpendFeesLoaded() ||
        SpendFeesFailed() ||
        SpendRetryPressed():
      return SpendOptionsNext.stay(state);
  }
}

SpendOptionsReady _rolledBack(SpendOptionsReady state, SpendCustomArm arm) =>
    state.copyWith(
      selection: arm.selection,
      customFee: () => arm.customFee,
      arm: () => null,
    );
