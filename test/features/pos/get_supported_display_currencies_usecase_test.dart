import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_supported_display_currencies_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_bullnym_client.dart';

void main() {
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late GetSupportedDisplayCurrenciesUsecase usecase;

  setUp(() {
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client);
    usecase = GetSupportedDisplayCurrenciesUsecase(bullnym);
  });

  test(
    'maps the server currency list into DisplayCurrency (code + precision)',
    () async {
      client.currencies = const [
        BullnymSupportedCurrency(code: 'CAD', precision: 2),
        BullnymSupportedCurrency(code: 'COP', precision: 0),
      ];

      final currencies = await usecase.execute();

      expect(currencies.map((c) => c.code), ['CAD', 'COP']);
      expect(currencies.last.precision, 0);
    },
  );

  test('maps a server failure into the pos error family', () async {
    client.currenciesError = const BullnymException.network(
      diagnosticReason: 'offline',
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.network),
      ),
    );
  });
}
