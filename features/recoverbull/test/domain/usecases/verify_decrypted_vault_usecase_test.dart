import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_wallet.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_wallet_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_settings_port.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Wallets extends Mock implements RecoverBullWalletRepository {}

class _Settings extends Mock implements RecoverBullSettingsPort {}

_Settings _settingsOn(RecoverBullNetwork network) {
  final settings = _Settings();
  when(settings.fetchNetwork).thenAnswer((_) async => network);
  return settings;
}

_Settings _mainnetSettings() => _settingsOn(RecoverBullNetwork.mainnet);

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
        () => wallets.getWallets(
          onlyBitcoin: true,
          onlyDefaults: true,
          network: any(named: 'network'),
        ),
      ).thenAnswer(
        (_) async => Ok([
          const RecoverBullWallet(
            id: 'wallet',
            masterFingerprint: '73c5da0a',
            network: RecoverBullNetwork.mainnet,
            isPhysicalBackupTested: false,
          ),
        ]),
      );
      final usecase = VerifyDecryptedVaultUsecase(wallets, _mainnetSettings());

      expect(
        await usecase.execute(
          decryptedVault: DecryptedVault(
            masterFingerprint: ' 73C5DA0A ',
            mnemonic: [...List.filled(11, 'abandon'), 'about'],
          ),
        ),
        predicate<Ok>(
          (result) =>
              result.value ==
              (
                result: VaultVerificationResult.match,
                network: RecoverBullNetwork.mainnet,
              ),
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
      expect((mismatch as Ok).value, (
        result: VaultVerificationResult.mismatch,
        network: null,
      ));
      final invalid = await usecase.execute(
        decryptedVault: const DecryptedVault(masterFingerprint: '73c5da0a'),
      );
      expect(invalid, isA<Err>());
    },
  );

  test('a fresh install reports that no current wallet exists', () async {
    final wallets = _Wallets();
    when(
      () => wallets.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        network: any(named: 'network'),
      ),
    ).thenAnswer((_) async => const Ok([]));

    final result =
        await VerifyDecryptedVaultUsecase(wallets, _mainnetSettings()).execute(
          decryptedVault: DecryptedVault(
            mnemonic: [...List.filled(11, 'abandon'), 'about'],
          ),
        );

    expect(
      result,
      predicate<Ok>(
        (value) =>
            value.value ==
            (result: VaultVerificationResult.noCurrentWallet, network: null),
      ),
    );
  });
  test('wallet read failure never reports a fresh install', () async {
    final wallets = _Wallets();
    const failure = RecoverBullUnexpectedFailure('Could not read the wallets');
    when(
      () => wallets.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        network: any(named: 'network'),
      ),
    ).thenAnswer((_) async => const Err(failure));
    final result =
        await VerifyDecryptedVaultUsecase(wallets, _mainnetSettings()).execute(
          decryptedVault: DecryptedVault(
            mnemonic: [...List.filled(11, 'abandon'), 'about'],
          ),
        );
    expect((result as Err).failure, same(failure));
  });

  test('in testnet mode verifies against the testnet default wallet even '
      'when a mainnet default wallet exists', () async {
    const mainnetWallet = RecoverBullWallet(
      id: 'mainnet-wallet',
      masterFingerprint: 'aaaaaaaa',
      network: RecoverBullNetwork.mainnet,
      isPhysicalBackupTested: false,
    );
    const testnetWallet = RecoverBullWallet(
      id: 'testnet-wallet',
      masterFingerprint: '73c5da0a',
      network: RecoverBullNetwork.testnet,
      isPhysicalBackupTested: false,
    );
    final wallets = _Wallets();
    // Behaves like the real wallet repository: a network narrows the list.
    when(
      () => wallets.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        network: any(named: 'network'),
      ),
    ).thenAnswer((invocation) async {
      final network = invocation.namedArguments[#network];
      return Ok([
        for (final candidate in [mainnetWallet, testnetWallet])
          if (network == null || candidate.network == network) candidate,
      ]);
    });

    final result =
        await VerifyDecryptedVaultUsecase(
          wallets,
          _settingsOn(RecoverBullNetwork.testnet),
        ).execute(
          decryptedVault: DecryptedVault(
            mnemonic: [...List.filled(11, 'abandon'), 'about'],
          ),
        );

    expect((result as Ok).value, (
      result: VaultVerificationResult.match,
      network: RecoverBullNetwork.testnet,
    ));
  });
}
