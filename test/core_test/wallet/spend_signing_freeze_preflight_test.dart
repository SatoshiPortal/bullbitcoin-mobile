import 'dart:io';

import 'package:ark/funding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:spend/setup.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);
  for (final network in <Network>[
    BitcoinNetwork.regtest,
    LiquidNetwork.testnet,
  ]) {
    test('a fresh freeze from another origin blocks $network signing', () async {
      final directory = Directory.systemTemp.createTempSync('signing-freezes-');
      addTearDown(() => directory.deleteSync(recursive: true));
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      );
      // Public BIP39 vector for native descriptor construction only.
      final secret = _value(
        await secrets.import(
          words: [...List.filled(11, 'abandon'), 'about'],
          language: Language.english,
        ),
      );
      final signer = secret.info.id;
      final descriptor = await _descriptor(secret, network);
      // No signing material is available once the descriptor is derived.
      final keystore = FakeSecureStoragePlatform().install();
      final catalog = _Catalog(descriptor, signer);
      final freezes = MemoryFreezeStore();
      final reservations = _Reservations();
      const connections = NoConnections();
      final runtime = WalletNativeRuntime.open(
        catalog: catalog,
        reserved: const NoReservedAddresses(),
        inputReservations: reservations,
        deleteCatalogEntry: (_) async =>
            throw StateError('Unexpected deletion'),
        sync: ElectrumSync(
          connections: connections,
          documentsDirectory: () async => throw StateError('Unexpected sync'),
          readRevision: (_) async => throw StateError('Unexpected sync'),
        ),
        documentsDirectory: () async => directory.path,
        freezes: freezes,
        connections: connections,
      );
      addTearDown(() async => _value(await runtime.close()));
      final spend = Spend.open(
        sync: runtime,
        secrets: secrets,
        arkFunding: const ArkFundingSigningGuard(authority: null),
        catalog: catalog,
      );
      final key = descriptor.key;
      _value(await runtime.initialize());
      final stamp = _value(await runtime.readRevision(key)).stamp;
      expect(_value(await runtime.readFrozenOutpoints()), isEmpty);
      final input = (txId: 'a' * 64, vout: 0);
      final built = UnsignedSpend(
        revision: stamp,
        // The policy refuses before a codec or signer gets a transaction.
        encoded: 'not-a-transaction',
        inputs: [input],
      );
      final Future<Result<Object, SpendFailure>> Function() sign =
          switch (network) {
            BitcoinNetwork() => () => spend.signBitcoin(
              prepared: SpendFixtures.preparedBitcoin(
                unsignedPsbt: built.encoded,
                fee: Sats.zero,
                native: built,
              ),
            ),
            LiquidNetwork() => () => spend.signLiquid(
              prepared: SpendFixtures.preparedLiquid(
                unsignedPset: built.encoded,
                fee: Sats.zero,
                amountSent: Sats.zero,
                native: built,
              ),
            ),
          };
      // First prove an unreadable policy stops before either downstream check.
      freezes.failure = const SyncStorageFailure();
      expect(await sign(), _failure<SpendUnavailableFailure>());
      expect(reservations.reads, 0);
      expect(keystore.reads, 0);

      freezes.failure = null;
      _value(
        await freezes.freeze([FrozenOutpoint(input, origin: 'another wallet')]),
      );
      expect(await sign(), _failure<SpendSelectedInputsUnavailableFailure>());
      expect(reservations.reads, 0);
      expect(catalog.resolves, 0);
      expect(keystore.reads, 0);
    });
  }
}

Future<PublicWalletDescriptor> _descriptor(
  Secret secret,
  Network network,
) async {
  const script = ScriptType.bip84;
  switch (network) {
    case BitcoinNetwork():
      final descriptor = _value(
        await secret.derive.descriptors.bitcoin(
          network: network,
          scriptType: script,
        ),
      );
      return BitcoinWalletDescriptor(
        key: WalletKey(id: 'freeze-proof:regtest', network: network),
        scriptType: script,
        origin: 'fixture',
        externalDescriptor: descriptor.external,
        internalDescriptor: descriptor.internal,
      );
    case LiquidNetwork():
      return LiquidWalletDescriptor(
        key: WalletKey(id: 'freeze-proof-liquid', network: network),
        scriptType: script,
        origin: 'fixture',
        combinedCtDescriptor: _value(
          await secret.derive.descriptors.liquid(network: network),
        ),
      );
  }
}

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

Matcher _failure<F extends SpendFailure>() => isA<Err<Object, SpendFailure>>()
    .having((result) => result.failure, 'failure', isA<F>());

final class _Catalog implements WalletCatalogPort, SpendCatalog {
  final PublicWalletDescriptor descriptor;
  final Fingerprint signer;
  int resolves = 0;

  _Catalog(this.descriptor, this.signer);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async =>
      key == descriptor.key ? Ok(descriptor) : const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok([descriptor]);

  @override
  Future<Result<SpendWallet, SpendFailure>> resolve(String walletId) async {
    resolves++;
    return Ok((
      key: descriptor.key,
      signer: (fingerprint: signer, scriptType: ScriptType.bip84),
    ));
  }
}

final class _Reservations implements InputReservationPort {
  int reads = 0;

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    reads++;
    return const Ok([]);
  }
}
