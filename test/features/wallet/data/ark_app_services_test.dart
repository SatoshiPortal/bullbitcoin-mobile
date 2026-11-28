import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/wallet_ark_services.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/ark_ui_setup.dart'
    show ArkDefaultSourceWallet, ArkNamedSourceWallet, ArkSourceWalletName;
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import '../../../support/wallet_registrations.dart';
import 'ark_funding_test_fixture.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Fees extends Mock implements Fees {}

class _Connections extends Mock implements WalletConnectionPort {}

class _Catalog extends Mock implements WalletCatalogPort {}

const _fastest = RelativeFee(350);
const _address = 'reserve-address';
final _amount = Sats.fromInt(42);

enum _Refusal { prepare, sign }

final class _Spend extends FakeSpend {
  final List<String> calls;
  final prepared = SpendFixtures.preparedBitcoin(
    unsignedPsbt: publicFundingPsbt,
    fee: Sats.fromInt(1),
  );
  final signed = SpendFixtures.signedBitcoin('signed-fixture');
  _Refusal? refusal;

  _Spend(this.calls);

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    calls.add('prepare');
    expect(walletId, fundingWalletId);
    expect(networkFee, _fastest);
    expect(recipients, hasLength(1));
    expect(recipients.single.address, _address);
    expect(recipients.single.amountSat, _amount);
    return refusal == _Refusal.prepare
        ? const Err(SpendDeveloperAuthorizationFailure())
        : Ok(prepared);
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    calls.add('sign');
    expect(prepared, same(this.prepared));
    return refusal == _Refusal.sign
        ? const Err(SpendSigningRefusedFailure())
        : Ok(signed);
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    calls.add('broadcast');
    expect(signed, same(this.signed));
    return const Ok((txid: 'published', guarded: true, durable: true));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(fundingKey);
  late _Inventory inventory;
  late _Catalog catalog;
  late List<String> calls;
  late List<WalletKey> synced;
  late _Spend spend;
  late Future<ArkSourceWalletName?> Function(String) walletName;
  late Future<Result<String, ArkFailure>> Function(String, String, Sats) send;
  late Result<WalletRegistration, SecretFailure> selection;
  late bool throwDuringSync;

  void showRow({
    String id = fundingWalletId,
    bool isDefault = false,
    String? label,
  }) {
    selection = Ok(
      walletRegistrationForTesting(
        id: id,
        network: BitcoinNetwork.regtest,
        isDefault: isDefault,
        label: label,
      ),
    );
  }

  setUp(() {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    inventory = _Inventory();
    catalog = _Catalog();
    calls = [];
    synced = [];
    spend = _Spend(calls);
    throwDuringSync = false;
    selection = const Err(WalletRegistrationNotFoundFailure());
    final legacy = MemoryWalletRegistrations();
    legacy.rows[fundingWalletId] = fundingMetadata.copyWith(
      networkCode: 'bitcoinMainnet',
    );
    final fees = _Fees();
    final synchronization = ForegroundWalletSynchronization(
      ElectrumSync(
        connections: _Connections(),
        documentsDirectory: () => throw StateError('No native store expected'),
        readRevision: (_) => throw StateError('No native revision expected'),
      ),
    );
    locator
      ..registerSingleton<WalletInventory>(inventory)
      ..registerSingleton<WalletRegistrations>(legacy)
      ..registerSingleton<WalletCatalogPort>(catalog)
      ..registerSingleton(synchronization)
      ..registerSingleton<Fees>(fees)
      ..registerSingleton<Spend>(spend);
    when(() => inventory.readWallet(fundingWalletId)).thenAnswer((_) async {
      calls.add('inventory');
      return selection;
    });
    when(() => catalog.find(any())).thenAnswer((invocation) async {
      calls.add('pre-sync');
      synced.add(invocation.positionalArguments.single as WalletKey);
      if (throwDuringSync) throw const FormatException('sync unavailable');
      return const Err(SyncConnectionFailure());
    });
    when(() => fees.estimate(BitcoinNetwork.regtest)).thenAnswer((_) async {
      calls.add('regtest fee');
      return const Ok(
        FeeOptions(
          fastest: _fastest,
          economic: RelativeFee(100),
          slow: RelativeFee(50),
          minRelay: RelativeFee(25),
        ),
      );
    });
    final services = walletArkAppServices(locator);
    walletName =
        services.walletName ?? fail('Missing Ark wallet-name callback');
    send = services.send ?? fail('Missing Ark reserve-send callback');
  });

  test('an invisible row ignores the legacy name', () async {
    expect(await walletName(fundingWalletId), isNull);
  });

  test(
    'default wins over a label, and a nonblank label keeps whitespace',
    () async {
      showRow(isDefault: true, label: 'custom');
      expect(await walletName(fundingWalletId), isA<ArkDefaultSourceWallet>());
      showRow(label: '  custom  ');
      expect(
        await walletName(fundingWalletId),
        isA<ArkNamedSourceWallet>().having((n) => n.name, 'name', '  custom  '),
      );
    },
  );

  test(
    'a blank label falls back to the ID without only its terminal suffix',
    () async {
      showRow(id: 'origin:regtest:segment:regtest', label: '  ');
      expect(
        await walletName(fundingWalletId),
        isA<ArkNamedSourceWallet>().having(
          (n) => n.name,
          'name',
          'origin:regtest:segment',
        ),
      );
      showRow(id: 'origin:regtest:segment');
      expect(
        await walletName(fundingWalletId),
        isA<ArkNamedSourceWallet>().having(
          (n) => n.name,
          'name',
          'origin:regtest:segment',
        ),
      );
    },
  );

  for (final failure in [
    const UnreadableWalletFailure(),
    const UseSecretFailure('access changed'),
    const FetchSecretFailure(),
  ]) {
    test(
      '${failure.runtimeType} fails rather than returning a generic name',
      () async {
        selection = Err(failure);
        await expectLater(walletName(fundingWalletId), throwsException);
      },
    );
  }

  for (final throws in [false, true]) {
    test(
      'Spend still owns reserve top-up after a pre-sync ${throws ? 'exception' : 'refusal'}',
      () async {
        expect(calls, isEmpty);
        showRow();
        throwDuringSync = throws;
        final result = await send(fundingWalletId, _address, _amount);
        expect(
          result,
          isA<Ok<String, ArkFailure>>().having(
            (r) => r.value,
            'txid',
            'published',
          ),
        );
        expect(synced, [fundingKey]);
        expect(calls, [
          'inventory',
          'pre-sync',
          'regtest fee',
          'prepare',
          'sign',
          'broadcast',
        ]);
      },
    );
  }

  for (final refusal in _Refusal.values) {
    test(
      'an invisible source cannot pre-sync and a ${refusal.name} refusal never broadcasts',
      () async {
        spend.refusal = refusal;
        expect(
          await send(fundingWalletId, _address, _amount),
          isA<Err<String, ArkFailure>>(),
        );
        expect(synced, isEmpty);
        expect(calls, [
          'inventory',
          'regtest fee',
          'prepare',
          if (refusal == _Refusal.sign) 'sign',
        ]);
      },
    );
  }
}
