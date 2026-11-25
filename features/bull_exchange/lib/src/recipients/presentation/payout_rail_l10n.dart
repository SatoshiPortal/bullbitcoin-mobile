import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// The one place a rail's name is chosen.
extension PayoutRailL10n on PayoutRail {
  String label(BuildContext context) => switch (this) {
    InteracEmailRail() => context.loc.recipientsTypeInteracEmail,
    BillPaymentRail() => context.loc.recipientsTypeBillPayment,
    BankTransferCadRail() => context.loc.recipientsTypeBankTransfer,
    SepaRail() => context.loc.recipientsTypeSepa,
    ConfidentialSepaRail() => context.loc.recipientsTypeConfidentialSepa,
    SpeiClabeRail() => context.loc.recipientsTypeSpeiClabe,
    SpeiSmsRail() => context.loc.recipientsTypeSpeiSms,
    SpeiCardRail() => context.loc.recipientsTypeSpeiCard,
    SinpeIbanUsdRail() => context.loc.recipientsTypeSinpeIbanUsd,
    SinpeIbanCrcRail() => context.loc.recipientsTypeSinpeIbanCrc,
    SinpeMovilRail() => context.loc.recipientsTypeSinpeMovil,
    ArsBankTransferRail() => context.loc.recipientsTypeBankAccountAr,
    PseRail() => context.loc.recipientsTypeBankAccountCo,
    NequiRail() => context.loc.recipientsTypeNequi,
  };
}

/// One label per kind of account value, for every rail.
extension AccountFieldL10n on AccountField {
  String label(BuildContext context) => switch (this) {
    AccountField.email => context.loc.recipientsInfoEmail,
    AccountField.payee => context.loc.recipientsInfoPayee,
    AccountField.accountNumber => context.loc.recipientsFieldAccountNumber,
    AccountField.bankAccount => context.loc.recipientsInfoAccount,
    AccountField.iban => context.loc.recipientsFieldIban,
    AccountField.clabe => context.loc.recipientsFieldClabe,
    AccountField.phone => context.loc.recipientsInfoPhone,
    AccountField.card => context.loc.recipientsInfoCard,
    AccountField.cbuCvu => context.loc.recipientsFieldCvuCbu,
  };
}
