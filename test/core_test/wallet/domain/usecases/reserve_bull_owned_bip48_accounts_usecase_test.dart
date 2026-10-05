import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bull_owned_bip48_accounts_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final class _AccountRepository implements Bip48AccountRepository {
  final List<int> reservedAccounts = [];

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claim({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) => throw UnimplementedError();

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claimNext({
    required String seedFingerprint,
    required int coinType,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> commitClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) => throw UnimplementedError();

  @override
  Future<Result<bool, Bip48AccountAllocationFailure>> isReserved({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) => throw UnimplementedError();

  @override
  Future<Result<int, Bip48AccountAllocationFailure>> nextAvailable({
    required String seedFingerprint,
    required int coinType,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> reserve({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async {
    reservedAccounts.add(account);
    return const Ok(null);
  }

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> releaseClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) => throw UnimplementedError();
}

final class _SeedVerification implements SeedVerificationPort {
  final bool matches;

  const _SeedVerification(this.matches);

  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) async => matches;
}

void main() {
  test('reserves only verified local BIP48 accounts', () async {
    final repository = _AccountRepository();
    final usecase = ReserveBullOwnedBip48AccountsUsecase(
      repository,
      const _SeedVerification(true),
    );

    final result = await usecase.execute(
      network: Network.bitcoinMainnet,
      signers: [_signer(account: 100, signer: SignerEntity.local)],
    );

    expect(result, isA<Ok<void, Bip48AccountAllocationFailure>>());
    expect(repository.reservedAccounts, [100]);
  });

  test('does not reserve an account whose xpub is not seed-owned', () async {
    final repository = _AccountRepository();
    final usecase = ReserveBullOwnedBip48AccountsUsecase(
      repository,
      const _SeedVerification(false),
    );

    final result = await usecase.execute(
      network: Network.bitcoinMainnet,
      signers: [_signer(account: 3, signer: SignerEntity.local)],
    );

    expect(result, isA<Err<void, Bip48AccountAllocationFailure>>());
    expect(repository.reservedAccounts, isEmpty);
  });

  test(
    'reserves a remote signer account verified against the Bull seed',
    () async {
      final repository = _AccountRepository();
      final usecase = ReserveBullOwnedBip48AccountsUsecase(
        repository,
        const _SeedVerification(true),
      );

      final result = await usecase.execute(
        network: Network.bitcoinMainnet,
        signers: [_signer(account: 3, signer: SignerEntity.remote)],
      );

      expect(result, isA<Ok<void, Bip48AccountAllocationFailure>>());
      expect(repository.reservedAccounts, [3]);
    },
  );

  test('ignores a remote signer account not owned by the Bull seed', () async {
    final repository = _AccountRepository();
    final usecase = ReserveBullOwnedBip48AccountsUsecase(
      repository,
      const _SeedVerification(false),
    );

    final result = await usecase.execute(
      network: Network.bitcoinMainnet,
      signers: [_signer(account: 3, signer: SignerEntity.remote)],
    );

    expect(result, isA<Ok<void, Bip48AccountAllocationFailure>>());
    expect(repository.reservedAccounts, isEmpty);
  });
}

WalletSigner _signer({required int account, required SignerEntity signer}) =>
    WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'cafebabe',
      xpub: 'xpub-account-$account',
      derivationPath: "m/48'/0'/$account'/2'",
      signer: signer,
      signerDevice: null,
    );
