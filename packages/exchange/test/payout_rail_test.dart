import 'package:exchange/exchange.dart';
import 'package:test/test.dart';

final _sepa = SepaEurDetails.create(
  iban: 'FR76 3000 6000 0112 3456 7890 189',
  isCorporate: false,
  firstname: 'Ana',
  lastname: 'Silva',
);

/// One recipient per rail, with the name and account rows the rail shows.
final _cases = <(RecipientDetails, PayoutRail, String?, List<AccountRow>)>[
  (
    InteracEmailCadDetails.create(email: 'a@b.ca', name: 'Ann'),
    PayoutRails.interacEmail,
    'Ann',
    [const AccountRow(AccountField.email, 'a@b.ca')],
  ),
  (
    BillPaymentCadDetails.create(
      payeeName: 'Hydro',
      payeeCode: 'H1',
      payeeAccountNumber: '42',
    ),
    PayoutRails.billPayment,
    'Hydro',
    [
      const AccountRow(AccountField.accountNumber, '42'),
      const AccountRow(AccountField.payee, 'Hydro'),
    ],
  ),
  (
    BankTransferCadDetails.create(
      institutionNumber: '001',
      transitNumber: '12345',
      accountNumber: '9876',
      name: 'Bo',
    ),
    PayoutRails.bankTransferCad,
    'Bo',
    [const AccountRow(AccountField.bankAccount, '001-12345-9876')],
  ),
  (
    _sepa,
    PayoutRails.sepa,
    'Ana Silva',
    [const AccountRow(AccountField.iban, 'FR76 3000 6000 0112 3456 7890 189')],
  ),
  (
    _sepa.asConfidential(),
    PayoutRails.confidentialSepa,
    'Ana Silva',
    [const AccountRow(AccountField.iban, 'FR76 3000 6000 0112 3456 7890 189')],
  ),
  (
    SpeiClabeMxnDetails.create(clabe: '0021', name: 'Lu'),
    PayoutRails.speiClabe,
    'Lu',
    [const AccountRow(AccountField.clabe, '0021')],
  ),
  (
    SpeiSmsMxnDetails.create(institutionCode: '40', phone: '555', name: 'Lu'),
    PayoutRails.speiSms,
    'Lu',
    [const AccountRow(AccountField.phone, '555')],
  ),
  (
    SpeiCardMxnDetails.create(
      institutionCode: '40',
      debitcard: '4111',
      name: 'Lu',
    ),
    PayoutRails.speiCard,
    'Lu',
    [const AccountRow(AccountField.card, '4111')],
  ),
  (
    SinpeIbanUsdDetails.create(iban: 'CR01'),
    PayoutRails.sinpeIbanUsd,
    'CR01',
    [const AccountRow(AccountField.iban, 'CR01')],
  ),
  (
    SinpeIbanCrcDetails.create(iban: 'CR02', ownerName: 'Eva'),
    PayoutRails.sinpeIbanCrc,
    'Eva',
    [const AccountRow(AccountField.iban, 'CR02')],
  ),
  (
    SinpeMovilCrcDetails.create(phoneNumber: '8888', label: 'Mom'),
    PayoutRails.sinpeMovil,
    'Mom',
    [const AccountRow(AccountField.phone, '+506-8888')],
  ),
  (
    BankAccountArgentinaDetails.create(claveUniform: '0170', name: 'Juan'),
    PayoutRails.arsBankTransfer,
    'Juan',
    [const AccountRow(AccountField.cbuCvu, '0170')],
  ),
  (
    PseColombiaDetails.create(
      holder: ColombiaIndividual.create(firstName: 'Sofi', lastName: 'Gómez'),
      email: 'sofi@example.com',
      accountType: 'SAVINGS',
      bankAccount: '123',
      bankCode: '1007',
      bankName: 'Bancolombia',
      documentId: '99',
      documentType: 'CC',
    ),
    PayoutRails.pse,
    'Sofi Gómez',
    [const AccountRow(AccountField.accountNumber, '123')],
  ),
  (
    NequiColombiaDetails.create(
      holder: ColombiaCorporate.create(corporateName: 'Sofi SAS'),
      email: 'pagos@sofi.co',
      phoneNumber: '300',
      documentId: '99',
      documentType: 'CC',
    ),
    PayoutRails.nequi,
    'Sofi SAS',
    [const AccountRow(AccountField.phone, '300')],
  ),
];

void main() {
  test('there are 14 rails, one per recipient type', () {
    expect(PayoutRails.all, hasLength(14));
    expect(PayoutRails.all.toSet(), hasLength(14));
    for (final type in RecipientType.values) {
      expect(PayoutRails.of(type).type, type, reason: type.name);
      expect(type.rail, PayoutRails.of(type));
    }
    expect(
      PayoutRails.all.map((rail) => rail.type).toSet(),
      RecipientType.values.toSet(),
    );
  });

  test('every rail is in exactly one market of its own currency', () {
    for (final rail in PayoutRails.all) {
      final markets = [
        for (final market in ExchangeCatalog.markets)
          if (market.payoutRails.contains(rail)) market,
      ];
      expect(markets, [rail.market], reason: '$rail');
      expect(
        rail.market,
        ExchangeCatalog.market(rail.market.currency),
        reason: '$rail',
      );
      expect(rail.type.jurisdiction, rail.market.jurisdiction);
      expect(rail.type.currency, rail.market.currency);
    }
  });

  test('every market offers a rail without eligibility', () {
    for (final market in ExchangeCatalog.markets) {
      expect(
        market.payoutRails.where((rail) => !rail.needsEligibility),
        isNotEmpty,
        reason: '$market',
      );
    }
  });

  test('the standard rails leave out Confidential SEPA only', () {
    expect(PayoutRails.standard, hasLength(13));
    expect(PayoutRails.standard, isNot(contains(PayoutRails.confidentialSepa)));
    expect(
      [
        for (final rail in PayoutRails.all)
          if (rail.needsEligibility) rail,
      ],
      [PayoutRails.confidentialSepa],
    );
  });

  test('USD pays out in Costa Rica', () {
    expect(PayoutRails.sinpeIbanUsd.market, ExchangeCatalog.usd);
    expect(ExchangeCatalog.usd.jurisdiction, Jurisdiction.costaRica);
  });

  test('only SEPA rails name a processor, one mapping for every flow', () {
    for (final rail in PayoutRails.all) {
      expect(rail.paymentProcessor, switch (rail) {
        SepaRail() => SepaPaymentProcessor.regular,
        ConfidentialSepaRail() => SepaPaymentProcessor.confidential,
        _ => isNull,
      }, reason: '$rail');
    }
  });

  test('only SINPE Móvil has a receipt', () {
    expect(
      [
        for (final rail in PayoutRails.all)
          if (rail.hasReceipt) rail,
      ],
      [PayoutRails.sinpeMovil],
    );
  });

  test('every rail has a case below', () {
    expect(_cases.map((c) => c.$2).toSet(), PayoutRails.all.toSet());
  });

  for (final (details, rail, name, rows) in _cases) {
    test('$rail reads its own details', () {
      final onRail = details.onRail;
      expect(onRail.rail, rail);
      expect(details.rail, rail);
      expect(onRail.displayName, name);
      expect(onRail.accountRows, rows);
    });
  }

  test('a SEPA corporate recipient shows the company name', () {
    final corporate = SepaEurDetails.create(
      iban: 'DE89',
      isCorporate: true,
      corporateName: 'ACME GmbH',
    );
    expect(corporate.onRail.displayName, 'ACME GmbH');
  });

  test('a SINPE recipient without owner name falls back to its label', () {
    final movil = SinpeMovilCrcDetails.create(phoneNumber: '8888 1234');
    expect(movil.onRail.displayName, '8888 1234');
    expect(movil.onRail.accountRows, [
      const AccountRow(AccountField.phone, '+506-8888-1234'),
    ]);
    final iban = SinpeIbanCrcDetails.create(iban: 'CR02', label: 'Rent');
    expect(iban.onRail.displayName, 'Rent');
  });
}
