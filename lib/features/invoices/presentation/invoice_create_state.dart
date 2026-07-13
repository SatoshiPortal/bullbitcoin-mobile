import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';

enum InvoiceAmountMode { sats, fiat }

/// The create-invoice fields that submit-time validation can flag, for
/// per-field highlighting (`errorText`).
enum InvoiceCreateField { amount, currency }

/// The create-invoice form + submission state. All form fields are local; the
/// wallet lookup, address generation, signing and labels live in the usecase,
/// never here. On success [result] carries the share URL.
class InvoiceCreateState {
  final bool submitting;
  final CreateInvoiceResult? result;
  final InvoicesFailure? failure;

  // Amount (one-of).
  final InvoiceAmountMode amountMode;
  final String amountInput;
  final String fiatCurrency;

  // Details.
  final String publicDescription;
  final String recipientName;
  final String invoiceNumber;

  // Rails.
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;

  // Expiry: a 1–7 day picker (§3.7).
  final int expiryDays;

  final String privateMemo;

  // Supported fiat currencies (live), with a graceful-degrade flag.
  final List<BullnymSupportedCurrency> currencies;
  final bool currenciesUnavailable;

  /// The field flagged by the last submit-time validation, for per-field
  /// highlighting (`errorText`). Cleared when that field is edited or on a new
  /// submit.
  final InvoiceCreateField? invalidField;

  const InvoiceCreateState({
    this.submitting = false,
    this.result,
    this.failure,
    this.amountMode = InvoiceAmountMode.sats,
    this.amountInput = '',
    this.fiatCurrency = '',
    this.publicDescription = '',
    this.recipientName = '',
    this.invoiceNumber = '',
    this.acceptBtc = false,
    this.acceptLn = true,
    this.acceptLiquid = true,
    this.expiryDays = 1,
    this.privateMemo = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.invalidField,
  });

  bool get isSubmitted => result != null;
  bool get hasAnyRail => acceptBtc || acceptLn || acceptLiquid;

  InvoiceCreateState copyWith({
    bool? submitting,
    CreateInvoiceResult? result,
    InvoicesFailure? failure,
    InvoiceAmountMode? amountMode,
    String? amountInput,
    String? fiatCurrency,
    String? publicDescription,
    String? recipientName,
    String? invoiceNumber,
    bool? acceptBtc,
    bool? acceptLn,
    bool? acceptLiquid,
    int? expiryDays,
    String? privateMemo,
    List<BullnymSupportedCurrency>? currencies,
    bool? currenciesUnavailable,
    InvoiceCreateField? invalidField,
    bool clearFailure = false,
    bool clearInvalidField = false,
  }) {
    return InvoiceCreateState(
      submitting: submitting ?? this.submitting,
      result: result ?? this.result,
      failure: clearFailure ? null : failure ?? this.failure,
      amountMode: amountMode ?? this.amountMode,
      amountInput: amountInput ?? this.amountInput,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      publicDescription: publicDescription ?? this.publicDescription,
      recipientName: recipientName ?? this.recipientName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      acceptBtc: acceptBtc ?? this.acceptBtc,
      acceptLn: acceptLn ?? this.acceptLn,
      acceptLiquid: acceptLiquid ?? this.acceptLiquid,
      expiryDays: expiryDays ?? this.expiryDays,
      privateMemo: privateMemo ?? this.privateMemo,
      currencies: currencies ?? this.currencies,
      currenciesUnavailable:
          currenciesUnavailable ?? this.currenciesUnavailable,
      invalidField: clearInvalidField
          ? null
          : invalidField ?? this.invalidField,
    );
  }
}
