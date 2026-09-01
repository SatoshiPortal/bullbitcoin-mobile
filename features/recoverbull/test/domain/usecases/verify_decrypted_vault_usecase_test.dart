import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_wallet.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_wallet_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Wallets extends Mock implements RecoverBullWalletRepository {}

RecoverBullTorRoute _route({Future<void> Function()? onClose}) =>
    RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      onClose ?? () async {},
      HttpClient(),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_route());
  });

  test(
    'only a vault for the current wallet is eligible for verification',
    () async {
      final wallets = _Wallets();
      when(
        () => wallets.getWallets(onlyBitcoin: true, onlyDefaults: true),
      ).thenAnswer(
        (_) async => [
          const RecoverBullWallet(
            id: 'wallet',
            masterFingerprint: '73c5da0a',
            network: RecoverBullNetwork.mainnet,
            isPhysicalBackupTested: false,
          ),
        ],
      );
      final usecase = VerifyDecryptedVaultUsecase(wallets);

      expect(
        await usecase.execute(
          decryptedVault: DecryptedVault(
            masterFingerprint: ' 73C5DA0A ',
            mnemonic: [...List.filled(11, 'abandon'), 'about'],
          ),
        ),
        predicate<Ok>(
          (result) => result.value == VaultVerificationResult.match,
        ),
      );
      final mismatch = await usecase.execute(
        decryptedVault: const DecryptedVault(
          masterFingerprint: '73c5da0a',
          mnemonic: [
            'legal',
            'winner',
            'thank',
            'year',
            'wave',
            'sausage',
            'worth',
            'useful',
            'legal',
            'winner',
            'thank',
            'yellow',
          ],
        ),
      );
      expect(mismatch, isA<Ok>());
      expect((mismatch as Ok).value, VaultVerificationResult.mismatch);
      final invalid = await usecase.execute(
        decryptedVault: const DecryptedVault(masterFingerprint: '73c5da0a'),
      );
      expect(invalid, isA<Err>());
    },
  );

  test('a fresh install reports that no current wallet exists', () async {
    final wallets = _Wallets();
    when(
      () => wallets.getWallets(onlyBitcoin: true, onlyDefaults: true),
    ).thenAnswer((_) async => const []);

    final result = await VerifyDecryptedVaultUsecase(wallets).execute(
      decryptedVault: DecryptedVault(
        mnemonic: [...List.filled(11, 'abandon'), 'about'],
      ),
    );

    expect(
      result,
      predicate<Ok>(
        (value) => value.value == VaultVerificationResult.noCurrentWallet,
      ),
    );
  });
}
