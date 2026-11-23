import 'package:meta/meta.dart';

import '../catalog/jurisdiction.dart';

@immutable
sealed class FundingMethod {
  const FundingMethod();

  Jurisdiction get jurisdiction;
}

class EmailETransfer extends FundingMethod {
  const EmailETransfer();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;
}

class BankTransferWire extends FundingMethod {
  const BankTransferWire();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;
}

class OnlineBillPayment extends FundingMethod {
  const OnlineBillPayment();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;
}

class CanadaPost extends FundingMethod {
  const CanadaPost();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;
}

class InstantSepa extends FundingMethod {
  const InstantSepa();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;
}

class RegularSepa extends FundingMethod {
  const RegularSepa();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;
}

class SpeiTransfer extends FundingMethod {
  const SpeiTransfer();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.mexico;
}

class Sinpe extends FundingMethod {
  const Sinpe();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;
}

class CrIbanCrc extends FundingMethod {
  const CrIbanCrc();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;
}

class CrIbanUsd extends FundingMethod {
  const CrIbanUsd();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;
}

class ArsBankTransfer extends FundingMethod {
  const ArsBankTransfer();

  @override
  Jurisdiction get jurisdiction => Jurisdiction.argentina;
}

class CopBankTransfer extends FundingMethod {
  final String bankCode;
  final int amountCop;

  const CopBankTransfer({required this.bankCode, required this.amountCop});

  @override
  Jurisdiction get jurisdiction => Jurisdiction.colombia;
}
