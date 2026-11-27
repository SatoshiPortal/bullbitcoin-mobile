import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:bull_ark/ark_ui_setup.dart' show ArkDisplayData;
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_ark/bull_ark.dart'
    show ArkFailure, ArkFeatureStorageFailure;
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:sync/sync.dart';

import '../../../core_test/wallet/support/sync_spend_fixture.dart';
import '../../../core_test/wallet/support/wallet_model.dart';

// Published BIP84 account xpub, with no private fixture material.
const _xpub =
    'tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39y'
    'BA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'fixture-server',
  );
  const model = PublicBdkWalletModel(
    id: 'ark-display-order:regtest',
    network: Network.bitcoinRegtest,
    externalDescriptor: 'wpkh($_xpub/0/*)',
    internalDescriptor: 'wpkh($_xpub/1/*)',
  );

  for (final changeSource in [false, true]) {
    test(
      changeSource
          ? 'a changed selection invalidates the entire suspended display read'
          : 'a changed revision masks the amount after a suspended price read',
      () async {
        final directory = Directory.systemTemp.createTempSync('ark-display-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final order = <String>[];
        final reservations = _Reservations(order);
        final fixture = await SyncSpendFixture.open(
          directory.path,
          model,
          reservations: reservations,
        );
        addTearDown(fixture.close);
        final reachedPrice = Completer<void>();
        final finishPrice = Completer<void>();
        var hold = false;
        var selected = model.id;
        final adapter = WalletArkDisplayData(
          runtime: fixture.runtime,
          account: account,
          currencyChanges: const Stream.empty(),
          selectedSource: (_) async {
            order.add('select $selected');
            return Ok(selected);
          },
          currency: () async => 'USD',
          walletName: (_) async => null,
          isActive: () => true,
          price: ({required network, required currency}) async {
            order.add('price');
            if (hold) {
              reachedPrice.complete();
              await finishPrice.future;
            }
            return Ok(
              BitcoinPrice(
                currency: currency,
                fiatAmount: 100,
                fetchedAt: DateTime.utc(2026),
              ),
            );
          },
        );
        addTearDown(adapter.close);
        addTearDown(() {
          if (!finishPrice.isCompleted) finishPrice.complete();
        });
        // An unchanged live adapter displays a known empty balance.
        expect(
          await adapter.read(account),
          isA<Ok<ArkDisplayData, ArkFailure>>().having(
            (result) => result.value.available,
            'available',
            Sats.zero,
          ),
        );
        order.clear();
        hold = true;
        final before = _value(await fixture.runtime.readRevision(fixture.key));
        final reading = adapter.read(account);
        await reachedPrice.future;
        expect(order, ['select ${model.id}', 'reservations', 'price']);
        if (changeSource) {
          selected = 'another-wallet';
        } else {
          _value(await fixture.runtime.receive(fixture.key, advance: true));
          final after = _value(await fixture.runtime.readRevision(fixture.key));
          expect(after.stamp.generation, before.stamp.generation);
          expect(after.stamp.revision, greaterThan(before.stamp.revision));
        }
        finishPrice.complete();
        final result = await reading;
        expect(order, [
          'select ${model.id}',
          'reservations',
          'price',
          'select $selected',
        ]);
        if (changeSource) {
          expect(
            result,
            isA<Err<ArkDisplayData, ArkFailure>>().having(
              (err) => err.failure,
              'failure',
              isA<ArkFeatureStorageFailure>(),
            ),
          );
        } else {
          expect(
            result,
            isA<Ok<ArkDisplayData, ArkFailure>>()
                .having((ok) => ok.value.available, 'available', isNull)
                .having((ok) => ok.value.price, 'price', isNotNull),
          );
        }
      },
    );
  }
}

T _value<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.logCode),
};

final class _Reservations implements InputReservationPort {
  final List<String> _order;

  _Reservations(this._order);

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    _order.add('reservations');
    return const Ok([]);
  }
}
