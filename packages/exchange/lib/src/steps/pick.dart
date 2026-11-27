import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import 'step_next.dart';
import 'payin_wallet_admission.dart';

/// Picking where bitcoin comes from or goes to (composition §4.6):
/// `PayinSourcePick` and `DestinationPick` are this machine with their own
/// options and output ([PayinSource], [Destination]). Lookups (a receive
/// address of an app wallet) and validations (a typed address) are effects;
/// their answers are keyed by the option or the text they were asked for.
@immutable
sealed class PickState<O, V> {
  const PickState();

  List<O> get options;
}

final class PickChoosing<O, V> extends PickState<O, V> {
  @override
  final List<O> options;

  /// Why the last pick did not work; cleared by the next one.
  final PickProblem<O>? problem;

  const PickChoosing(this.options, {this.problem});

  @override
  bool operator ==(Object other) =>
      other is PickChoosing &&
      _sameList(other.options, options) &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(PickChoosing, Object.hashAll(options), problem);

  @override
  String toString() => 'PickChoosing($options, $problem)';
}

/// The option needs a lookup before it is a value (an app wallet's receive
/// address).
final class PickResolving<O, V> extends PickState<O, V> {
  @override
  final List<O> options;
  final O option;

  const PickResolving(this.options, this.option);

  @override
  bool operator ==(Object other) =>
      other is PickResolving &&
      _sameList(other.options, options) &&
      other.option == option;

  @override
  int get hashCode =>
      Object.hash(PickResolving, Object.hashAll(options), option);

  @override
  String toString() => 'PickResolving($option)';
}

/// A typed address is being validated by its rail.
final class PickValidating<O, V> extends PickState<O, V> {
  @override
  final List<O> options;
  final String text;

  const PickValidating(this.options, this.text);

  @override
  bool operator ==(Object other) =>
      other is PickValidating &&
      _sameList(other.options, options) &&
      other.text == text;

  @override
  int get hashCode =>
      Object.hash(PickValidating, Object.hashAll(options), text);

  @override
  String toString() => 'PickValidating("$text")';
}

/// The step's output: [value].
final class PickChosen<O, V> extends PickState<O, V> {
  @override
  final List<O> options;
  final V value;

  const PickChosen(this.options, this.value);

  @override
  bool operator ==(Object other) =>
      other is PickChosen &&
      _sameList(other.options, options) &&
      other.value == value;

  @override
  int get hashCode => Object.hash(PickChosen, Object.hashAll(options), value);

  @override
  String toString() => 'PickChosen($value)';
}

bool _sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

@immutable
sealed class PickProblem<O> {
  const PickProblem();
}

final class PickResolveFailed<O> extends PickProblem<O> {
  final O option;
  final Failure failure;

  const PickResolveFailed(this.option, this.failure);

  @override
  bool operator ==(Object other) =>
      other is PickResolveFailed &&
      other.option == option &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(PickResolveFailed, option, failure);
}

final class PickTextInvalid<O> extends PickProblem<O> {
  final String text;
  final Failure failure;

  const PickTextInvalid(this.text, this.failure);

  @override
  bool operator ==(Object other) =>
      other is PickTextInvalid &&
      other.text == text &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(PickTextInvalid, text, failure);
}

@immutable
sealed class PickEvent<O, V> {
  const PickEvent();
}

final class PickChose<O, V> extends PickEvent<O, V> {
  final O option;

  const PickChose(this.option);
}

final class PickTyped<O, V> extends PickEvent<O, V> {
  final String text;

  const PickTyped(this.text);
}

/// The validation of [text] answered [result].
final class PickValidated<O, V> extends PickEvent<O, V> {
  final String text;
  final Result<V, Failure> result;

  const PickValidated(this.text, this.result);
}

/// The lookup of [option] answered [result].
final class PickResolved<O, V> extends PickEvent<O, V> {
  final O option;
  final Result<V, Failure> result;

  const PickResolved(this.option, this.result);
}

/// Back from the next step, or away from a lookup or validation.
final class PickBackPressed<O, V> extends PickEvent<O, V> {
  const PickBackPressed();
}

@immutable
sealed class PickEffect<O> {
  const PickEffect();
}

/// Look [option] up; answer [PickResolved] for it.
final class PickResolve<O> extends PickEffect<O> {
  final O option;

  const PickResolve(this.option);

  @override
  bool operator ==(Object other) =>
      other is PickResolve && other.option == option;

  @override
  int get hashCode => Object.hash(PickResolve, option);

  @override
  String toString() => 'PickResolve($option)';
}

/// Validate [text] with the rail it parses as (C4's `BitcoinRail`); answer
/// [PickValidated] for it.
final class PickValidate<O> extends PickEffect<O> {
  final String text;

  const PickValidate(this.text);

  @override
  bool operator ==(Object other) => other is PickValidate && other.text == text;

  @override
  int get hashCode => Object.hash(PickValidate, text);

  @override
  String toString() => 'PickValidate("$text")';
}

/// Whether an option is a value at once or needs a lookup.
@immutable
sealed class PickResolution<V> {
  const PickResolution();
}

final class PickImmediate<V> extends PickResolution<V> {
  final V value;

  const PickImmediate(this.value);
}

final class PickNeedsLookup<V> extends PickResolution<V> {
  const PickNeedsLookup();
}

/// A flow's pick rules: how each option resolves, and whether a typed
/// address is accepted.
@immutable
final class PickPolicy<O, V> {
  final PickResolution<V> Function(O option) resolutionOf;
  final bool acceptsTyped;

  const PickPolicy({required this.resolutionOf, required this.acceptsTyped});
}

typedef PickNext<O, V> = StepNext<PickState<O, V>, PickEffect<O>>;

PickNext<O, V> pickStart<O, V>(List<O> options) =>
    StepNext(PickChoosing<O, V>(List.unmodifiable(options)));

PickNext<O, V> _chose<O, V>(
  PickPolicy<O, V> policy,
  PickState<O, V> state,
  O option,
) {
  final options = state.options;
  if (!options.contains(option)) return StepNext.stay(state);
  return switch (policy.resolutionOf(option)) {
    PickImmediate(:final value) => StepNext(PickChosen<O, V>(options, value)),
    PickNeedsLookup() => StepNext(PickResolving<O, V>(options, option), [
      PickResolve(option),
    ]),
  };
}

PickNext<O, V> _typed<O, V>(
  PickPolicy<O, V> policy,
  PickState<O, V> state,
  String text,
) {
  if (!policy.acceptsTyped) return StepNext.stay(state);
  final trimmed = text.trim();
  if (trimmed.isEmpty) return StepNext(PickChoosing<O, V>(state.options));
  return StepNext(PickValidating<O, V>(state.options, trimmed), [
    PickValidate(trimmed),
  ]);
}

PickNext<O, V> transitionPick<O, V>(
  PickPolicy<O, V> policy,
  PickState<O, V> state,
  PickEvent<O, V> event,
) => switch ((state, event)) {
  (PickChoosing(), PickChose(:final option)) => _chose(policy, state, option),
  (PickChoosing(:final problem), PickTyped(:final text))
      when problem == null && text.trim().isEmpty =>
    StepNext.stay(state),
  (PickChoosing(), PickTyped(:final text)) => _typed(policy, state, text),
  (PickChoosing(), PickValidated() || PickResolved() || PickBackPressed()) =>
    StepNext.stay(state),

  (PickResolving(:final option), PickChose(option: final chosen))
      when chosen == option =>
    StepNext.stay(state),
  (PickResolving(), PickChose(:final option)) => _chose(policy, state, option),
  (PickResolving(), PickTyped(:final text)) when text.trim().isEmpty =>
    StepNext.stay(state),
  (PickResolving(), PickTyped(:final text)) => _typed(policy, state, text),
  (
    PickResolving(:final options, :final option),
    PickResolved(option: final answered, :final result),
  )
      when answered == option =>
    switch (result) {
      Ok(:final value) => StepNext(PickChosen<O, V>(options, value)),
      Err(:final failure) => StepNext(
        PickChoosing<O, V>(
          options,
          problem: PickResolveFailed(option, failure),
        ),
      ),
    },
  (PickResolving(), PickResolved() || PickValidated()) => StepNext.stay(state),
  (PickResolving(:final options), PickBackPressed()) => StepNext(
    PickChoosing<O, V>(options),
  ),

  (PickValidating(), PickChose(:final option)) => _chose(policy, state, option),
  (PickValidating(text: final current), PickTyped(:final text))
      when text.trim() == current =>
    StepNext.stay(state),
  (PickValidating(), PickTyped(:final text)) => _typed(policy, state, text),
  (
    PickValidating(:final options, text: final current),
    PickValidated(:final text, :final result),
  )
      when text == current =>
    switch (result) {
      Ok(:final value) => StepNext(PickChosen<O, V>(options, value)),
      Err(:final failure) => StepNext(
        PickChoosing<O, V>(options, problem: PickTextInvalid(current, failure)),
      ),
    },
  (PickValidating(), PickValidated() || PickResolved()) => StepNext.stay(state),
  (PickValidating(:final options), PickBackPressed()) => StepNext(
    PickChoosing<O, V>(options),
  ),

  (PickChosen(:final options), PickBackPressed()) => StepNext(
    PickChoosing<O, V>(options),
  ),
  (
    PickChosen(),
    PickChose() || PickTyped() || PickValidated() || PickResolved(),
  ) =>
    StepNext.stay(state),
};

/// Where a sell or pay payin comes from.
@immutable
sealed class PayinOption {
  const PayinOption();
}

final class PayinOptionAppWallet extends PayinOption {
  final String walletId;
  final BtcNetwork rail;

  const PayinOptionAppWallet(this.walletId, this.rail);

  @override
  bool operator ==(Object other) =>
      other is PayinOptionAppWallet &&
      other.walletId == walletId &&
      other.rail == rail;

  @override
  int get hashCode => Object.hash(PayinOptionAppWallet, walletId, rail);
}

final class PayinOptionExternal extends PayinOption {
  final BtcNetwork rail;

  const PayinOptionExternal(this.rail);

  @override
  bool operator ==(Object other) =>
      other is PayinOptionExternal && other.rail == rail;

  @override
  int get hashCode => Object.hash(PayinOptionExternal, rail);
}

/// The output of `PayinSourcePick`.
@immutable
sealed class PayinSource {
  const PayinSource();

  BtcNetwork get rail;
}

final class PayinFromAppWallet extends PayinSource {
  final String walletId;
  @override
  final BtcNetwork rail;

  /// How the review names the wallet ("Pay from wallet"): its label, or for
  /// the app's setup wallets [isDefault].
  final String? label;
  final bool isDefault;
  final PayinWalletWitness? witness;
  final PayinWalletAttempt? attempt;

  const PayinFromAppWallet(
    this.walletId,
    this.rail, {
    this.label,
    this.isDefault = false,
  }) : witness = null,
       attempt = null;

  PayinFromAppWallet.witnessed(
    PayinWalletWitness witness, {
    this.label,
    this.isDefault = false,
  }) : witness = witness,
       attempt = null,
       walletId = witness.walletId,
       rail = witness.network is LiquidNetwork
           ? BtcNetwork.liquid
           : BtcNetwork.bitcoin;

  PayinFromAppWallet._bound(PayinFromAppWallet source, this.attempt)
    : walletId = source.walletId,
      rail = source.rail,
      label = source.label,
      isDefault = source.isDefault,
      witness = source.witness;

  PayinFromAppWallet? bindAttempt() {
    final choice = witness;
    if (choice == null) return this;
    return attempt == null && choice.isCurrent
        ? PayinFromAppWallet._bound(this, PayinWalletAttempt(choice))
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is PayinFromAppWallet &&
      other.walletId == walletId &&
      other.rail == rail &&
      other.label == label &&
      other.isDefault == isDefault &&
      identical(other.witness, witness) &&
      identical(other.attempt, attempt);

  @override
  int get hashCode => Object.hash(
    PayinFromAppWallet,
    walletId,
    rail,
    label,
    isDefault,
    witness,
    attempt,
  );
}

final class PayinFromExternal extends PayinSource {
  @override
  final BtcNetwork rail;

  const PayinFromExternal(this.rail);

  @override
  bool operator ==(Object other) =>
      other is PayinFromExternal && other.rail == rail;

  @override
  int get hashCode => Object.hash(PayinFromExternal, rail);
}

PickResolution<PayinSource> payinResolution(PayinOption option) =>
    switch (option) {
      PayinOptionAppWallet(:final walletId, :final rail) => PickImmediate(
        PayinFromAppWallet(walletId, rail),
      ),
      PayinOptionExternal(:final rail) => PickImmediate(
        PayinFromExternal(rail),
      ),
    };

/// `PayinSourcePick`: every option is a value at once; nothing is typed.
const payinSourcePolicy = PickPolicy<PayinOption, PayinSource>(
  resolutionOf: payinResolution,
  acceptsTyped: false,
);

/// Where an order's bitcoin goes.
@immutable
sealed class DestinationOption {
  const DestinationOption();
}

/// An app wallet; its receive address is looked up when picked.
final class DestinationOptionAppWallet extends DestinationOption {
  final String walletId;
  final BtcNetwork rail;

  const DestinationOptionAppWallet(this.walletId, this.rail);

  @override
  bool operator ==(Object other) =>
      other is DestinationOptionAppWallet &&
      other.walletId == walletId &&
      other.rail == rail;

  @override
  int get hashCode => Object.hash(DestinationOptionAppWallet, walletId, rail);
}

/// An exchange default wallet (an address saved on the account).
final class DestinationOptionDefaultWallet extends DestinationOption {
  final BtcNetwork rail;
  final String address;

  const DestinationOptionDefaultWallet(this.rail, this.address);

  @override
  bool operator ==(Object other) =>
      other is DestinationOptionDefaultWallet &&
      other.rail == rail &&
      other.address == address;

  @override
  int get hashCode =>
      Object.hash(DestinationOptionDefaultWallet, rail, address);
}

/// The output of `DestinationPick`.
@immutable
sealed class Destination {
  const Destination();

  BtcNetwork get rail;
  String get address;
}

final class DestinationAppWallet extends Destination {
  final String walletId;
  @override
  final BtcNetwork rail;
  @override
  final String address;

  const DestinationAppWallet(this.walletId, this.rail, this.address);

  @override
  bool operator ==(Object other) =>
      other is DestinationAppWallet &&
      other.walletId == walletId &&
      other.rail == rail &&
      other.address == address;

  @override
  int get hashCode =>
      Object.hash(DestinationAppWallet, walletId, rail, address);
}

final class DestinationDefaultWallet extends Destination {
  @override
  final BtcNetwork rail;
  @override
  final String address;

  const DestinationDefaultWallet(this.rail, this.address);

  @override
  bool operator ==(Object other) =>
      other is DestinationDefaultWallet &&
      other.rail == rail &&
      other.address == address;

  @override
  int get hashCode => Object.hash(DestinationDefaultWallet, rail, address);
}

/// A typed address (external bitcoin address, Lightning address), validated
/// by its rail.
final class DestinationAddress extends Destination {
  @override
  final BtcNetwork rail;
  @override
  final String address;

  const DestinationAddress(this.rail, this.address);

  @override
  bool operator ==(Object other) =>
      other is DestinationAddress &&
      other.rail == rail &&
      other.address == address;

  @override
  int get hashCode => Object.hash(DestinationAddress, rail, address);
}

PickResolution<Destination> destinationResolution(DestinationOption option) =>
    switch (option) {
      DestinationOptionAppWallet() => const PickNeedsLookup(),
      DestinationOptionDefaultWallet(:final rail, :final address) =>
        PickImmediate(DestinationDefaultWallet(rail, address)),
    };

/// `DestinationPick`; [acceptsTyped] when the flow offers a typed address.
PickPolicy<DestinationOption, Destination> destinationPolicy({
  required bool acceptsTyped,
}) =>
    PickPolicy(resolutionOf: destinationResolution, acceptsTyped: acceptsTyped);
