import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_wallet.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/prepare_payment_page_wallet_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/save_payment_page_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/recording_bullnym_client.dart';

class _MockResolveIdentity extends Mock
    implements ResolvePaymentPageIdentityUsecase {}

class _MockPrepareWallet extends Mock
    implements PreparePaymentPageWalletUsecase {}

class _MockGetPaidSettings extends Mock implements GetPaidSettingsFacade {}

void main() {
  late _MockResolveIdentity resolveIdentity;
  late _MockPrepareWallet prepareWallet;
  late _MockGetPaidSettings getPaidSettings;
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late SavePaymentPageUsecase usecase;

  final identity = ResolvedPaymentPageIdentity(
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
    usecase = SavePaymentPageUsecase(
      resolveIdentity: resolveIdentity,
      prepareWallet: prepareWallet,
      bullnym: bullnym,
      getPaidSettings: getPaidSettings,
    );

    when(() => resolveIdentity.execute()).thenAnswer((_) async => identity);
    when(() => getPaidSettings.publishBackupSnapshotIfEnabled())
        .thenAnswer((_) async {});
  });

  void stubPrepared({bool created = true, String ctDescriptor = 'ct(desc)'}) {
    when(() => prepareWallet.execute()).thenAnswer(
      (_) async => PreparedPaymentPageWallet(
        walletId: 'pp-wallet',
        ctDescriptor: ctDescriptor,
        created: created,
      ),
    );
  }

  test('resolves identity, prepares the wallet, then sends the signed save',
      () async {
    stubPrepared();

    final page = await usecase.execute(
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
      website: 'https://example.com',
      twitter: 'me',
    );

    expect(page.nym, 'alice');
    verify(() => resolveIdentity.execute()).called(1);
    verify(() => prepareWallet.execute()).called(1);

    final saved = client.saveCalls.single;
    // KR-1: the descriptor is ALWAYS the prepared wallet's non-empty descriptor.
    expect(saved.ctDescriptor, 'ct(desc)');
    expect(saved.ctDescriptor, isNotEmpty);
    // kind pinned to payment_page; enabled always true (single off-switch =
    // archive, DG-3).
    expect(saved.kind, 'payment_page');
    expect(saved.enabled, isTrue);
    expect(saved.nym, 'alice');
    expect(saved.website, 'https://example.com');
    expect(saved.instagram, ''); // absent optional serialized as empty
  });

  test('publishes the backup snapshot best-effort when the wallet was created',
      () async {
    stubPrepared(created: true);

    await usecase.execute(
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
    );

    verify(() => getPaidSettings.publishBackupSnapshotIfEnabled()).called(1);
  });

  test('does NOT publish when the wallet already existed (created:false)',
      () async {
    stubPrepared(created: false);

    await usecase.execute(
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
    );

    verifyNever(() => getPaidSettings.publishBackupSnapshotIfEnabled());
  });

  test('a backup publish failure never fails the save (best-effort)', () async {
    stubPrepared(created: true);
    when(() => getPaidSettings.publishBackupSnapshotIfEnabled())
        .thenThrow(StateError('publish failed'));

    final page = await usecase.execute(
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
    );

    expect(page.nym, 'alice');
  });

  test('rejects invalid input locally before any wallet or wire work',
      () async {
    stubPrepared();

    await expectLater(
      usecase.execute(
        header: '', // invalid
        description: 'Support my work',
        displayCurrency: 'CAD',
      ),
      throwsA(
        isA<PaymentPageException>().having(
          (e) => e.kind,
          'kind',
          PaymentPageErrorKind.invalidInput,
        ),
      ),
    );

    verifyNever(() => resolveIdentity.execute());
    verifyNever(() => prepareWallet.execute());
    expect(client.saveCalls, isEmpty);
  });

  test('refuses an empty descriptor before signing/wire (KR-1 guard)',
      () async {
    // Defense-in-depth: even if a prepared wallet somehow yields an empty
    // descriptor, the save must fail BEFORE the wire so page funds can never
    // route to the LA wallet via the server's empty-descriptor fallback.
    stubPrepared(ctDescriptor: '');

    await expectLater(
      usecase.execute(
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
      ),
      throwsA(
        isA<PaymentPageSaveException>()
            .having(
              (e) => e.phase,
              'phase',
              PaymentPageSaveFailurePhase.localPreparation,
            )
            .having((e) => e.code, 'code', 'EmptyPageDescriptor'),
      ),
    );
    expect(client.saveCalls, isEmpty);
  });

  test('wraps a preparation failure as the localPreparation phase', () async {
    when(() => prepareWallet.execute()).thenThrow(
      const PaymentPageException.localPreparationFailed(
        code: 'WalletDefaultsFailed',
        retryable: true,
      ),
    );

    await expectLater(
      usecase.execute(
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
      ),
      throwsA(
        isA<PaymentPageSaveException>()
            .having(
              (e) => e.phase,
              'phase',
              PaymentPageSaveFailurePhase.localPreparation,
            )
            .having((e) => e.submissionMayBeUncertain, 'uncertain', false),
      ),
    );
    expect(client.saveCalls, isEmpty);
  });

  test('wraps a timeout on the PUT as an uncertain submission', () async {
    stubPrepared();
    client.saveError = const BullnymException.timeout(diagnosticReason: 'slow');

    await expectLater(
      usecase.execute(
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
      ),
      throwsA(
        isA<PaymentPageSaveException>()
            .having(
              (e) => e.phase,
              'phase',
              PaymentPageSaveFailurePhase.submission,
            )
            .having((e) => e.submissionMayBeUncertain, 'uncertain', true),
      ),
    );
    // The save was attempted exactly once (retry is the caller's decision).
    expect(client.saveCalls, hasLength(1));
  });

  test('surfaces a pre-034 server AuthError as a non-uncertain submission',
      () async {
    stubPrepared();
    client.saveError = const BullnymException.serverRejectedRequest(
      code: 'AuthError',
      diagnosticReason: 'signature mismatch',
      statusCode: 401,
      retryable: false,
    );

    await expectLater(
      usecase.execute(
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
      ),
      throwsA(
        isA<PaymentPageSaveException>()
            .having((e) => e.kind, 'kind', PaymentPageErrorKind.authError)
            .having((e) => e.submissionMayBeUncertain, 'uncertain', false),
      ),
    );
  });

  test('a minimal save (no optionals) still sends the prepared descriptor',
      () async {
    // The save API has NO descriptor parameter (the fields are the validated
    // command only). The descriptor is sourced solely from the prepared wallet,
    // so an empty-descriptor save cannot be constructed (KR-1).
    stubPrepared(ctDescriptor: 'ct(minimal)');

    await usecase.execute(
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
    );

    final saved = client.saveCalls.single;
    expect(saved.ctDescriptor, 'ct(minimal)');
    expect(saved.ctDescriptor, isNotEmpty);
    expect(saved.website, '');
    expect(saved.twitter, '');
    expect(saved.instagram, '');
  });
}
