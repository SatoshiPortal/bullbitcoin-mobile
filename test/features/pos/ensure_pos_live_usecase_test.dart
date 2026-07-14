import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_liveness.dart';
import 'package:bb_mobile/features/pos/domain/usecases/ensure_pos_live_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/find_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_bullnym_client.dart';

void main() {
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late FindPosUsecase findPos;

  setUp(() {
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client);
    findPos = FindPosUsecase(GetPosUsecase(bullnym));
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

  EnsurePosLiveUsecase healWith(LightningAddressFacade la) {
    return EnsurePosLiveUsecase(lightningAddress: la, findPos: findPos);
  }

  BullnymDonationPage pos({bool isArchived = false}) {
    return BullnymDonationPage(
      nym: 'alice',
      header: 'My Till',
      description: '',
      displayCurrency: 'CAD',
      kind: 'pos',
      posMode: false,
      enabled: true,
      isArchived: isArchived,
      publicUrl: 'https://bullpay.ca/alice/pos',
    );
  }

  const activeStatus = LightningAddressStatus(nym: 'alice', active: true);

  test('pos present and not archived -> live, zero writes', () async {
    client.storedPage = pos();
    final outcome = await healWith(laFacade(status: activeStatus)).execute();

    expect(outcome.liveness, PosLiveness.live);
    expect(client.totalWriteCalls, 0);
  });

  test('pos archived -> archivedByUser, zero writes', () async {
    client.storedPage = pos(isArchived: true);
    final outcome = await healWith(laFacade(status: activeStatus)).execute();

    expect(outcome.liveness, PosLiveness.archivedByUser);
    expect(client.totalWriteCalls, 0);
  });

  test(
    'registration live but pos row absent -> needsReactivation, no PUT',
    () async {
      client.storedPage = null; // GET returns DonationPageNotFound
      final outcome = await healWith(laFacade(status: activeStatus)).execute();

      expect(outcome.liveness, PosLiveness.needsReactivation);
      expect(client.getDonationPageCalls, 1);
      // The heal GET is kind-scoped to pos - it never touches the page row.
      expect(client.getKinds, ['pos']);
      expect(client.totalWriteCalls, 0);
    },
  );

  test(
    'pos GET unreachable -> unreachable, never fake-live, zero writes',
    () async {
      client.getError = const BullnymFailure.network(logMessage: 'offline');
      final outcome = await healWith(laFacade(status: activeStatus)).execute();

      expect(outcome.liveness, PosLiveness.unreachable);
      expect(client.totalWriteCalls, 0);
    },
  );

  test(
    'no nym (NymNotFound) -> needsReactivation, never touches the pos',
    () async {
      final la = laFacade(
        lookupError: const LightningAddressServerRejectedRequestException(
          code: 'NymNotFound',
          retryable: false,
        ),
      );

      final outcome = await healWith(la).execute();

      expect(outcome.liveness, PosLiveness.needsReactivation);
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

    expect(outcome.liveness, PosLiveness.unreachable);
    expect(client.totalWriteCalls, 0);
  });
}
