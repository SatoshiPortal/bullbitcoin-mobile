import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_wallet.dart';
import 'package:bb_mobile/features/pos/domain/usecases/prepare_pos_wallet_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/provision_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/recording_bullnym_client.dart';

class _MockResolveIdentity extends Mock implements ResolvePosIdentityUsecase {}

class _MockPrepareWallet extends Mock implements PreparePosWalletUsecase {}

class _MockGetPaidSettings extends Mock implements GetPaidSettingsFacade {}

void main() {
  late _MockResolveIdentity resolveIdentity;
  late _MockPrepareWallet prepareWallet;
  late _MockGetPaidSettings getPaidSettings;
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late ProvisionPosUsecase usecase;

  final identity = ResolvedPosIdentity(
    nym: 'alice',
    signer: BullnymAuthSigner(
      npubHex: 'aa' * 32,
      signHashHex: (_) => 'bb' * 64,
    ),
  );

  setUp(() {
    resolveIdentity = _MockResolveIdentity();
    prepareWallet = _MockPrepareWallet();
    getPaidSettings = _MockGetPaidSettings();
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client, nowSecs: () => 1710000000);
    usecase = ProvisionPosUsecase(
      resolveIdentity: resolveIdentity,
      prepareWallet: prepareWallet,
      bullnym: bullnym,
      getPaidSettings: getPaidSettings,
      terminalBaseUrl: 'https://bullpay.ca',
    );

    when(() => resolveIdentity.execute()).thenAnswer((_) async => identity);
    when(
      () => getPaidSettings.publishBackupSnapshotIfEnabled(),
    ).thenAnswer((_) async {});
  });

  void stubPrepared({bool created = true, String ctDescriptor = 'ct(103)'}) {
    when(() => prepareWallet.execute()).thenAnswer(
      (_) async => PreparedPosWallet(
        walletId: 'pos-wallet',
        ctDescriptor: ctDescriptor,
        created: created,
      ),
    );
  }

  test(
    'resolves identity, prepares wallet 103, then sends the signed pos save',
    () async {
      stubPrepared();

      final terminal = await usecase.execute(
        label: 'My Till',
        displayCurrency: 'CAD',
      );

      expect(terminal.nym, 'alice');
      expect(terminal.label, 'My Till');
      // DG-P5: the terminal URL is constructed client-side, never the server echo.
      expect(terminal.terminalUrl, 'https://bullpay.ca/alice/pos');
      verify(() => resolveIdentity.execute()).called(1);
      verify(() => prepareWallet.execute()).called(1);

      final saved = client.saveCalls.single;
      // KR-1: the 103 descriptor is ALWAYS present and non-empty; POS sales settle
      // to 103, never 101/102.
      expect(saved.ctDescriptor, 'ct(103)');
      expect(saved.ctDescriptor, isNotEmpty);
      // kind pinned pos; label in the header slot; content fields empty (DELTA 2);
      // enabled always true (single off-switch = archive, DG-P2).
      expect(saved.kind, 'pos');
      expect(saved.header, 'My Till');
      expect(saved.description, '');
      expect(saved.website, '');
      expect(saved.twitter, '');
      expect(saved.instagram, '');
      expect(saved.enabled, isTrue);
    },
  );

  test(
    'coexistence: provisioning touches only the (nym,pos) row (§8.3)',
    () async {
      stubPrepared();

      await usecase.execute(label: 'My Till', displayCurrency: 'CAD');

      // The only wire write is a single kind=pos save; the page (102) row is never
      // read or written by the pos provision path.
      expect(client.saveCalls, hasLength(1));
      expect(client.saveCalls.single.kind, 'pos');
      expect(client.archiveCalls, isEmpty);
      expect(client.getKinds, isNot(contains('payment_page')));
    },
  );

  test(
    'publishes the backup snapshot best-effort when the wallet was created',
    () async {
      stubPrepared(created: true);

      await usecase.execute(label: 'My Till', displayCurrency: 'CAD');

      verify(() => getPaidSettings.publishBackupSnapshotIfEnabled()).called(1);
    },
  );

  test(
    'does NOT publish when the wallet already existed (created:false)',
    () async {
      stubPrepared(created: false);

      await usecase.execute(label: 'My Till', displayCurrency: 'CAD');

      verifyNever(() => getPaidSettings.publishBackupSnapshotIfEnabled());
    },
  );

  test(
    'a backup publish failure never fails the provision (best-effort)',
    () async {
      stubPrepared(created: true);
      when(
        () => getPaidSettings.publishBackupSnapshotIfEnabled(),
      ).thenThrow(StateError('publish failed'));

      final terminal = await usecase.execute(
        label: 'My Till',
        displayCurrency: 'CAD',
      );

      expect(terminal.nym, 'alice');
    },
  );

  test(
    'rejects invalid input locally before any wallet or wire work',
    () async {
      stubPrepared();

      await expectLater(
        usecase.execute(label: '', displayCurrency: 'CAD'),
        throwsA(
          isA<PosException>().having(
            (e) => e.kind,
            'kind',
            PosErrorKind.invalidInput,
          ),
        ),
      );

      verifyNever(() => resolveIdentity.execute());
      verifyNever(() => prepareWallet.execute());
      expect(client.saveCalls, isEmpty);
    },
  );

  test(
    'refuses an empty descriptor before signing/wire (KR-1 kill shot)',
    () async {
      // Defense-in-depth: even if a prepared wallet somehow yields an empty
      // descriptor, the save must fail BEFORE the wire. Unlike the page, kind=pos
      // has NO server fallback, so a descriptorless save must be impossible to
      // construct - it can never route sales to 101/102.
      stubPrepared(ctDescriptor: '');

      await expectLater(
        usecase.execute(label: 'My Till', displayCurrency: 'CAD'),
        throwsA(
          isA<PosProvisionException>()
              .having(
                (e) => e.phase,
                'phase',
                PosProvisionFailurePhase.localPreparation,
              )
              .having((e) => e.code, 'code', 'EmptyPosDescriptor'),
        ),
      );
      expect(client.saveCalls, isEmpty);
    },
  );

  test('wraps a preparation failure as the localPreparation phase', () async {
    when(() => prepareWallet.execute()).thenThrow(
      const PosException.localPreparationFailed(
        code: 'WalletDefaultsFailed',
        retryable: true,
      ),
    );

    await expectLater(
      usecase.execute(label: 'My Till', displayCurrency: 'CAD'),
      throwsA(
        isA<PosProvisionException>()
            .having(
              (e) => e.phase,
              'phase',
              PosProvisionFailurePhase.localPreparation,
            )
            .having((e) => e.submissionMayBeUncertain, 'uncertain', false),
      ),
    );
    expect(client.saveCalls, isEmpty);
  });

  test('wraps a timeout on the PUT as an uncertain submission', () async {
    stubPrepared();
    client.saveError = const BullnymFailure.timeout(logMessage: 'slow');

    await expectLater(
      usecase.execute(label: 'My Till', displayCurrency: 'CAD'),
      throwsA(
        isA<PosProvisionException>()
            .having(
              (e) => e.phase,
              'phase',
              PosProvisionFailurePhase.submission,
            )
            .having((e) => e.submissionMayBeUncertain, 'uncertain', true),
      ),
    );
    expect(client.saveCalls, hasLength(1));
  });

  test('surfaces a pre-release server AuthError as a non-uncertain submission '
      '(fail-closed, KR-2)', () async {
    stubPrepared();
    client.saveError = const BullnymFailure.serverRejectedRequest(
      code: 'AuthError',
      logMessage: 'signature mismatch',
      statusCode: 401,
      retryable: false,
    );

    await expectLater(
      usecase.execute(label: 'My Till', displayCurrency: 'CAD'),
      throwsA(
        isA<PosProvisionException>()
            .having((e) => e.kind, 'kind', PosErrorKind.authError)
            .having((e) => e.submissionMayBeUncertain, 'uncertain', false),
      ),
    );
  });

  test('a descriptorless save cannot be constructed: no save API descriptor '
      'parameter, sourced solely from the prepared wallet (KR-1)', () async {
    stubPrepared(ctDescriptor: 'ct(minimal)');

    await usecase.execute(label: 'My Till', displayCurrency: 'CAD');

    final saved = client.saveCalls.single;
    expect(saved.ctDescriptor, 'ct(minimal)');
    expect(saved.ctDescriptor, isNotEmpty);
  });
}
