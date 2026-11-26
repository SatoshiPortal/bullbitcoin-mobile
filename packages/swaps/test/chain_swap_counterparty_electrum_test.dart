import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:rust_bindings/boltz.dart' as native;
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

class _Storage extends Mock implements SwapStorage {}

class _ChainSwap extends Mock implements native.ChainSwap {}

const _bitcoin = ElectrumConnection(
  url: 'tcp://127.0.0.1:50000',
  validateDomain: false,
  timeout: 7,
);
const _liquid = ElectrumConnection(
  url: 'tcp://127.0.0.1:50001',
  validateDomain: true,
  timeout: 9,
);

class _Electrum extends ReproElectrumBackend {
  @override
  Future<T> run<T>({
    required bool isLiquid,
    required NetworkEnv environment,
    required Future<T> Function(ElectrumConnection) operation,
    bool Function(Object)? isTransient,
  }) => operation(isLiquid ? _liquid : _bitcoin);
}

void main() {
  for (final btcToLbtc in [true, false]) {
    final type = btcToLbtc
        ? SwapType.bitcoinToLiquid
        : SwapType.liquidToBitcoin;
    group(type.name, () {
      late BoltzSwapRepository repository;

      setUp(() {
        final storage = _Storage();
        final chain = _ChainSwap();
        when(() => storage.isRegtestStore).thenReturn(true);
        when(() => storage.fetchChainSwap('swap'))
            .thenAnswer((_) async => chain);
        when(() => chain.direction).thenReturn(
          btcToLbtc
              ? native.ChainSwapDirection.btcToLbtc
              : native.ChainSwapDirection.lbtcToBtc,
        );
        // Native swaps persist host and port, including for plaintext servers.
        when(() => chain.btcElectrumUrl).thenReturn('127.0.0.1:50000');
        when(() => chain.lbtcElectrumUrl).thenReturn('127.0.0.1:50001');

        void expectElectrum(Invocation call) {
          for (final (argument, connection) in [
            (#btcElectrumSettings, _bitcoin),
            (#lbtcElectrumSettings, _liquid),
          ]) {
            final settings =
                call.namedArguments[argument] as native.ElectrumSettings;
            expect(
              settings.tls,
              isFalse,
              reason: '${call.memberName} $argument',
            );
            expect(settings.url, connection.url);
            expect(settings.validateDomain, connection.validateDomain);
            expect(settings.timeout, connection.timeout);
          }
        }

        when(
          () => chain.claimTxSize(
            outAddress: 'address',
            tryCooperate: true,
            btcElectrumSettings: any(named: 'btcElectrumSettings'),
            lbtcElectrumSettings: any(named: 'lbtcElectrumSettings'),
          ),
        ).thenAnswer((call) async {
          expectElectrum(call);
          return BigInt.one;
        });
        when(
          () => chain.refundTxSize(
            refundAddress: 'address',
            tryCooperate: true,
            btcElectrumSettings: any(named: 'btcElectrumSettings'),
            lbtcElectrumSettings: any(named: 'lbtcElectrumSettings'),
          ),
        ).thenAnswer((call) async {
          expectElectrum(call);
          return BigInt.one;
        });
        repository = BoltzSwapRepository.connect(
          url: 'http://127.0.0.1:1',
          webSocketUrl: 'ws://127.0.0.1:1',
          storage: storage,
          environment: NetworkEnv.regtest,
          electrum: _Electrum(),
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
      });

      test('sizes a claim with configured TCP', () async {
        expect(
          await repository.getSwapClaimTxSize(
            swapId: 'swap',
            swapType: type,
            claimAddressForChainSwaps: 'address',
            electrum: btcToLbtc ? _liquid : _bitcoin,
          ),
          1,
        );
      });

      test('sizes a refund with configured TCP', () async {
        expect(
          await repository.getSwapRefundTxSize(
            swapId: 'swap',
            swapType: type,
            refundAddressForChainSwaps: 'address',
            electrum: btcToLbtc ? _bitcoin : _liquid,
          ),
          1,
        );
      });
    });
  }
}
