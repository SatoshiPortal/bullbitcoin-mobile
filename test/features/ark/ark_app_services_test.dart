import 'dart:async';

import 'package:address_view/address_view.dart';
import 'package:ark/ark.dart' show ArkAccountId;
import 'package:ark/funding.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/ark_wallet_setup.dart' show WalletArkExitDestination;
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
import 'package:spend/setup.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

class _AddressView extends Mock implements AddressView {}

class _Reserved extends Mock implements ReservedAddressPort {}

class _InputReservations extends Mock implements InputReservationPort {}

class _Freezes extends Mock implements FreezeStorePort {}

class _Inventory extends Mock implements WalletInventory {}

class _Fees extends Mock implements Fees {}

class _Connections extends Mock implements WalletConnectionPort {}

class _Catalog extends Mock implements WalletCatalogPort {}

const _fastest = RelativeFee(350);
const fundingWalletId = '[00112233/84h/1h/0h]:regtest';
final fundingKey = WalletKey(
  id: fundingWalletId,
  network: BitcoinNetwork.regtest,
);
const _address = 'reserve-address';
final _amount = Sats.fromInt(42);

final class _Spend extends FakeSpend {
  final List<String> calls;
  final prepared = SpendFixtures.preparedBitcoin(
    unsignedPsbt: 'unsigned-fixture',
    fee: Sats.fromInt(1),
  );
  final signed = SpendFixtures.signedBitcoin('signed-fixture');
  SpendFailure? prepareFailure;
  SpendFailure? signFailure;
  SpendFailure? broadcastFailure;

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
    return switch (prepareFailure) {
      final failure? => Err(failure),
      null => Ok(prepared),
    };
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    calls.add('sign');
    expect(prepared, same(this.prepared));
    return switch (signFailure) {
      final failure? => Err(failure),
      null => Ok(signed),
    };
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) async {
    calls.add('broadcast');
    expect(signed, same(this.signed));
    return switch (broadcastFailure) {
      final failure? => Err(failure),
      null => const Ok((txid: 'published', guarded: true, durable: true)),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(fundingKey);
  late GetIt locator;
  late _AddressView addressView;
  late _Inventory inventory;
  late _Fees fees;
  late _Catalog catalog;
  late List<String> calls;
  late List<WalletKey> synced;
  late _Spend spend;
  late Future<ArkSourceWalletName?> Function(String) walletName;
  late Future<Result<String, ArkFailure>> Function(String, String, Sats) send;
  late Result<WalletRegistration, SecretFailure> selection;
  late bool throwDuringSync;
  late ElectrumSync electrum;
  late _Connections connections;
  late Future<void> Function()? waitForSync;
  late Future<void> Function()? waitForFee;
  late int spendLookups;

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
    locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    addressView = _AddressView();
    inventory = _Inventory();
    catalog = _Catalog();
    calls = [];
    synced = [];
    spend = _Spend(calls);
    throwDuringSync = false;
    selection = const Err(WalletRegistrationNotFoundFailure());
    fees = _Fees();
    connections = _Connections();
    electrum = ElectrumSync(
      connections: connections,
      documentsDirectory: () => throw StateError('No native store expected'),
      readRevision: (_) => throw StateError('No native revision expected'),
    );
    waitForSync = null;
    waitForFee = null;
    spendLookups = 0;
    locator
      ..registerSingleton<AddressView>(addressView)
      ..registerSingleton<WalletInventory>(inventory)
      ..registerSingleton<WalletCatalogPort>(catalog)
      ..registerSingleton(ForegroundWalletSynchronization(electrum))
      ..registerSingleton<Fees>(fees)
      ..registerLazySingleton<Spend>(() {
        spendLookups++;
        return spend;
      });
    when(() => inventory.readWallet(fundingWalletId)).thenAnswer((_) async {
      calls.add('inventory');
      return selection;
    });
    when(() => catalog.find(any())).thenAnswer((invocation) async {
      calls.add('pre-sync');
      synced.add(invocation.positionalArguments.single as WalletKey);
      await waitForSync?.call();
      if (throwDuringSync) throw const FormatException('sync unavailable');
      return const Err(SyncConnectionFailure());
    });
    when(() => fees.estimate(BitcoinNetwork.regtest)).thenAnswer((_) async {
      calls.add('regtest fee');
      await waitForFee?.call();
      return const Ok(
        FeeOptions(
          fastest: _fastest,
          economic: RelativeFee(100),
          slow: RelativeFee(50),
          minRelay: RelativeFee(25),
        ),
      );
    });
    final services = arkWalletAppServices(locator);
    walletName =
        services.walletName ?? fail('Missing Ark wallet-name callback');
    send = services.send ?? fail('Missing Ark reserve-send callback');
  });

  test('an invisible row has no name or Spend lookup', () async {
    expect(await walletName(fundingWalletId), isNull);
    expect(spendLookups, 0);
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
        expect(spendLookups, 0);
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

  test('a missing refresh row does not block an admitted Spend', () async {
    expect(await send(fundingWalletId, _address, _amount), isA<Ok>());
    expect(synced, isEmpty);
    expect(calls, ['inventory', 'regtest fee', 'prepare', 'sign', 'broadcast']);
  });

  test('unavailable Regtest fees stop before preparation', () async {
    showRow();
    when(() => fees.estimate(BitcoinNetwork.regtest)).thenAnswer((_) async {
      calls.add('regtest fee');
      return const Err(FeeEstimateUnavailableFailure());
    });
    expect(
      await send(fundingWalletId, _address, _amount),
      isA<Err<String, ArkFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ArkNetworkUnavailableFailure>(),
      ),
    );
    expect(calls, ['inventory', 'pre-sync', 'regtest fee']);
  });

  for (final (prepareFailure, signFailure, expected, extraCalls) in [
    (
      const SpendDeveloperAuthorizationFailure(),
      null,
      isA<ArkServiceUnavailableFailure>(),
      <String>[],
    ),
    (
      null,
      const SpendSigningRefusedFailure(),
      isA<ArkServiceUnavailableFailure>(),
      ['sign'],
    ),
    for (final failure in [
      const SpendInsufficientFundsFailure(),
      const SpendInsufficientFundsForFeesFailure(),
      const SpendNoSpendableInputsFailure(),
    ])
      (failure, null, isA<ArkPaymentInsufficientFundsFailure>(), <String>[]),
  ]) {
    test(
      '${prepareFailure ?? signFailure} is refused before broadcast',
      () async {
        spend.prepareFailure = prepareFailure;
        spend.signFailure = signFailure;
        final result = await send(fundingWalletId, _address, _amount);
        expect(
          result,
          isA<Err<String, ArkFailure>>().having(
            (r) => r.failure,
            'failure',
            expected,
          ),
        );
        expect(synced, isEmpty);
        expect(calls, ['inventory', 'regtest fee', 'prepare', ...extraCalls]);
      },
    );
  }

  test('an uncertain relay is reported without broadcasting again', () async {
    showRow();
    spend.broadcastFailure = const SpendBroadcastOutcomeUnknownFailure();
    expect(
      await send(fundingWalletId, _address, _amount),
      isA<Err<String, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkSubmissionUncertainFailure>(),
      ),
    );
    expect(calls, [
      'inventory',
      'pre-sync',
      'regtest fee',
      'prepare',
      'sign',
      'broadcast',
    ]);
  });

  for (final pauseDuringSync in [true, false]) {
    test(
      'Spend refuses the source revoked during ${pauseDuringSync ? 'sync' : 'fees'}',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        Future<void> pause() {
          entered.complete();
          return release.future;
        }

        showRow();
        if (pauseDuringSync) {
          waitForSync = pause;
        } else {
          waitForFee = pause;
        }
        final runtime = WalletNativeRuntime.open(
          catalog: catalog,
          reserved: _Reserved(),
          inputReservations: _InputReservations(),
          deleteCatalogEntry: (_) => throw StateError('No delete expected'),
          sync: electrum,
          documentsDirectory: () => throw StateError('No wallet may be opened'),
          freezes: _Freezes(),
          connections: connections,
        );
        addTearDown(runtime.close);
        final secrets = Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () => throw StateError('No signer may be opened'),
        );
        await locator.unregister<Spend>();
        locator.registerSingleton(
          Spend.open(
            sync: runtime,
            secrets: secrets,
            arkFunding: const ArkFundingSigningGuard(authority: null),
            catalog: SpendCatalog.fromInventory(inventory),
          ),
        );

        final pending = send(fundingWalletId, _address, _amount);
        await entered.future;
        selection = const Err(WalletRegistrationNotFoundFailure());
        release.complete();
        expect(
          await pending,
          isA<Err<String, ArkFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ArkServiceUnavailableFailure>(),
          ),
        );
        expect(calls, ['inventory', 'pre-sync', 'regtest fee', 'inventory']);
      },
    );
  }

  test(
    'the admitted account gets a fresh address from its bound source',
    () async {
      final now = DateTime.utc(2026);
      when(
        () => addressView.receiveAddress(
          walletId: fundingWalletId,
          advance: true,
        ),
      ).thenAnswer(
        (_) async => Ok(
          WalletAddress(
            walletId: fundingWalletId,
            index: 7,
            address: 'fresh-address',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
      final account = ArkAccountId(
        parent: Fingerprint('00112233'),
        network: BitcoinNetwork.regtest,
        serverIdentity: 'server',
      );
      final nextAddress = arkWalletAppServices(locator).nextReceiveAddress;
      final destination = WalletArkExitDestination(
        sourceWallet: (id) async => id == account
            ? const Ok(fundingWalletId)
            : const Err(ArkServiceUnavailableFailure()),
        nextAddress: nextAddress ?? fail('Missing Ark receive callback'),
      );
      expect(
        await destination.secureBitcoinAddress(account),
        isA<Ok<String, ArkFailure>>().having(
          (r) => r.value,
          'address',
          'fresh-address',
        ),
      );
      verify(
        () => addressView.receiveAddress(
          walletId: fundingWalletId,
          advance: true,
        ),
      ).called(1);
      expect(spendLookups, 0);
    },
  );
}
