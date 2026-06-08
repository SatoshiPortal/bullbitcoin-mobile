import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/lnurl_pay_limits.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SendState LNURL pay limits', () {
    test('combines LNURL minimum with Lightning swap minimum', () {
      final state = SendState(
        sendType: SendType.lightning,
        selectedWallet: _wallet(network: Network.bitcoinMainnet),
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        amount: '4000',
        selectedSwapLimits: const SwapLimits(min: 1000, max: 100000),
        lnurlPayLimits: const LnurlPayLimits(
          minSendableSat: 5000,
          maxSendableSat: 50000,
        ),
      );

      expect(state.effectiveLightningMinimum, 5000);
      expect(state.swapAmountBelowLimit, isTrue);
    });

    test('combines LNURL maximum with Lightning swap maximum', () {
      final state = SendState(
        sendType: SendType.lightning,
        selectedWallet: _wallet(network: Network.bitcoinMainnet),
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        amount: '60000',
        selectedSwapLimits: const SwapLimits(min: 1000, max: 100000),
        lnurlPayLimits: const LnurlPayLimits(
          minSendableSat: 5000,
          maxSendableSat: 50000,
        ),
      );

      expect(state.effectiveLightningMaximum, 50000);
      expect(state.swapAmountAboveLimit, isTrue);
    });

    test('keeps fixed LNURL amount explicit in state', () {
      const state = SendState(
        lnurlPayLimits: LnurlPayLimits(
          minSendableSat: 5000,
          maxSendableSat: 5000,
        ),
      );

      expect(state.hasFixedLnurlAmount, isTrue);
    });
  });
}

Wallet _wallet({required Network network}) {
  return Wallet(
    origin: 'wallet-id',
    network: network,
    xpubFingerprint: 'fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh([00000000/84h/0h/0h]xpub/0/*)',
    internalPublicDescriptor: 'wpkh([00000000/84h/0h/0h]xpub/1/*)',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.from(100000),
  );
}
