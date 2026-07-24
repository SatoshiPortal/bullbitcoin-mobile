import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

WalletMetadataModel _buildModel({
  BitcoinSyncBackend bitcoinSyncBackend = BitcoinSyncBackend.electrum,
  int lastReceiveAddressIndex = 0,
}) {
  return WalletMetadataModel(
    id: '[abcdef12/84h/0h/0h]',
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    bitcoinSyncBackend: bitcoinSyncBackend,
    lastReceiveAddressIndex: lastReceiveAddressIndex,
  );
}

WalletMetadataRow _buildRow({
  BitcoinSyncBackend bitcoinSyncBackend = BitcoinSyncBackend.electrum,
  int lastReceiveAddressIndex = 0,
}) {
  return WalletMetadataRow(
    id: '[abcdef12/84h/0h/0h]',
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local.name,
    isDefault: false,
    bitcoinSyncBackend: bitcoinSyncBackend,
    lastReceiveAddressIndex: lastReceiveAddressIndex,
  );
}

void main() {
  group('WalletMetadataModel.bitcoinSyncBackend', () {
    test('defaults to electrum when not specified', () {
      final model = _buildModel();

      expect(model.bitcoinSyncBackend, BitcoinSyncBackend.electrum);
    });

    test('toSqlite carries the electrum backend through', () {
      final model = _buildModel();

      final companion = model.toSqlite();

      expect(
        companion.bitcoinSyncBackend,
        const Value(BitcoinSyncBackend.electrum),
      );
    });

    test('toSqlite carries the compactBlockFilters backend through', () {
      final model = _buildModel(
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final companion = model.toSqlite();

      expect(
        companion.bitcoinSyncBackend,
        const Value(BitcoinSyncBackend.compactBlockFilters),
      );
    });

    test('fromSqlite reads the persisted backend back off the row', () {
      final row = _buildRow(
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final model = WalletMetadataModelMapper.fromSqlite(row);

      expect(model.bitcoinSyncBackend, BitcoinSyncBackend.compactBlockFilters);
    });

    test('round-trips through toSqlite/fromSqlite for every backend value', () {
      for (final backend in BitcoinSyncBackend.values) {
        final model = _buildModel(bitcoinSyncBackend: backend);

        final companion = model.toSqlite();
        final row = _buildRow(bitcoinSyncBackend: backend);
        final roundTripped = WalletMetadataModelMapper.fromSqlite(row);

        expect(companion.bitcoinSyncBackend.value, backend);
        expect(roundTripped.bitcoinSyncBackend, backend);
      }
    });
  });

  group('WalletMetadataModel.lastReceiveAddressIndex', () {
    test('defaults to 0 when not specified', () {
      final model = _buildModel();

      expect(model.lastReceiveAddressIndex, 0);
    });

    test('toSqlite carries the index through', () {
      final model = _buildModel(lastReceiveAddressIndex: 42);

      final companion = model.toSqlite();

      expect(companion.lastReceiveAddressIndex, const Value(42));
    });

    test('fromSqlite reads the persisted index back off the row', () {
      final row = _buildRow(lastReceiveAddressIndex: 42);

      final model = WalletMetadataModelMapper.fromSqlite(row);

      expect(model.lastReceiveAddressIndex, 42);
    });

    test(
      'round-trips through toSqlite/fromSqlite for zero and non-zero indices',
      () {
        for (final index in [0, 1, 7, 2147483647]) {
          final model = _buildModel(lastReceiveAddressIndex: index);

          final companion = model.toSqlite();
          final row = _buildRow(lastReceiveAddressIndex: index);
          final roundTripped = WalletMetadataModelMapper.fromSqlite(row);

          expect(companion.lastReceiveAddressIndex.value, index);
          expect(roundTripped.lastReceiveAddressIndex, index);
        }
      },
    );
  });

  group('WalletMetadataModel.birthdayCheckpoint', () {
    final checkpoint = WalletBirthdayCheckpoint(
      requestedBirthday: DateTime.utc(2026),
      blockTimestamp: DateTime.utc(2026),
      blockHeight: 900000,
      blockHash: 'a' * 64,
    );

    test('is null when birthday is unset', () {
      final model = _buildModel();

      expect(model.birthdayCheckpoint, isNull);
    });

    test('is null when birthday is set but no block field has been resolved '
        'yet', () {
      final model = _buildModel().copyWith(birthday: DateTime.utc(2026));

      expect(model.birthdayCheckpoint, isNull);
    });

    test('is null when only some of the three block fields are set (the '
        'all-or-none invariant)', () {
      final model = _buildModel().copyWith(
        birthday: DateTime.utc(2026),
        birthdayBlockTimestamp: DateTime.utc(2026),
        birthdayBlockHeight: 900000,
        // birthdayBlockHash intentionally left unset.
      );

      expect(model.birthdayCheckpoint, isNull);
    });

    test('is still null when all three block fields are set but birthday '
        'itself is unset — birthday is part of the all-or-none read too', () {
      final model = _buildModel().copyWithBirthdayCheckpoint(checkpoint);

      expect(model.birthdayCheckpoint, isNull);
    });

    test(
      'copyWithBirthdayCheckpoint sets the three block fields atomically',
      () {
        final model = _buildModel()
            .copyWith(birthday: checkpoint.requestedBirthday)
            .copyWithBirthdayCheckpoint(checkpoint);

        expect(model.birthdayCheckpoint, checkpoint);
        expect(model.birthdayBlockTimestamp, checkpoint.blockTimestamp);
        expect(model.birthdayBlockHeight, checkpoint.blockHeight);
        expect(model.birthdayBlockHash, checkpoint.blockHash);
      },
    );

    test('round-trips through toSqlite/fromSqlite', () {
      final model = _buildModel()
          .copyWith(birthday: checkpoint.requestedBirthday)
          .copyWithBirthdayCheckpoint(checkpoint);

      final companion = model.toSqlite();
      expect(
        companion.birthdayBlockTimestamp,
        Value(checkpoint.blockTimestamp),
      );
      expect(companion.birthdayBlockHeight, Value(checkpoint.blockHeight));
      expect(companion.birthdayBlockHash, Value(checkpoint.blockHash));

      final row = _buildRow().copyWith(
        birthday: Value(checkpoint.requestedBirthday),
        birthdayBlockTimestamp: Value(checkpoint.blockTimestamp),
        birthdayBlockHeight: Value(checkpoint.blockHeight),
        birthdayBlockHash: Value(checkpoint.blockHash),
      );
      final roundTripped = WalletMetadataModelMapper.fromSqlite(row);

      expect(roundTripped.birthdayCheckpoint, checkpoint);
    });
  });
}
