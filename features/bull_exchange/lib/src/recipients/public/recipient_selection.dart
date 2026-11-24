import 'package:exchange/exchange.dart';

/// Recipient data published for cross-feature selection flows.
final class RecipientSelection {
  const RecipientSelection({
    required this.id,
    required this.type,
    this.displayName,
    this.email,
    this.securityQuestion,
    this.securityAnswer,
    this.payeeName,
    this.payeeCode,
    this.payeeAccountNumber,
    this.institutionNumber,
    this.transitNumber,
    this.accountNumber,
    this.iban,
    this.clabe,
    this.phoneNumber,
    this.debitcard,
    this.bankAccount,
    this.isVirtualPayeeActive = false,
    this.accountRows = const [],
  });

  /// [recipient] as flows receive it: its rail's name and account rows, and
  /// the fields the flows still read until they take a ready recipient.
  factory RecipientSelection.of(Recipient recipient) {
    final onRail = recipient.onRail;
    final base = RecipientSelection(
      id: recipient.recipientId,
      type: onRail.rail.type,
      displayName: onRail.displayName,
      accountRows: onRail.accountRows,
    );
    return switch (recipient.details) {
      final InteracEmailCadDetails d => base._with(
        email: d.email,
        securityQuestion: d.securityQuestion,
        securityAnswer: d.securityAnswer,
      ),
      final BillPaymentCadDetails d => base._with(
        payeeName: d.payeeName,
        payeeCode: d.payeeCode,
        payeeAccountNumber: d.payeeAccountNumber,
      ),
      final BankTransferCadDetails d => base._with(
        institutionNumber: d.institutionNumber,
        transitNumber: d.transitNumber,
        accountNumber: d.accountNumber,
      ),
      final SepaEurDetails d => base._with(
        iban: d.iban,
        isVirtualPayeeActive: d.isVirtualPayeeActive,
      ),
      final SpeiClabeMxnDetails d => base._with(clabe: d.clabe),
      final SpeiSmsMxnDetails d => base._with(phoneNumber: d.phone),
      final SpeiCardMxnDetails d => base._with(debitcard: d.debitcard),
      final SinpeIbanUsdDetails d => base._with(iban: d.iban),
      final SinpeIbanCrcDetails d => base._with(iban: d.iban),
      final SinpeMovilCrcDetails d => base._with(phoneNumber: d.phoneNumber),
      final BankAccountArgentinaDetails d => base._with(
        bankAccount: d.claveUniform,
      ),
      final PseColombiaDetails d => base._with(bankAccount: d.bankAccount),
      final NequiColombiaDetails d => base._with(phoneNumber: d.phoneNumber),
    };
  }

  RecipientSelection _with({
    String? email,
    String? securityQuestion,
    String? securityAnswer,
    String? payeeName,
    String? payeeCode,
    String? payeeAccountNumber,
    String? institutionNumber,
    String? transitNumber,
    String? accountNumber,
    String? iban,
    String? clabe,
    String? phoneNumber,
    String? debitcard,
    String? bankAccount,
    bool isVirtualPayeeActive = false,
  }) => RecipientSelection(
    id: id,
    type: type,
    displayName: displayName,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    iban: iban,
    clabe: clabe,
    phoneNumber: phoneNumber,
    debitcard: debitcard,
    bankAccount: bankAccount,
    isVirtualPayeeActive: isVirtualPayeeActive,
    accountRows: accountRows,
  );

  final String id;
  final RecipientType type;
  final String? displayName;
  final String? email;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? payeeName;
  final String? payeeCode;
  final String? payeeAccountNumber;
  final String? institutionNumber;
  final String? transitNumber;
  final String? accountNumber;
  final String? iban;
  final String? clabe;
  final String? phoneNumber;
  final String? debitcard;
  final String? bankAccount;
  final bool isVirtualPayeeActive;

  /// The account values its rail shows, in order.
  final List<AccountRow> accountRows;

  PayoutRail get rail => PayoutRails.of(type);

  bool get requiresInteracSecurityDetails =>
      type == RecipientType.interacEmailCad;

  /// A Confidential SEPA payout needs the recipient's virtual payee to be
  /// active.
  bool get requiresVirtualPayeeActivation =>
      type == RecipientType.confidentialSepaEur && !isVirtualPayeeActive;

  /// The same account, paid through regular SEPA.
  RecipientSelection asRegularSepa() => RecipientSelection(
    id: id,
    type: type == RecipientType.confidentialSepaEur
        ? RecipientType.sepaEur
        : type,
    displayName: displayName,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    iban: iban,
    clabe: clabe,
    phoneNumber: phoneNumber,
    debitcard: debitcard,
    bankAccount: bankAccount,
    accountRows: accountRows,
  );

  RecipientSelection asVirtualPayeeActive() => RecipientSelection(
    id: id,
    type: type,
    displayName: displayName,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    payeeName: payeeName,
    payeeCode: payeeCode,
    payeeAccountNumber: payeeAccountNumber,
    institutionNumber: institutionNumber,
    transitNumber: transitNumber,
    accountNumber: accountNumber,
    iban: iban,
    clabe: clabe,
    phoneNumber: phoneNumber,
    debitcard: debitcard,
    bankAccount: bankAccount,
    isVirtualPayeeActive: true,
    accountRows: accountRows,
  );

  @override
  String toString() => 'RecipientSelection(id: $id, type: $type)';
}
