import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/src/domain/mainnet_bitcoin_sync_checkpoints.dart';
import 'package:transaction_sync/transaction_sync.dart';

final _now = DateTime.utc(2026, 10, 28);
const _usecase = ResolveBitcoinSyncCheckpointUsecase();

BitcoinSyncCheckpoint _resolve(
  DateTime? birthday, {
  BitcoinNetwork network = BitcoinNetwork.mainnet,
  BitcoinSyncScriptType scriptType = BitcoinSyncScriptType.segwitV0,
}) {
  return switch (_usecase.execute(
    network: network,
    scriptType: scriptType,
    birthday: birthday,
    now: _now,
  )) {
    Ok(:final value) => value,
    Err() => fail('expected a valid offline checkpoint'),
  };
}

DateTime _utc(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  test(
    'unknown and unsupported early birthdays use the exact SegWit floor',
    () {
      final checkpoint = _resolve(null);
      expect(checkpoint.height, 481823);
      expect(checkpoint.timestamp, _utc(1503539571));
      expect(
        checkpoint.blockHash,
        '000000000000000000cbeff0b533f8e1189cf09dfbebf57a8ebe349362811b80',
      );
      for (final birthday in [
        DateTime.fromMillisecondsSinceEpoch(-8640000000000000, isUtc: true),
        DateTime.utc(2009),
        DateTime.utc(2017, 8),
        DateTime.utc(2017, 8, 30),
      ]) {
        // The explicit supported-history floor is the exception to the margin.
        expect(_resolve(birthday), checkpoint);
      }
    },
  );

  for (final scriptType in BitcoinSyncScriptType.values) {
    test('$scriptType uses its exact floor for unknown and earlier dates', () {
      expect(_resolve(null, scriptType: scriptType), scriptType.floor);
      for (final birthday in [DateTime.utc(2009), scriptType.earliestDate]) {
        expect(_resolve(birthday, scriptType: scriptType), scriptType.floor);
      }
      for (final network in BitcoinNetwork.values.where((n) => !n.isMainnet)) {
        expect(
          _resolve(null, scriptType: scriptType, network: network),
          BitcoinSyncCheckpoint.genesis(network),
        );
      }
    });
    test(
      '$scriptType never moves backwards across activation and catalogue',
      () {
        var previous = scriptType.floor.height;
        for (
          var date = DateTime.utc(2012);
          !date.isAfter(_now);
          date = date.add(const Duration(days: 1))
        ) {
          final checkpoint = _resolve(date, scriptType: scriptType);
          expect(checkpoint.height, greaterThanOrEqualTo(previous));
          if (checkpoint != scriptType.floor) {
            expect(
              checkpoint.timestamp?.isBefore(
                date.subtract(const Duration(days: 7)),
              ),
              isTrue,
            );
          }
          previous = checkpoint.height;
        }
      },
    );
  }

  test(
    'descriptor output scripts determine the floor rather than key paths',
    () {
      for (final descriptor in [
        'wpkh(key)',
        'sh(wpkh(key))',
        'wsh(multi(keys))',
        'sh(wsh(multi(keys)))',
      ]) {
        expect(
          BitcoinSyncScriptType.fromDescriptor(descriptor),
          BitcoinSyncScriptType.segwitV0,
        );
      }
      expect(
        BitcoinSyncScriptType.fromDescriptor('tr([12345678/84h]key)'),
        BitcoinSyncScriptType.taproot,
      );
      for (final descriptor in ['pkh(key)', 'sh(multi(keys))', 'raw(script)']) {
        expect(
          BitcoinSyncScriptType.fromDescriptor(descriptor),
          BitcoinSyncScriptType.preSegwit,
        );
      }
      expect(
        BitcoinSyncScriptType.fromScriptType(ScriptType.bip44),
        BitcoinSyncScriptType.preSegwit,
      );
      expect(
        BitcoinSyncScriptType.fromScriptType(ScriptType.bip49),
        BitcoinSyncScriptType.segwitV0,
      );
      expect(
        BitcoinSyncScriptType.fromScriptType(ScriptType.bip84),
        BitcoinSyncScriptType.segwitV0,
      );
    },
  );

  test('known 2015 legacy birthday avoids the earlier HD-wallet history', () {
    final checkpoint = _resolve(
      DateTime.utc(2015, 6),
      scriptType: BitcoinSyncScriptType.preSegwit,
    );
    expect(checkpoint.height, greaterThan(BitcoinSyncCheckpoint.bip32.height));
    expect(checkpoint.timestamp?.year, 2015);
    expect(checkpoint.timestamp?.month, 4);
  });

  test(
    'catalogue entries are exact, monotonic and strictly before their dates',
    () {
      expect(mainnetBitcoinSyncCheckpoints, hasLength(177));
      expect(
        _utc(mainnetBitcoinSyncCheckpoints.first.cutoffTimestamp),
        DateTime.utc(2012, 2),
      );
      expect(
        _utc(mainnetBitcoinSyncCheckpoints.last.cutoffTimestamp),
        DateTime.utc(2026, 10),
      );
      expect(mainnetBitcoinSyncCheckpoints.first.height, 164780);
      expect(mainnetBitcoinSyncCheckpoints.last.height, 969369);
      var previousHeight = 0;
      var previousTimestamp = 0;
      var previousMonth = DateTime.utc(2012, 1);
      final hashes = <String>{};
      for (final entry in mainnetBitcoinSyncCheckpoints) {
        expect(entry.height, greaterThan(previousHeight));
        expect(entry.blockTimestamp, greaterThan(previousTimestamp));
        expect(entry.blockTimestamp, lessThan(entry.cutoffTimestamp));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.blockHash), isTrue);
        expect(hashes.add(entry.blockHash), isTrue);
        final month = _utc(entry.cutoffTimestamp);
        expect(
          month,
          DateTime.utc(previousMonth.year, previousMonth.month + 1),
        );
        previousHeight = entry.height;
        previousTimestamp = entry.blockTimestamp;
        previousMonth = month;
      }
      final latestEligibleMonth = _now.subtract(const Duration(days: 14));
      expect(previousMonth.isAfter(latestEligibleMonth), isFalse);
      expect(
        DateTime.utc(
          previousMonth.year,
          previousMonth.month + 1,
        ).isAfter(latestEligibleMonth),
        isTrue,
      );
    },
  );

  for (final (index, entry) in mainnetBitcoinSyncCheckpoints.indexed) {
    test('exact seven-day boundary for cutoff ${entry.cutoffTimestamp}', () {
      final boundary = _utc(entry.cutoffTimestamp).add(const Duration(days: 7));
      final expected = BitcoinSyncCheckpoint(
        height: entry.height,
        blockHash: entry.blockHash,
      );
      BitcoinSyncCheckpoint resolve(DateTime date) =>
          _resolve(date, scriptType: BitcoinSyncScriptType.preSegwit);
      expect(resolve(boundary), expected);
      expect(resolve(boundary).timestamp, _utc(entry.blockTimestamp));
      expect(
        resolve(boundary.add(const Duration(hours: 23, minutes: 59))),
        expected,
      );
      final before = resolve(
        boundary.subtract(const Duration(microseconds: 1)),
      );
      expect(
        before,
        index == 0
            ? BitcoinSyncCheckpoint.bip32
            : BitcoinSyncCheckpoint(
                height: mainnetBitcoinSyncCheckpoints[index - 1].height,
                blockHash: mainnetBitcoinSyncCheckpoints[index - 1].blockHash,
              ),
      );
    });
  }

  test(
    'all supported daily birthdays have at least a strict week of margin',
    () {
      final timestamps = {
        BitcoinSyncCheckpoint.segwit.blockHash: 1503539571,
        for (final entry in mainnetBitcoinSyncCheckpoints)
          entry.blockHash: entry.blockTimestamp,
      };
      for (
        var birthday = DateTime.utc(2017, 9);
        !birthday.isAfter(_now);
        birthday = birthday.add(const Duration(days: 1))
      ) {
        final checkpoint = _resolve(birthday);
        final seconds = timestamps[checkpoint.blockHash];
        expect(seconds, isNotNull);
        if (seconds case final timestamp?) {
          expect(
            _utc(
              timestamp,
            ).isBefore(birthday.subtract(const Duration(days: 7))),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'selected heights never decrease, including the early fallback boundary',
    () {
      var previous = BitcoinSyncCheckpoint.segwit.height;
      for (
        var birthday = DateTime.utc(2009);
        !birthday.isAfter(_now);
        birthday = birthday.add(const Duration(days: 1))
      ) {
        final checkpoint = _resolve(birthday);
        expect(checkpoint.height, greaterThanOrEqualTo(previous));
        previous = checkpoint.height;
      }
    },
  );

  test('normalizes offsets before rounding down to the UTC birthday day', () {
    final previousMonth =
        mainnetBitcoinSyncCheckpoints[mainnetBitcoinSyncCheckpoints.length - 2];
    expect(
      _resolve(DateTime.parse('2026-10-08T00:30:00+02:00')).height,
      previousMonth.height,
    );
    expect(
      _resolve(DateTime.parse('2026-10-08T00:30:00-02:00')).height,
      mainnetBitcoinSyncCheckpoints.last.height,
    );
    expect(
      _resolve(DateTime.parse('2026-10-08T00:30:00+02:00')),
      _resolve(DateTime.parse('2026-10-07T22:30:00Z')),
    );
  });

  const genesisHashes = {
    BitcoinNetwork.testnet:
        '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
    BitcoinNetwork.signet:
        '00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6',
    BitcoinNetwork.regtest:
        '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
  };
  for (final MapEntry(key: network, value: hash) in genesisHashes.entries) {
    test('$network always uses its own genesis for valid or unknown dates', () {
      for (final birthday in [null, DateTime.utc(2009), _now]) {
        final checkpoint = _resolve(birthday, network: network);
        expect(checkpoint.height, 0);
        expect(checkpoint.timestamp, isNotNull);
        expect(checkpoint.blockHash, hash);
        expect(checkpoint, isNot(BitcoinSyncCheckpoint.segwit));
      }
    });
  }

  for (final network in BitcoinNetwork.values) {
    test('clamps a stored future birthday to now on $network', () {
      for (final birthday in [
        _now.add(const Duration(microseconds: 1)),
        DateTime.utc(2027),
      ]) {
        expect(
          _resolve(birthday, network: network),
          _resolve(_now, network: network),
        );
      }
    });
  }

  test('checkpoint values reject invalid heights or hashes', () {
    final hash = BitcoinSyncCheckpoint.segwit.blockHash;
    expect(
      () => BitcoinSyncCheckpoint(height: -1, blockHash: hash),
      throwsArgumentError,
    );
    expect(
      () => BitcoinSyncCheckpoint(height: 1, blockHash: 'invalid'),
      throwsArgumentError,
    );
    expect(
      BitcoinSyncCheckpoint(height: 481823, blockHash: hash),
      BitcoinSyncCheckpoint.segwit,
    );
  });
}
