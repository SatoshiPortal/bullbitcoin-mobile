import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';

/// The default display currency when the live supported-currencies list cannot
/// be fetched and no page currency is already set (§7.12).
const String paymentPageFallbackCurrency = 'CAD';

enum PaymentPageStatus {
  loading,

  /// The server does not advertise the exact permanent-name contract. No
  /// alias or availability action is exposed.
  unsupported,

  /// No permanent nym yet — direct the user to Lightning Address settings.
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

  /// Owner-level alias reconstructed from Bullnym. Never persisted locally.
  final String? permanentAlias;

  /// Optional first alias claim. Once [permanentAlias] exists this is ignored
  /// and the UI renders the server-owned alias read-only.
  final String aliasDraft;

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

  /// The field flagged by the last submit-time validation, for per-field
  /// highlighting (`errorText`). Cleared when that field is edited or on a new
  /// submit.
  final PaymentPageField? invalidField;

  /// The reserved Payment Page wallet's current behavior (auto-sweep /
  /// hide-on-home), resolved read-only. Null until wallet 102 exists.
  final GetPaidWalletBehavior? walletBehavior;

  /// True while a wallet-behavior toggle write is in flight.
  final bool walletBehaviorSaving;

  const PaymentPageState({
    this.status = PaymentPageStatus.loading,
    this.submitting = false,
    this.failure,
    this.submissionUncertain = false,
    this.nym = '',
    this.page,
    this.permanentAlias,
    this.aliasDraft = '',
    this.header = '',
    this.description = '',
    this.displayCurrency = '',
    this.website = '',
    this.twitter = '',
    this.instagram = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.invalidField,
    this.walletBehavior,
    this.walletBehaviorSaving = false,
  });

  bool get isLoading => status == PaymentPageStatus.loading;
  bool get isArchived => status == PaymentPageStatus.archived;
  bool get isOnline => status == PaymentPageStatus.edit;

  SavePaymentPageCommand get command => SavePaymentPageCommand(
    header: header,
    description: description,
    displayCurrency: displayCurrency,
    website: website,
    twitter: twitter,
    instagram: instagram,
    aliasClaim: permanentAlias == null && aliasDraft.trim().isNotEmpty
        ? normalizePaymentPageAlias(aliasDraft)
        : null,
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
    String? permanentAlias,
    String? aliasDraft,
    String? header,
    String? description,
    String? displayCurrency,
    String? website,
    String? twitter,
    String? instagram,
    List<DisplayCurrency>? currencies,
    bool? currenciesUnavailable,
    PaymentPageField? invalidField,
    GetPaidWalletBehavior? walletBehavior,
    bool? walletBehaviorSaving,
    bool clearFailure = false,
    bool clearPage = false,
    bool clearPermanentAlias = false,
    bool clearInvalidField = false,
    bool clearWalletBehavior = false,
  }) {
    return PaymentPageState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : failure ?? this.failure,
      submissionUncertain: submissionUncertain ?? this.submissionUncertain,
      nym: nym ?? this.nym,
      page: clearPage ? null : page ?? this.page,
      permanentAlias: clearPermanentAlias
          ? null
          : permanentAlias ?? this.permanentAlias,
      aliasDraft: aliasDraft ?? this.aliasDraft,
      header: header ?? this.header,
      description: description ?? this.description,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      website: website ?? this.website,
      twitter: twitter ?? this.twitter,
      instagram: instagram ?? this.instagram,
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
