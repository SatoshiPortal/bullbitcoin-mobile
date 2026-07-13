import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_liveness.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/ensure_payment_page_live_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/find_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_payment_page_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_bullnym_client.dart';

void main() {
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late FindPaymentPageUsecase findPage;

  setUp(() {
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client);
    findPage = FindPaymentPageUsecase(GetPaymentPageUsecase(bullnym));
  });

  // A Lightning Address facade whose only exercised callback is
  // lookupWalletOwnedRegistration; the rest are inert.
  LightningAddressFacade laFacade({
    LightningAddressStatus? status,
    Object? lookupError,
  }) {
    return LightningAddressFacade(
      prepareWallet: () => throw UnimplementedError(),
      lookupRegistration: ({required npubHex}) => throw UnimplementedError(),
      registerWalletOwned: ({required nym}) => throw UnimplementedError(),
      lookupWalletOwnedRegistration: () async {
        if (lookupError != null) throw lookupError;
        return status!;
      },
      ensureRegistrationLive: () => throw UnimplementedError(),
    );
  }

  EnsurePaymentPageLiveUsecase healWith(LightningAddressFacade la) {
    return EnsurePaymentPageLiveUsecase(
      lightningAddress: la,
      findPage: findPage,
    );
  }

  BullnymDonationPage page({bool isArchived = false}) {
    return BullnymDonationPage(
      nym: 'alice',
      header: 'Tip me',
      description: 'Support my work',
      displayCurrency: 'CAD',
      kind: 'payment_page',
      posMode: false,
      enabled: true,
      isArchived: isArchived,
      publicUrl: 'https://bullpay.ca/alice',
    );
  }

  const activeStatus = LightningAddressStatus(nym: 'alice', active: true);

  test('page present and not archived -> live, zero writes', () async {
    client.storedPage = page();
    final outcome = await healWith(laFacade(status: activeStatus)).execute();

    expect(outcome.liveness, PaymentPageLiveness.live);
    expect(client.totalWriteCalls, 0);
  });

  test('page archived -> archivedByUser, zero writes', () async {
    client.storedPage = page(isArchived: true);
    final outcome = await healWith(laFacade(status: activeStatus)).execute();

    expect(outcome.liveness, PaymentPageLiveness.archivedByUser);
    expect(client.totalWriteCalls, 0);
  });

  test(
    'registration live but page row absent -> needsReactivation, no PUT',
    () async {
      client.storedPage = null; // GET returns DonationPageNotFound
      final outcome = await healWith(laFacade(status: activeStatus)).execute();

      expect(outcome.liveness, PaymentPageLiveness.needsReactivation);
      expect(client.getDonationPageCalls, 1);
      expect(client.totalWriteCalls, 0);
    },
  );

  test(
    'page GET unreachable -> unreachable, never fake-live, zero writes',
    () async {
      client.getError = const BullnymFailure.network(logMessage: 'offline');
      final outcome = await healWith(laFacade(status: activeStatus)).execute();

      expect(outcome.liveness, PaymentPageLiveness.unreachable);
      expect(client.totalWriteCalls, 0);
    },
  );

  test(
    'no nym (NymNotFound) -> needsReactivation, never touches the page',
    () async {
      final la = laFacade(
        lookupError: const LightningAddressServerRejectedRequestException(
          code: 'NymNotFound',
          retryable: false,
        ),
      );

      final outcome = await healWith(la).execute();

      expect(outcome.liveness, PaymentPageLiveness.needsReactivation);
      expect(client.getDonationPageCalls, 0);
      expect(client.totalWriteCalls, 0);
    },
  );

  test('registration lookup unreachable -> unreachable, zero writes', () async {
    final la = laFacade(
      lookupError: const LightningAddressServerRejectedRequestException(
        code: 'ServiceUnavailable',
        retryable: true,
      ),
    );

    final outcome = await healWith(la).execute();

    expect(outcome.liveness, PaymentPageLiveness.unreachable);
    expect(client.totalWriteCalls, 0);
  });
}
