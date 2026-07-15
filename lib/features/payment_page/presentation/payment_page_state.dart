import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';

/// The default display currency when the live supported-currencies list cannot
/// be fetched and no page currency is already set (§7.12).
const String paymentPageFallbackCurrency = 'CAD';

enum PaymentPageStatus {
  loading,

  /// No Bull nym yet — the DG-6 first step (choose a name) is shown.
  needsNym,

  /// A nym exists but no page row — the create form is shown.
  create,

  /// A live (non-archived) page exists — the edit form is shown.
  edit,

  /// The page row exists but is archived — the archived view is shown.
  archived,

  /// The nym or page probe failed (unreachable) — a loud retry surface.
  loadFailed,
}

class PaymentPageState {
  final PaymentPageStatus status;
  final bool submitting;

  /// The last operation failure, for a one-shot snackbar (rendered via
  /// [PaymentPageException.toTranslated]). Server `reason` never surfaces.
  final PaymentPageException? failure;

  /// A save whose submission may have reached the server (§7.4).
  final bool submissionUncertain;

  final String nym;
  final PaymentPage? page;

  // Editable form fields.
  final String header;
  final String description;
  final String displayCurrency;
  final String website;
  final String twitter;
  final String instagram;

  final List<DisplayCurrency> currencies;

  /// The live currency list could not be fetched — the dropdown degrades to the
  /// current value only, with a retry affordance (§7.12).
  final bool currenciesUnavailable;

  /// The DG-6 choose-a-name input.
  final String nymDraft;

  /// The field flagged by the last submit-time validation, for per-field
  /// highlighting (`errorText`). Cleared when that field is edited or on a new
  /// submit.
  final PaymentPageField? invalidField;

  const PaymentPageState({
    this.status = PaymentPageStatus.loading,
    this.submitting = false,
    this.failure,
    this.submissionUncertain = false,
    this.nym = '',
    this.page,
    this.header = '',
    this.description = '',
    this.displayCurrency = '',
    this.website = '',
    this.twitter = '',
    this.instagram = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.nymDraft = '',
    this.invalidField,
  });

  bool get isLoading => status == PaymentPageStatus.loading;
  bool get isArchived => status == PaymentPageStatus.archived;

  SavePaymentPageCommand get command => SavePaymentPageCommand(
    header: header,
    description: description,
    displayCurrency: displayCurrency,
    website: website,
    twitter: twitter,
    instagram: instagram,
  );

  bool get canSubmit => !submitting && command.isValid;

  String? get publicUrl => page?.publicUrl;

  PaymentPageState copyWith({
    PaymentPageStatus? status,
    bool? submitting,
    PaymentPageException? failure,
    bool? submissionUncertain,
    String? nym,
    PaymentPage? page,
    String? header,
    String? description,
    String? displayCurrency,
    String? website,
    String? twitter,
    String? instagram,
    List<DisplayCurrency>? currencies,
    bool? currenciesUnavailable,
    String? nymDraft,
    PaymentPageField? invalidField,
    bool clearFailure = false,
    bool clearPage = false,
    bool clearInvalidField = false,
  }) {
    return PaymentPageState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : failure ?? this.failure,
      submissionUncertain: submissionUncertain ?? this.submissionUncertain,
      nym: nym ?? this.nym,
      page: clearPage ? null : page ?? this.page,
      header: header ?? this.header,
      description: description ?? this.description,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      website: website ?? this.website,
      twitter: twitter ?? this.twitter,
      instagram: instagram ?? this.instagram,
      currencies: currencies ?? this.currencies,
      currenciesUnavailable:
          currenciesUnavailable ?? this.currenciesUnavailable,
      nymDraft: nymDraft ?? this.nymDraft,
      invalidField: clearInvalidField
          ? null
          : invalidField ?? this.invalidField,
    );
  }
}
