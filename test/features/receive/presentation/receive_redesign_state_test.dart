import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/receive_navigation.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/swaps.dart';

Wallet _wallet() => Wallet(
  origin: 'receive',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  ReceiveState amount(int sats, SwapRoute route) => ReceiveState(
    type: ReceiveType.lightning,
    wallet: _wallet(),
    walletAdmitted: true,
    inputAmount: '$sats',
    inputAmountCurrencyCode: 'sats',
    swapRoute: route,
    swapLimits: const SwapLimits(min: 1000, max: 10000),
  );
  test(
    'Boltz bounds are inclusive; loading, zero and invalid input cannot create',
    () {
      for (final sats in [1000, 10000]) {
        expect(amount(sats, SwapRoute.boltz).canCreateInvoice, isTrue);
      }
      for (final sats in [0, 999, 10001]) {
        expect(amount(sats, SwapRoute.boltz).canCreateInvoice, isFalse);
      }
      expect(
        amount(
          1000,
          SwapRoute.boltz,
        ).copyWith(swapLimits: null).canCreateInvoice,
        isFalse,
      );
      expect(
        amount(
          1000,
          SwapRoute.boltz,
        ).copyWith(creatingSwap: true).canCreateInvoice,
        isFalse,
      );
      expect(
        amount(
          1000,
          SwapRoute.boltz,
        ).copyWith(amountEntryValid: false).canCreateInvoice,
        isFalse,
      );
    },
  );
  test('Boltz bounds never block exchange-only or fallback routes', () {
    for (final route in [
      SwapRoute.exchange,
      SwapRoute.boltzWithExchangeFallback,
    ]) {
      expect(amount(999, route).canCreateInvoice, isTrue);
      expect(amount(10001, route).canCreateInvoice, isTrue);
    }
  });
  test(
    'a changed message requires a new signed invoice at the same amount',
    () {
      final swap = Swap.lnReceive(
        id: 'invoice',
        keyIndex: 0,
        type: SwapType.lightningToLiquid,
        status: SwapStatus.pending,
        environment: SwapEnvironment.mainnet,
        creationTime: DateTime.utc(2026),
        receiveWalletId: 'liquid',
        invoice: 'public-fixture',
      ) as LnReceiveSwap;
      final state = amount(1000, SwapRoute.boltz).copyWith(
        confirmedAmountSat: 1000,
        lightningSwap: swap,
        confirmedNote: 'Original',
        note: 'Original',
      );
      expect(canReuseConfirmedReceiveDetails(state), isTrue);
      expect(
        canReuseConfirmedReceiveDetails(state.copyWith(note: 'Changed')),
        isFalse,
      );
    },
  );
  test('confirmed amount and message build the live Bitcoin request; clearing restores raw address', () {
    final now = DateTime.utc(2026);
    final state = ReceiveState(
      type: ReceiveType.bitcoin,
      wallet: _wallet(),
      payjoinAttemptSettled: true,
      confirmedAmountSat: 12345,
      note: 'Coffee',
      bitcoinAddress: WalletAddress(
        walletId: 'receive',
        index: 0,
        address: 'bc1qpublic',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final uri = Uri.parse(state.paymentRequest);
    expect(uri.queryParameters, {'amount': '0.00012345', 'message': 'Coffee'});
    expect(
      state.copyWith(confirmedAmountSat: null, note: '').paymentRequest,
      'bc1qpublic',
    );
  });
}
