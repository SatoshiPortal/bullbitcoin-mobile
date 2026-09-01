import 'dart:convert';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('passes an initial remote failure to the shared apply owner', () async {
    Result<WalletBackupSnapshot?, WalletBackupFailure>? applied;
    final usecase = RecoverWalletBackupUsecase(
      fetchImport: (_) async => const Ok(null),
      fetchRemote: () async =>
          const Err(WalletBackupRemoteUnavailableFailure()),
      apply:
          ({
            required snapshot,
            revalidate,
            defaultCreatedWalletIds = const {},
            callerSettlesFence = false,
            deadline,
          }) async {
            applied = snapshot;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.unavailable,
            );
          },
    );

    final result = await usecase.execute();

    expect(result.status, WalletBackupRecoveryStatus.unavailable);
    expect(applied, isA<Err>());
  });

  test('validates the same remote object after applying', () async {
    var fetches = 0;
    bool? unchanged;
    final head = WalletBackupRemoteHead.absent(generation: 0, etag: null);
    final usecase = RecoverWalletBackupUsecase(
      fetchImport: (_) async => const Ok(null),
      fetchRemote: () async {
        fetches++;
        return Ok(head);
      },
      apply:
          ({
            required snapshot,
            revalidate,
            defaultCreatedWalletIds = const {},
            callerSettlesFence = false,
            deadline,
          }) async {
            unchanged = switch (await revalidate!()) {
              Ok(:final value) => value,
              Err() => false,
            };
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.noBackup,
            );
          },
    );

    await usecase.execute();

    expect(fetches, 2);
    expect(unchanged, isTrue);
  });

  test('an object that appeared where there was none is a change', () async {
    var fetches = 0;

    final unchanged = await _revalidated(() {
      fetches++;
      return WalletBackupRemoteHead.absent(
        generation: fetches - 1,
        etag: fetches == 1 ? null : _etag,
      );
    });

    expect(unchanged, isFalse);
  });

  // The three cases below run on two real checkpoints, which is the only way
  // sameObjectAs gets to compare a generation or a ciphertext hash at all: an
  // absent head carries a null one and short-circuits before either.
  test('the same stored object passes revalidation', () async {
    final unchanged = await _revalidated(
      () => _present(generation: 4, ciphertextSha256: _contents),
    );

    expect(unchanged, isTrue);
  });

  test('a new generation of the same bytes is a change', () async {
    var fetches = 0;

    final unchanged = await _revalidated(() {
      fetches++;
      return _present(generation: fetches, ciphertextSha256: _contents);
    });

    expect(unchanged, isFalse);
  });

  test('new bytes under the same generation are a change', () async {
    var fetches = 0;

    final unchanged = await _revalidated(() {
      fetches++;
      return _present(
        generation: 4,
        ciphertextSha256: fetches == 1 ? _contents : _otherContents,
      );
    });

    expect(unchanged, isFalse);
  });
}

/// Runs one recovery over [head] — called once for the initial fetch and again
/// for the revalidation — and reports what the apply owner was told.
Future<bool?> _revalidated(WalletBackupRemoteHead Function() head) async {
  bool? unchanged;
  final usecase = RecoverWalletBackupUsecase(
    fetchImport: (_) async => const Ok(null),
    fetchRemote: () async => Ok(head()),
    apply:
        ({
          required snapshot,
          revalidate,
          defaultCreatedWalletIds = const {},
          callerSettlesFence = false,
          deadline,
        }) async {
          unchanged = switch (await revalidate!()) {
            Ok(:final value) => value,
            Err() => false,
          };
          return const WalletBackupRecoveryResult(
            status: WalletBackupRecoveryStatus.conflict,
          );
        },
  );

  await usecase.execute();
  return unchanged;
}

WalletBackupRemoteHead _present({
  required int generation,
  required String ciphertextSha256,
}) => WalletBackupRemoteHead.present(
  generation: generation,
  etag: _etag,
  ciphertext: _ciphertext,
  ciphertextSha256: ciphertextSha256,
);

final _ciphertext = WalletBackupCiphertext(base64.encode(List.filled(64, 7)));

const _etag =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _contents =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _otherContents =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
