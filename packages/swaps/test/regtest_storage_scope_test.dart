import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:rust_bindings/boltz.dart' as native;
import 'package:mocktail/mocktail.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/data/db/boltz_swaps_database.dart';
import 'package:swaps/src/data/db/drift_swap_row_store.dart';
import 'package:swaps/src/util.dart';
import 'package:test/test.dart';

const _legacy = bool.fromEnvironment('LEGACY_STORAGE_BASELINE');

class _BtcSwap extends Mock implements native.BtcLnSwap {}

class _LiquidSwap extends Mock implements native.LbtcLnSwap {}

class _ChainSwap extends Mock implements native.ChainSwap {}

class _Keychain extends ReproKeychainBackend {
  final keysRead = <String>[];
  final firstCounterRead = Completer<void>();
  final releaseCounterRead = Completer<void>();
  bool holdFirstCounterRead = false;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    keysRead.add(key);
    final snapshot = values[key];
    if (holdFirstCounterRead &&
        key.startsWith('swap_master_key_index_') &&
        !firstCounterRead.isCompleted) {
      firstCounterRead.complete();
      await releaseCounterRead.future;
    }
    return snapshot;
  }
}

SwapStorage _regtest(
  SwapStorage canonical,
  SwapRowStore rows,
  _Keychain keychain,
) {
  if (_legacy) return SwapStorage(rows: rows, secrets: keychain.capability);
  // Dynamic invocation keeps the original750 test compilable. Only the old
  // constructor selection changes; allocator code/counter/assertions are real.
  final dynamic owner = canonical;
  return owner.regtestView(rows: rows) as SwapStorage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'testnet and regtest stores share one allocation authority per fingerprint',
    () async {
      final directory = await Directory.systemTemp.createTemp('swap-scope-');
      final productionDb = BoltzSwapsDatabase(
        NativeDatabase(File('${directory.path}/production.sqlite')),
      );
      final regtestDb = BoltzSwapsDatabase(
        NativeDatabase(File('${directory.path}/regtest.sqlite')),
      );
      addTearDown(() async {
        await productionDb.close();
        await regtestDb.close();
        await directory.delete(recursive: true);
      });
      final keychain = _Keychain();
      final testnet = SwapStorage(
        rows: DriftSwapRowStore(productionDb),
        secrets: keychain.capability,
      );
      final regtest = _regtest(testnet, DriftSwapRowStore(regtestDb), keychain);
      expect(identical(testnet, regtest), isFalse);
      await testnet.setSwapKeyIndex('00000001', 0);
      keychain.holdFirstCounterRead = true;
      final oldCreateRange = testnet.reserveSwapKeyIndex('00000001', 2, 0);
      await keychain.firstCounterRead.future;
      final newCreateRange = regtest.reserveSwapKeyIndex('00000001', 1, 0);
      await pumpEventQueue();
      keychain.releaseCounterRead.complete();
      final oldStart = await oldCreateRange;
      final newStart = await newCreateRange;
      expect(
        {oldStart, oldStart + 1}.contains(newStart),
        isFalse,
        reason:
            'Distinct environment stores must never reuse a child-key range',
      );
      expect(await testnet.getSwapKeyIndex('00000001'), 3);
      expect(await regtest.getSwapKeyIndex('00000001'), 3);
      expect(
        keychain.values.keys.where(
          (key) => key.startsWith('swap_master_key_index_'),
        ),
        ['swap_master_key_index_00000001'],
      );
    },
  );

  test(
    'regtest blob reads and deletes never use the production namespace',
    () async {
      final productionDb = BoltzSwapsDatabase(NativeDatabase.memory());
      final regtestDb = BoltzSwapsDatabase(NativeDatabase.memory());
      addTearDown(productionDb.close);
      addTearDown(regtestDb.close);
      final keychain = _Keychain();
      final production = SwapStorage(
        rows: DriftSwapRowStore(productionDb),
        secrets: keychain.capability,
      );
      final regtest = _regtest(
        production,
        DriftSwapRowStore(regtestDb),
        keychain,
      );
      await expectLater(
        regtest.fetchBtcLnSwap('public-id'),
        throwsA(isA<SwapsException>()),
      );
      expect(keychain.keysRead.last, 'swap_regtest_public-id');
      keychain.values['swap_public-id'] = 'public-production-placeholder';
      keychain.values['swap_regtest_public-id'] = 'public-regtest-placeholder';
      await regtest.deleteFromSecureStorage('public-id');
      expect(
        keychain.values['swap_public-id'],
        'public-production-placeholder',
      );
      expect(keychain.values.containsKey('swap_regtest_public-id'), isFalse);
    },
  );
  test(
    'all three native blob writers use only the regtest namespace',
    () async {
      final productionDb = BoltzSwapsDatabase(NativeDatabase.memory());
      final regtestDb = BoltzSwapsDatabase(NativeDatabase.memory());
      addTearDown(productionDb.close);
      addTearDown(regtestDb.close);
      final keychain = _Keychain();
      final canonical = SwapStorage(
        rows: DriftSwapRowStore(productionDb),
        secrets: keychain.capability,
      );
      final regtest = _regtest(
        canonical,
        DriftSwapRowStore(regtestDb),
        keychain,
      );
      final btc = _BtcSwap();
      final liquid = _LiquidSwap();
      final chain = _ChainSwap();
      when(() => btc.id).thenReturn('btc');
      when(btc.toJson).thenAnswer((_) async => '{}');
      when(() => liquid.id).thenReturn('liquid');
      when(liquid.toJson).thenAnswer((_) async => '{}');
      when(() => chain.id).thenReturn('chain');
      when(chain.toJson).thenAnswer((_) async => '{}');
      await regtest.storeBtcLnSwap(btc);
      await regtest.storeLbtcLnSwap(liquid);
      await regtest.storeChainSwap(chain);
      expect(keychain.values.keys.toSet(), {
        'swap_regtest_btc',
        'swap_regtest_liquid',
        'swap_regtest_chain',
      });
    },
  );
}
