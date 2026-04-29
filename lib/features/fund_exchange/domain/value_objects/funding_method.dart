import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:meta/meta.dart';

@immutable
sealed class FundingMethod {
  const FundingMethod();

  FundingJurisdiction get jurisdiction;
}

class EmailETransfer extends FundingMethod {
  const EmailETransfer();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.canada;
}

class BankTransferWire extends FundingMethod {
  const BankTransferWire();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.canada;
}

class OnlineBillPayment extends FundingMethod {
  const OnlineBillPayment();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.canada;
}

class CanadaPost extends FundingMethod {
  const CanadaPost();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.canada;
}

class InstantSepa extends FundingMethod {
  const InstantSepa();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.europe;
}

class RegularSepa extends FundingMethod {
  const RegularSepa();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.europe;
}

class SpeiTransfer extends FundingMethod {
  const SpeiTransfer();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.mexico;
}

class Sinpe extends FundingMethod {
  const Sinpe();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.costaRica;
}

class CrIbanCrc extends FundingMethod {
  const CrIbanCrc();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.costaRica;
}

class CrIbanUsd extends FundingMethod {
  const CrIbanUsd();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.costaRica;
}

class ArsBankTransfer extends FundingMethod {
  const ArsBankTransfer();

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.argentina;
}

class CopBankTransfer extends FundingMethod {
  final String bankCode;
  final int amountCop;

  const CopBankTransfer({required this.bankCode, required this.amountCop});

  @override
  FundingJurisdiction get jurisdiction => FundingJurisdiction.colombia;
}
