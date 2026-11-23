import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:send/src/payment/domain/usecases/load_send_sources_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show WalletInventory, WalletSigner, WalletRegistrationNotFoundFailure;
import 'package:secrets/testing.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:sync/sync.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

void main() {
  final inventory = _Inventory();
  final environment = _Environment();
  final wallet = walletRegistrationForTesting(
    id: 'bitcoin-wallet',
    network: BitcoinNetwork.regtest,
    signer: WalletSigner.none,
  );
  final key = WalletKey(id: wallet.id, network: wallet.network);
  var deviceAvailable = true;
  final loads = <WalletKey>[];
  final syncs = <WalletKey>[];
  final usecase = LoadSendSourcesUsecase(
    inventory,
    (key) async {
      loads.add(key);
      return const Err(SyncBusyFailure());
    },
    (id) async => deviceAvailable
        ? const Ok<SignerDevice?, Failure>(null)
        : const Err<SignerDevice?, Failure>(SyncStorageFailure()),
    environment,
    synchronize: (key) async {
      syncs.add(key);
      return const Ok(null);
    },
    finished: const Stream.empty(),
  );

  setUp(() {
    deviceAvailable = true;
    loads.clear();
    syncs.clear();
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.regtest));
    when(() => inventory.readWallet(wallet.id))
        .thenAnswer((_) async => Ok(wallet));
    when(() => inventory.walletsForNetwork(BitcoinNetwork.regtest))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([wallet])));
    when(() => inventory.walletsForNetwork(LiquidNetwork.regtest))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
  });

  test(
    'keeps an unavailable balance unknown and a watch-only source unsigned',
    () async {
      final result = await usecase.execute();
      final source = (result as Ok<List<SendSource>, SendFailure>).value.single;
      expect(source.balanceSat, isNull);
      expect(source.isWatchOnly, isTrue);
      expect(source.signsLocally, isFalse);
      expect(loads, [key]);
      expect(syncs, isEmpty);
    },
  );

  test('refuses a partial inventory before loading balances', () async {
    when(() => inventory.walletsForNetwork(BitcoinNetwork.regtest)).thenAnswer(
      (_) async => Ok(walletSelectionForTesting([wallet], isComplete: false)),
    );
    expect(await usecase.execute(), isA<Err<List<SendSource>, SendFailure>>());
    expect(loads, isEmpty);
  });

  test('a signer device lookup failure refuses the source', () async {
    deviceAvailable = false;
    expect(await usecase.read(wallet.id), isA<Err<SendSource?, SendFailure>>());
    expect(loads, isEmpty);
  });

  test(
    'a forced refresh synchronizes the exact key and requires a balance',
    () async {
      expect(
        await usecase.read(wallet.id, sync: true),
        isA<Err<SendSource?, SendFailure>>(),
      );
      expect(syncs, [key]);
      expect(loads, [key]);
    },
  );

  test(
    'uses the registered account origin when the descriptor omits its path',
    () {
      final registration = walletRegistrationForTesting(
        id: 'wpkh([aabbccdd/84h/1h/7h])',
        network: BitcoinNetwork.testnet,
        signer: WalletSigner.remote,
      );
      final source = SendSource(registration, null, SignerDevice.ledgerNanoX);
      expect(source.derivationPath, "m/84'/1'/7'");
      expect(source.signsLocally, isFalse);
    },
  );

  test('distinguishes a deleted wallet from a read failure', () async {
    when(
      () => inventory.readWallet(wallet.id),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    final result = await usecase.read(wallet.id);
    expect((result as Ok<SendSource?, SendFailure>).value, isNull);
    expect(loads, isEmpty);
  });
}
