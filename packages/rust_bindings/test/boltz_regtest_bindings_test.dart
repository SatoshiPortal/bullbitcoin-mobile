import 'dart:convert';
import 'dart:io';

import 'package:bull_sdk/boltz.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => BullSdk.init());
  tearDownAll(BullSdk.dispose);

  test('concrete regtest chains retain their native enum indices', () async {
    expect(Chain.bitcoinRegtest.index, 4);
    expect(Chain.liquidRegtest.index, 5);
    expect(await Chain.bitcoinRegtest.isTestnet(), isFalse);
    expect(await Chain.liquidRegtest.isTestnet(), isFalse);
  });

  test(
    'synthetic legacy production JSON round-trips exactly through FFI',
    () async {
      for (final name in ['mainnet', 'testnet']) {
        final original = File('test/fixtures/boltz_chain_swap_$name.json')
            .readAsStringSync();
        final swap = await ChainSwap.fromJson(jsonStr: original);
        expect(await swap.toJson(), original);
        expect(
          swap.network,
          name == 'mainnet' ? Network.mainnet : Network.testnet,
        );
      }
    },
  );

  test('regtest manual construction and JSON preserve caller URLs', () async {
    final data = jsonDecode(
      File('test/fixtures/boltz_chain_swap_mainnet.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    data.remove('is_testnet');
    data['network'] = 'Regtest';
    final recovered = await ChainSwap.fromJson(jsonStr: jsonEncode(data));
    final swap = await ChainSwap.newInstance(
      id: recovered.id,
      network: Network.regtest,
      direction: recovered.direction,
      refundKeys: recovered.refundKeys,
      refundIndex: recovered.refundIndex,
      claimKeys: recovered.claimKeys,
      claimIndex: recovered.claimIndex,
      preimage: recovered.preimage,
      btcScriptStr: recovered.btcScriptStr,
      lbtcScriptStr: recovered.lbtcScriptStr,
      scriptAddress: recovered.scriptAddress,
      outAmount: recovered.outAmount,
      btcElectrumUrl: 'bitcoin.example:18201',
      lbtcElectrumUrl: 'liquid.example:18202',
      boltzUrl: 'http://boltz.example:18200/custom/v2',
      blindingKey: recovered.blindingKey,
    );
    expect(swap.network, Network.regtest);
    expect(swap.boltzUrl, 'http://boltz.example:18200/custom/v2');
    final encoded = await swap.toJson();
    expect(jsonDecode(encoded).containsKey('is_testnet'), isFalse);
    final restored = await ChainSwap.fromJson(jsonStr: encoded);
    expect(restored.network, Network.regtest);
    expect(restored.boltzUrl, swap.boltzUrl);
    expect(restored.btcElectrumUrl, swap.btcElectrumUrl);
    expect(restored.lbtcElectrumUrl, swap.lbtcElectrumUrl);
  });

  test(
    'quotes retain explicit HTTP URLs through the existing constructor',
    () async {
      final fees = await Fees.newInstance(
        boltzUrl: 'http://quotes.example:18204/v2',
      );
      expect(fees.boltzUrl, 'http://quotes.example:18204/v2');
    },
  );

  test(
    'explicit explorer crosses FFI before an invalid operation is rejected',
    () async {
      Future<List<VoutOutspend>> check(String? explorerUrl) =>
          checkLockupOutspends(
            swapId: 'synthetic',
            swapType: SwapType.submarine,
            txKind: SwapTxKind.claim,
            network: Chain.bitcoinRegtest,
            boltzUrl: 'http://127.0.0.1:1',
            explorerUrl: explorerUrl,
          );
      await expectLater(
        check(null),
        throwsA(
          isA<BoltzError>().having(
            (error) => error.message,
            'message',
            'Regtest requires an explicit explorer URL',
          ),
        ),
      );
      await expectLater(
        check('http://explorer.example:18205/custom'),
        throwsA(
          isA<BoltzError>().having(
            (error) => error.message,
            'message',
            'Submarine swaps cannot be checked for claim',
          ),
        ),
      );
    },
  );

  test(
    'ChainSwap.newSwap rejects a mismatched key through the changed wire',
    () async {
      final key = SwapMasterKey(
        xprv: '',
        xpub: '',
        mnemonic: '',
        fingerprint: '',
        network: Network.testnet,
      );
      await expectLater(
        ChainSwap.newSwap(
          direction: ChainSwapDirection.btcToLbtc,
          swapMasterKey: key,
          index: BigInt.zero,
          amount: BigInt.from(1000),
          network: Network.regtest,
          btcElectrumUrl: 'bitcoin.example:18201',
          lbtcElectrumUrl: 'liquid.example:18202',
          boltzUrl: 'http://boltz.example:18200/custom/v2',
        ),
        throwsA(
          isA<BoltzError>()
              .having((error) => error.kind, 'kind', 'Network')
              .having(
                (error) => error.message,
                'message',
                'Swap master key network does not match the swap network',
              ),
        ),
      );
    },
  );
}
