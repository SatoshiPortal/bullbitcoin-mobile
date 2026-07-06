import 'package:bb_mobile/features/pos/public/pos_facade.dart';

/// The default display currency when the live supported-currencies list cannot
/// be fetched and no POS currency is already set (§7.13).
const String posFallbackCurrency = 'CAD';

enum PosStatus {
  loading,

  /// No Bull nym yet - the DG-P6 first step (choose a name) is shown.
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

  // Editable form fields.
  final String label;
  final String displayCurrency;

  final List<DisplayCurrency> currencies;

  /// The live currency list could not be fetched - the dropdown degrades to the
  /// current value only, with a retry affordance (§7.13).
  final bool currenciesUnavailable;

  /// The DG-P6 choose-a-name input.
  final String nymDraft;

  const PosState({
    this.status = PosStatus.loading,
    this.submitting = false,
    this.failure,
    this.submissionUncertain = false,
    this.nym = '',
    this.terminal,
    this.label = '',
    this.displayCurrency = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.nymDraft = '',
  });

  bool get isLoading => status == PosStatus.loading;
  bool get isArchived => status == PosStatus.archived;

  PosProvisionCommand get command =>
      PosProvisionCommand(label: label, displayCurrency: displayCurrency);

  bool get canSubmit => !submitting && command.isValid;

  String? get terminalUrl => terminal?.terminalUrl;

  PosState copyWith({
    PosStatus? status,
    bool? submitting,
    PosException? failure,
    bool? submissionUncertain,
    String? nym,
    PosTerminal? terminal,
    String? label,
    String? displayCurrency,
    List<DisplayCurrency>? currencies,
    bool? currenciesUnavailable,
    String? nymDraft,
    bool clearFailure = false,
    bool clearTerminal = false,
  }) {
    return PosState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : failure ?? this.failure,
      submissionUncertain: submissionUncertain ?? this.submissionUncertain,
      nym: nym ?? this.nym,
      terminal: clearTerminal ? null : terminal ?? this.terminal,
      label: label ?? this.label,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      currencies: currencies ?? this.currencies,
      currenciesUnavailable:
          currenciesUnavailable ?? this.currenciesUnavailable,
      nymDraft: nymDraft ?? this.nymDraft,
    );
  }
}
