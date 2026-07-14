import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_payment_page_permanent_name_usecase.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_permanent_name_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeBullnymFacade bullnym;
  late _OwnerLookup owner;

  setUp(() {
    bullnym = _FakeBullnymFacade();
    owner = _OwnerLookup();
  });

  GetPaymentPagePermanentNameUsecase pageUsecase() =>
      GetPaymentPagePermanentNameUsecase(
        bullnym: bullnym,
        lightningAddress: owner.facade,
      );

  GetPosPermanentNameUsecase posUsecase() => GetPosPermanentNameUsecase(
    bullnym: bullnym,
    lightningAddress: owner.facade,
  );

  test(
    'both surfaces reconstruct one shared alias independent of LA online',
    () async {
      owner.status = _status(
        nym: 'alice',
        alias: 'shop',
        lightningAddressOnline: false,
      );

      final page = await pageUsecase().execute();
      final pos = await posUsecase().execute();

      expect(page.supported, isTrue);
      expect(page.nym, 'alice');
      expect(page.alias, 'shop');
      expect(pos.supported, isTrue);
      expect(pos.nym, 'alice');
      expect(pos.alias, 'shop');
      expect(owner.calls, 2);
    },
  );

  test(
    'unknown policy fails closed before authenticated owner lookup',
    () async {
      bullnym.version = const BullnymVersionInfo(
        publicNamePolicy: 'permanent_names_v2',
      );

      final page = await pageUsecase().execute();
      final pos = await posUsecase().execute();

      expect(page.supported, isFalse);
      expect(pos.supported, isFalse);
      expect(owner.calls, 0);
    },
  );

  test(
    'absent policy fails closed before authenticated owner lookup',
    () async {
      bullnym.version = const BullnymVersionInfo(publicNamePolicy: null);

      expect((await pageUsecase().execute()).supported, isFalse);
      expect((await posUsecase().execute()).supported, isFalse);
      expect(owner.calls, 0);
    },
  );

  test('NymNotFound is the only owner failure treated as unclaimed', () async {
    owner.error = const LightningAddressServerRejectedRequestException(
      code: 'NymNotFound',
      retryable: false,
    );

    final page = await pageUsecase().execute();
    final pos = await posUsecase().execute();

    expect(page.supported, isTrue);
    expect(page.nym, isNull);
    expect(pos.supported, isTrue);
    expect(pos.nym, isNull);
  });

  test('capability transport failures remain loud and typed', () async {
    bullnym.versionFailure = const BullnymFailure.network(
      logMessage: 'diagnostic must not escape',
    );

    await expectLater(
      pageUsecase().execute(),
      throwsA(
        isA<PaymentPageException>()
            .having((error) => error.kind, 'kind', PaymentPageErrorKind.network)
            .having(
              (error) => error.toString(),
              'safe error',
              isNot(contains('diagnostic')),
            ),
      ),
    );
    await expectLater(
      posUsecase().execute(),
      throwsA(
        isA<PosException>().having(
          (error) => error.kind,
          'kind',
          PosErrorKind.network,
        ),
      ),
    );
    expect(owner.calls, 0);
  });

  test(
    'inconsistent permanent-name projection is refused by both surfaces',
    () async {
      owner.status = _status(nym: 'other', projectionNym: 'alice');

      await expectLater(
        pageUsecase().execute(),
        throwsA(
          isA<PaymentPageException>().having(
            (error) => error.kind,
            'kind',
            PaymentPageErrorKind.invalidServerResponse,
          ),
        ),
      );
      await expectLater(
        posUsecase().execute(),
        throwsA(
          isA<PosException>().having(
            (error) => error.kind,
            'kind',
            PosErrorKind.invalidServerResponse,
          ),
        ),
      );
    },
  );
}

LightningAddressStatus _status({
  required String nym,
  String? projectionNym,
  String? alias,
  bool lightningAddressOnline = true,
}) {
  return LightningAddressStatus(
    nym: nym,
    active: lightningAddressOnline,
    permanentNameStatus: LightningAddressPermanentNameStatus(
      nym: projectionNym ?? nym,
      alias: alias,
      lightningAddressOnline: lightningAddressOnline,
      quota: const LightningAddressPermanentNameQuota(
        used: 1,
        cap: 1,
        remaining: 0,
      ),
    ),
  );
}

class _FakeBullnymFacade implements BullnymFacade {
  BullnymVersionInfo version = const BullnymVersionInfo(
    publicNamePolicy: bullnymPermanentNamesV1Policy,
  );
  BullnymFailure? versionFailure;

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() async {
    final failure = versionFailure;
    return failure == null ? Ok(version) : Err(failure);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OwnerLookup {
  LightningAddressStatus status = _status(nym: 'alice');
  Object? error;
  int calls = 0;

  late final LightningAddressFacade facade = LightningAddressFacade(
    prepareWallet: () => throw UnimplementedError(),
    lookupRegistration: ({required npubHex}) => throw UnimplementedError(),
    registerWalletOwned: ({required nym}) => throw UnimplementedError(),
    lookupWalletOwnedRegistration: () async {
      calls += 1;
      final currentError = error;
      if (currentError != null) throw currentError;
      return status;
    },
    ensureRegistrationLive: () => throw UnimplementedError(),
  );
}
