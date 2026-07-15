import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/usecases/archive_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/recording_bullnym_client.dart';

class _MockResolveIdentity extends Mock implements ResolvePosIdentityUsecase {}

void main() {
  late _MockResolveIdentity resolveIdentity;
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late ArchivePosUsecase usecase;

  final identity = ResolvedPosIdentity(
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
    usecase = ArchivePosUsecase(
      resolveIdentity: resolveIdentity,
      bullnym: bullnym,
      terminalBaseUrl: 'https://bullpay.ca',
    );
    when(() => resolveIdentity.execute()).thenAnswer((_) async => identity);
  });

  test(
    'sends a kind-pinned signed archive and returns the archived terminal',
    () async {
      final terminal = await usecase.execute();

      expect(terminal, isNotNull);
      expect(terminal!.isArchived, isTrue);
      expect(terminal.terminalUrl, 'https://bullpay.ca/alice/pos');
      final archived = client.archiveCalls.single;
      expect(archived.kind, 'pos');
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

      final terminal = await usecase.execute();

      expect(terminal, isNull);
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
        isA<PosException>().having(
          (e) => e.kind,
          'kind',
          PosErrorKind.authError,
        ),
      ),
    );
  });
}
