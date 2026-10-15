import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete bank details make an active virtual IBAN', () {
    final virtualIban = VirtualIban.fromBankDetails(
      iban: ' FR7616958000016918327146718 ',
      bicCode: 'FIRPFRP2',
      bankAddress: '1 Rue de la Paix, Paris',
      ibanCountry: 'FR',
    );

    expect(virtualIban, isA<ActiveVirtualIban>());
    final active = virtualIban as ActiveVirtualIban;
    expect(active.iban, 'FR7616958000016918327146718');
    expect(active.bicCode, 'FIRPFRP2');
    expect(active.bankAddress, '1 Rue de la Paix, Paris');
    expect(active.ibanCountry, 'FR');
  });

  test('missing bank details mean the virtual IBAN is still pending', () {
    expect(VirtualIban.fromBankDetails(), isA<PendingVirtualIban>());
    expect(
      VirtualIban.fromBankDetails(
        iban: 'FR7616958000016918327146718',
        bicCode: 'FIRPFRP2',
      ),
      isA<PendingVirtualIban>(),
    );
    expect(
      VirtualIban.fromBankDetails(
        iban: 'FR7616958000016918327146718',
        bicCode: 'FIRPFRP2',
        bankAddress: '  ',
      ),
      isA<PendingVirtualIban>(),
    );
  });
}
