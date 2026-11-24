import 'package:primitives/primitives.dart' show NetworkEnv;

import 'dart:async';

import 'package:rust_bindings/boltz.dart' as native;
import 'package:mocktail/mocktail.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

class _Storage extends Mock implements SwapStorage {}

class _BtcSwap extends Mock implements native.BtcLnSwap {}

class _LiquidSwap extends Mock implements native.LbtcLnSwap {}

class _ChainSwap extends Mock implements native.ChainSwap {}

void main() {
  const counterpartyElectrum = ElectrumConnection(
    url: 'tcp://127.0.0.1:1',
    validateDomain: false,
    timeout: 1,
  );
  final actions = <String, (String, Future<Object?> Function(BoltzDatasource))>{
    'Bitcoin claim': (
      'btc',
      (api) => api.claimBtcReverseSwap(
        swapId: 's',
        claimAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
      ),
    ),
    'Liquid claim': (
      'liquid',
      (api) => api.claimLBtcReverseSwap(
        swapId: 's',
        claimAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
      ),
    ),
    'Bitcoin refund': (
      'btc',
      (api) => api.refundBtcSubmarineSwap(
        swapId: 's',
        refundAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
      ),
    ),
    'Liquid refund': (
      'liquid',
      (api) => api.refundLbtcSubmarineSwap(
        swapId: 's',
        refundAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
      ),
    ),
    'Bitcoin cooperative sign': (
      'btc',
      (api) async {
        await api.coopSignBtcSubmarineSwap(swapId: 's');
        return null;
      },
    ),
    'Liquid cooperative sign': (
      'liquid',
      (api) async {
        await api.coopSignLbtcSubmarineSwap(swapId: 's');
        return null;
      },
    ),
    'Bitcoin to Liquid claim': (
      'chain',
      (api) => api.claimBtcToLbtcChainSwap(
        swapId: 's',
        claimLiquidAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
        counterpartyElectrum: counterpartyElectrum,
      ),
    ),
    'Liquid to Bitcoin claim': (
      'chain',
      (api) => api.claimLbtcToBtcChainSwap(
        swapId: 's',
        claimBitcoinAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
        counterpartyElectrum: counterpartyElectrum,
      ),
    ),
    'Bitcoin to Liquid refund': (
      'chain',
      (api) => api.refundBtcToLbtcChainSwap(
        swapId: 's',
        refundBitcoinAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
        counterpartyElectrum: counterpartyElectrum,
      ),
    ),
    'Liquid to Bitcoin refund': (
      'chain',
      (api) => api.refundLbtcToBtcChainSwap(
        swapId: 's',
        refundLiquidAddress: 'unused',
        absoluteFees: 1,
        tryCooperate: true,
        counterpartyElectrum: counterpartyElectrum,
      ),
    ),
  };
  for (final entry in actions.entries) {
    test(
      '${entry.key} rechecks admission after the native-store read',
      () async {
        final storage = _Storage();
        final entered = Completer<void>();
        final release = Completer<void>();
        final btc = _BtcSwap();
        final liquid = _LiquidSwap();
        final chain = _ChainSwap();
        when(() => storage.fetchBtcLnSwap('s')).thenAnswer((_) async {
          entered.complete();
          await release.future;
          return btc;
        });
        when(() => storage.fetchLbtcLnSwap('s')).thenAnswer((_) async {
          entered.complete();
          await release.future;
          return liquid;
        });
        when(() => storage.fetchChainSwap('s')).thenAnswer((_) async {
          entered.complete();
          await release.future;
          return chain;
        });
        when(() => storage.isRegtestStore).thenReturn(false);
        final api = BoltzDatasource(
          environment: NetworkEnv.testnet,
          url: 'http://127.0.0.1:1',
          boltzStore: storage,
        );
        final repository = BoltzSwapRepository(
          boltz: api,
          environment: NetworkEnv.testnet,
          electrum: ReproElectrumBackend(),
          lockupChain: ReproChainBackend(),
          newAddressFor: (_) async => throw StateError('No address needed'),
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required environment,
          }) async => 1,
          wallets: ({required environment}) async => const [],
          swapMasterKeySource: ({required environment}) async => null,
        );
        addTearDown(repository.close);
        final running = entry.value.$2(api);
        final expected = expectLater(running, throwsA(isA<SwapsBusyFailure>()));
        await entered.future;
        repository.suspendEffects();
        release.complete();
        await expected;
        verifyZeroInteractions(btc);
        verifyZeroInteractions(liquid);
        verifyZeroInteractions(chain);
      },
    );
  }
}
