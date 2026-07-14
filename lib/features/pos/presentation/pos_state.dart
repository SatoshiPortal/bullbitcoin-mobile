import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';

/// The default display currency when the live supported-currencies list cannot
/// be fetched and no POS currency is already set (§7.13).
const String posFallbackCurrency = 'CAD';

enum PosStatus {
  loading,

  /// Exact permanent-name capability is absent. Alias and availability
  /// actions stay hidden.
  unsupported,

  /// No permanent nym yet - direct the user to Lightning Address settings.
  needsNym,

  /// A nym exists but no pos row - the create form is shown.
  create,

  /// A live (non-archived) POS exists - the edit form is shown.
  edit,

  /// The pos row exists but is archived - the archived view is shown.
  archived,

  /// The nym or pos probe failed (unreachable) - a loud retry surface.
  loadFailed,
}

class PosState {
  final PosStatus status;
  final bool submitting;

  /// The last operation failure, for a one-shot snackbar (rendered via
  /// [PosException.toTranslated]). Server `reason` never surfaces.
  final PosException? failure;

  /// A save whose submission may have reached the server (§7.7).
  final bool submissionUncertain;

  final String nym;
  final PosTerminal? terminal;
  final String? permanentAlias;
  final String aliasDraft;

  // Editable form fields.
  final String label;
  final String displayCurrency;

  final List<DisplayCurrency> currencies;

  /// The live currency list could not be fetched - the dropdown degrades to the
  /// current value only, with a retry affordance (§7.13).
  final bool currenciesUnavailable;

  /// The field flagged by the last provision-time validation, for per-field
  /// highlighting (`errorText`). Cleared when that field is edited or on a new
  /// provision.
  final PosField? invalidField;

  /// The reserved POS wallet's current behavior (auto-sweep / hide-on-home),
  /// resolved read-only. Null until wallet 103 exists.
  final GetPaidWalletBehavior? walletBehavior;

  /// True while a wallet-behavior toggle write is in flight.
  final bool walletBehaviorSaving;

  const PosState({
    this.status = PosStatus.loading,
    this.submitting = false,
    this.failure,
    this.submissionUncertain = false,
    this.nym = '',
    this.terminal,
    this.permanentAlias,
    this.aliasDraft = '',
    this.label = '',
    this.displayCurrency = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.invalidField,
    this.walletBehavior,
    this.walletBehaviorSaving = false,
  });

  bool get isLoading => status == PosStatus.loading;
  bool get isArchived => status == PosStatus.archived;
  bool get isOnline => status == PosStatus.edit;

  PosProvisionCommand get command => PosProvisionCommand(
    label: label,
    displayCurrency: displayCurrency,
    aliasClaim: permanentAlias == null && aliasDraft.trim().isNotEmpty
        ? normalizePosAlias(aliasDraft)
        : null,
  );

  bool get canSubmit => !submitting && command.isValid;

  String? get terminalUrl => terminal?.terminalUrl;

  PosState copyWith({
    PosStatus? status,
    bool? submitting,
    PosException? failure,
    bool? submissionUncertain,
    String? nym,
    PosTerminal? terminal,
    String? permanentAlias,
    String? aliasDraft,
    String? label,
    String? displayCurrency,
    List<DisplayCurrency>? currencies,
    bool? currenciesUnavailable,
    PosField? invalidField,
    GetPaidWalletBehavior? walletBehavior,
    bool? walletBehaviorSaving,
    bool clearFailure = false,
    bool clearTerminal = false,
    bool clearPermanentAlias = false,
    bool clearInvalidField = false,
    bool clearWalletBehavior = false,
  }) {
    return PosState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : failure ?? this.failure,
      submissionUncertain: submissionUncertain ?? this.submissionUncertain,
      nym: nym ?? this.nym,
      terminal: clearTerminal ? null : terminal ?? this.terminal,
      permanentAlias: clearPermanentAlias
          ? null
          : permanentAlias ?? this.permanentAlias,
      aliasDraft: aliasDraft ?? this.aliasDraft,
      label: label ?? this.label,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      currencies: currencies ?? this.currencies,
      currenciesUnavailable:
          currenciesUnavailable ?? this.currenciesUnavailable,
      invalidField: clearInvalidField
          ? null
          : invalidField ?? this.invalidField,
      walletBehavior: clearWalletBehavior
          ? null
          : walletBehavior ?? this.walletBehavior,
      walletBehaviorSaving: walletBehaviorSaving ?? this.walletBehaviorSaving,
    );
  }
}
