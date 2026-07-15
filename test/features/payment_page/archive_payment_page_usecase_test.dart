import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/archive_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/recording_bullnym_client.dart';

class _MockResolveIdentity extends Mock
    implements ResolvePaymentPageIdentityUsecase {}

void main() {
  late _MockResolveIdentity resolveIdentity;
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late ArchivePaymentPageUsecase usecase;

  final identity = ResolvedPaymentPageIdentity(
    nym: 'alice',
    signer: BullnymAuthSigner(
      npubHex: 'aa' * 32,
      signHashHex: (_) => 'bb' * 64,
    ),
  );

  setUp(() {
    resolveIdentity = _MockResolveIdentity();
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client, nowSecs: () => 1710000000);
    usecase = ArchivePaymentPageUsecase(
      resolveIdentity: resolveIdentity,
      bullnym: bullnym,
    );
    when(() => resolveIdentity.execute()).thenAnswer((_) async => identity);
  });

  test(
    'sends a kind-pinned signed archive and returns the archived page',
    () async {
      final page = await usecase.execute();

      expect(page, isNotNull);
      expect(page!.isArchived, isTrue);
      final archived = client.archiveCalls.single;
      expect(archived.kind, 'payment_page');
      expect(archived.nym, 'alice');
    },
  );

  test(
    'maps a second archive (DonationPageNotFound) to a benign null',
    () async {
      client.archiveError = const BullnymException.serverRejectedRequest(
        code: 'DonationPageNotFound',
        diagnosticReason: 'nothing to archive',
        statusCode: 200,
        retryable: false,
      );

      final page = await usecase.execute();

      expect(page, isNull);
    },
  );

  test('rethrows a genuine server rejection', () async {
    client.archiveError = const BullnymException.serverRejectedRequest(
      code: 'AuthError',
      diagnosticReason: 'inactive',
      statusCode: 401,
      retryable: false,
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<PaymentPageException>().having(
          (e) => e.kind,
          'kind',
          PaymentPageErrorKind.authError,
        ),
      ),
    );
  });
}
