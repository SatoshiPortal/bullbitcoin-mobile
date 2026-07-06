import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/usecases/find_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_bullnym_client.dart';

void main() {
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late GetPosUsecase getPos;
  late FindPosUsecase findPos;

  setUp(() {
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client);
    getPos = GetPosUsecase(bullnym, terminalBaseUrl: 'https://bullpay.ca');
    findPos = FindPosUsecase(getPos);
  });

  BullnymDonationPage row({String kind = 'pos', bool isArchived = false}) {
    return BullnymDonationPage(
      nym: 'alice',
      header: 'My Till',
      description: '',
      displayCurrency: 'CAD',
      kind: kind,
      posMode: false,
      enabled: true,
      isArchived: isArchived,
      // A hostile/oversized server public_url is IGNORED - we construct our own.
      publicUrl: 'javascript:alert(1)',
    );
  }

  test('GETs the kind=pos row and maps it, constructing the terminal URL '
      'client-side (DG-P5)', () async {
    client.storedPage = row();

    final terminal = await getPos.execute(nym: 'alice');

    expect(client.getKinds, ['pos']);
    expect(terminal.label, 'My Till');
    expect(terminal.displayCurrency, 'CAD');
    // The terminal URL is built from the known base + nym, NOT the hostile
    // server public_url.
    expect(terminal.terminalUrl, 'https://bullpay.ca/alice/pos');
  });

  test('refuses a non-pos (payment_page) row body (§8.10 kind assertion)',
      () async {
    client.storedPage = row(kind: 'payment_page');

    await expectLater(
      getPos.execute(nym: 'alice'),
      throwsA(
        isA<PosException>().having(
          (e) => e.kind,
          'kind',
          PosErrorKind.invalidServerResponse,
        ),
      ),
    );
  });

  test('find returns null when the pos row is absent (DonationPageNotFound)',
      () async {
    client.storedPage = null;

    expect(await findPos.execute(nym: 'alice'), isNull);
  });

  test('find rethrows a non-notFound failure (loud degrade)', () async {
    client.getError = const BullnymException.network(diagnosticReason: 'x');

    await expectLater(
      findPos.execute(nym: 'alice'),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.network),
      ),
    );
  });
}
