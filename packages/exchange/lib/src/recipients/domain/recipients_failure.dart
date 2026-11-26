part of '../../domain/exchange_failure.dart';

sealed class RecipientsFailure extends ExchangeFailure {
  const RecipientsFailure([super.logMessage]);
}

/// No usable exchange credential is available for this authenticated action.
final class RecipientsNotAuthenticatedFailure extends RecipientsFailure {
  const RecipientsNotAuthenticatedFailure();
}

/// The recipient list could not be loaded.
final class RecipientsLoadFailure extends RecipientsFailure {
  const RecipientsLoadFailure([super.logMessage]);
}

/// The recipient could not be saved.
final class RecipientsSaveFailure extends RecipientsFailure {
  const RecipientsSaveFailure([super.logMessage]);
}

/// A field of a recipient form, by its name in the API request.
enum RecipientField {
  email('email'),
  name('name'),
  firstname('firstname'),
  lastname('lastname'),
  corporateName('corporateName'),
  securityQuestion('securityQuestion'),
  securityAnswer('securityAnswer'),
  payeeName('payeeName'),
  payeeCode('payeeCode'),
  payeeAccountNumber('payeeAccountNumber'),
  institutionNumber('institutionNumber'),
  transitNumber('transitNumber'),
  accountNumber('accountNumber'),
  iban('iban'),
  clabe('clabe'),
  institutionCode('institutionCode'),
  phone('phone'),
  debitcard('debitcard'),
  phoneNumber('phoneNumber'),
  claveUniform('claveUniform'),
  bankCode('bankCode'),
  accountType('accountType'),
  bankAccount('bankAccount'),
  documentId('documentId'),
  documentType('documentType'),
  label('label');

  final String wireName;

  const RecipientField(this.wireName);

  static RecipientField? fromWire(String name) {
    for (final field in values) {
      if (field.wireName == name) return field;
    }
    return null;
  }
}

/// What the exchange found wrong with a refused field.
enum RecipientFieldProblem {
  /// `ERR_VALIDATION_REQUIRED` and `ERR_VALIDATION_REQUIRED_OTHER`.
  missing,

  /// Any other validation code: a wrong format, value or length.
  invalid;

  static RecipientFieldProblem fromCode(String code) => switch (code) {
    'ERR_VALIDATION_REQUIRED' ||
    'ERR_VALIDATION_REQUIRED_OTHER' => RecipientFieldProblem.missing,
    _ => RecipientFieldProblem.invalid,
  };
}

/// The exchange refused the recipient for the fields it named.
///
/// [fields] holds the refused fields the forms know; [otherFields] the
/// names of the others (a field path the app doesn't send by that name),
/// so a form can still name them. Never a value.
final class RecipientsInvalidFieldsFailure extends RecipientsFailure {
  final Map<RecipientField, RecipientFieldProblem> fields;
  final List<String> otherFields;

  RecipientsInvalidFieldsFailure._(this.fields, this.otherFields)
    : super(
        'refused fields: ${[...fields.keys.map((f) => f.wireName), ...otherFields]}',
      );

  /// The failure for the server's [fieldErrors] (field path to
  /// `ERR_VALIDATION_` code), or null when it named none.
  static RecipientsInvalidFieldsFailure? fromFieldErrors(
    Map<String, String> fieldErrors,
  ) {
    if (fieldErrors.isEmpty) return null;
    final fields = <RecipientField, RecipientFieldProblem>{};
    final others = <String>[];
    for (final MapEntry(key: name, value: code) in fieldErrors.entries) {
      switch (RecipientField.fromWire(name)) {
        case final field?:
          fields[field] = RecipientFieldProblem.fromCode(code);
        case null:
          others.add(name);
      }
    }
    return RecipientsInvalidFieldsFailure._(
      Map.unmodifiable(fields),
      List.unmodifiable(others),
    );
  }
}

/// The save request may have reached the exchange without a readable answer,
/// so the recipient may exist. The form does not offer the save again: the
/// recipient list says whether it was saved.
final class RecipientsSaveOutcomeUnknownFailure extends RecipientsFailure {
  const RecipientsSaveOutcomeUnknownFailure([super.logMessage]);
}

/// The SINPE phone number could not be looked up. Distinct from a save
/// failure: the user is mid-form and the actionable advice is to check the
/// number, not to retry the whole thing.
final class RecipientsSinpeLookupFailure extends RecipientsFailure {
  const RecipientsSinpeLookupFailure([super.logMessage]);
}

/// The CAD biller directory could not be searched.
final class RecipientsCadBillerSearchFailure extends RecipientsFailure {
  const RecipientsCadBillerSearchFailure([super.logMessage]);
}

/// The request never reached the API, or timed out. Worth its own variant
/// because it is the one case with advice the user can act on.
final class RecipientsNetworkFailure extends RecipientsFailure {
  const RecipientsNetworkFailure([super.logMessage]);
}

/// The caller-supplied selection hook failed. The cause belongs to whichever
/// feature opened the recipients screen (see `RecipientsBloc`'s
/// `onRecipientSelectedHook`), so this feature reports it generically rather
/// than pretending to know what went wrong.
final class RecipientsSelectionFailure extends RecipientsFailure {
  const RecipientsSelectionFailure([super.logMessage]);
}

/// The recipient was saved, but the hook that should have carried the user
/// onward failed.
///
/// Separate from [RecipientsSelectionFailure] because of what the user does
/// next: this one appears under the Continue button of a form that has
/// already succeeded, so a message implying the save failed invites a retry
/// — and a duplicate recipient.
final class RecipientsSavedButNotSelectedFailure extends RecipientsFailure {
  const RecipientsSavedButNotSelectedFailure([super.logMessage]);
}

/// The Interac security question/answer pair failed its invariants (see
/// `InteracSecurityDetails.create`).
final class RecipientsInvalidSecurityDetailsFailure extends RecipientsFailure {
  const RecipientsInvalidSecurityDetailsFailure([super.logMessage]);
}

/// The user's account cannot get a virtual IBAN: their KYC is insufficient
/// or Confidential SEPA is not offered to them.
final class RecipientsVirtualIbanNotAvailableFailure extends RecipientsFailure {
  const RecipientsVirtualIbanNotAvailableFailure([super.logMessage]);
}

/// A virtual IBAN is only issued to residents of the European Union.
final class RecipientsEuResidencyRequiredFailure extends RecipientsFailure {
  const RecipientsEuResidencyRequiredFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class RecipientsUnexpectedFailure extends RecipientsFailure {
  const RecipientsUnexpectedFailure([super.logMessage]);
}

final class RecipientsUnsupportedNetworkFailure extends RecipientsFailure {
  const RecipientsUnsupportedNetworkFailure();
}
