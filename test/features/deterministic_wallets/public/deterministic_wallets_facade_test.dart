import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrepareDeterministicWalletsUsecase extends Mock
    implements PrepareDeterministicWalletsUsecase {}

const _spec = DeterministicWalletSpec(
  id: 'product-bitcoin',
  network: Network.bitcoinMainnet,
  scriptType: ScriptType.bip84,
  isDefault: false,
  sync: false,
);

const _request = DeterministicWalletsRequest(
  bip85Index: 100,
  bip85Alias: 'Product Wallets',
  environment: Environment.mainnet,
  walletSpecs: [_spec],
);

void main() {
  late _MockPrepareDeterministicWalletsUsecase prepareUsecase;
  late DeterministicWalletsFacade facade;

  setUp(() {
    prepareUsecase = _MockPrepareDeterministicWalletsUsecase();
    facade = DeterministicWalletsFacade(
      prepareWallets: prepareUsecase.execute,
      rollbackWallets: prepareUsecase.rollbackCreatedWallets,
    );
  });

  test('prepare forwards a typed successful result', () async {
    final prepared = _preparedWallets();
    when(
      () => prepareUsecase.execute(_request),
    ).thenAnswer((_) async => Ok(prepared));

    final result = await facade.prepare(_request);

    expect(
      result,
      isA<Ok<PreparedDeterministicWallets, DeterministicWalletFailure>>(),
    );
    expect(
      (result as Ok<PreparedDeterministicWallets, DeterministicWalletFailure>)
          .value,
      same(prepared),
    );
  });

  test('prepare forwards a typed failure without throwing', () async {
    when(() => prepareUsecase.execute(_request)).thenAnswer(
      (_) async => const Err(DeterministicWalletDerivationConflictFailure()),
    );

    final result = await facade.prepare(_request);

    expect(
      result,
      isA<Err<PreparedDeterministicWallets, DeterministicWalletFailure>>(),
    );
    expect(
      (result as Err<PreparedDeterministicWallets, DeterministicWalletFailure>)
          .failure,
      isA<DeterministicWalletDerivationConflictFailure>(),
    );
  });

  test('rollback forwards a typed result', () async {
    final prepared = _preparedWallets();
    when(
      () => prepareUsecase.rollbackCreatedWallets(prepared),
    ).thenAnswer((_) async => const Err(DeterministicWalletRollbackFailure()));

    final result = await facade.rollbackCreatedWallets(prepared);

    expect(result, isA<Err<void, DeterministicWalletFailure>>());
    expect(
      (result as Err<void, DeterministicWalletFailure>).failure,
      isA<DeterministicWalletRollbackFailure>(),
    );
  });

  test('public facade exports no secret-bearing implementation type', () {
    final source = File(
      'lib/features/deterministic_wallets/public/'
      'deterministic_wallets_facade.dart',
    ).readAsStringSync();
    final exportLines = source
        .split('\n')
        .where((line) => line.trimLeft().startsWith('export '))
        .join('\n');
    final contract = source.substring(
      source.indexOf('class DeterministicWalletsFacade'),
    );

    expect(exportLines, contains('deterministic_wallet_failure.dart'));
    expect(exportLines, contains('deterministic_wallets.dart'));
    expect(exportLines, isNot(contains('seed_material')));
    expect(exportLines, isNot(contains('repository')));
    expect(exportLines, isNot(contains('usecase')));
    expect(exportLines, isNot(contains('/data/')));

    for (final forbiddenType in [
      'Mnemonic',
      'Seed',
      'Uint8List',
      'xprv',
      'xpriv',
      'WalletMetadataModel',
    ]) {
      expect(contract, isNot(contains(forbiddenType)));
    }
  });
}

PreparedDeterministicWallets _preparedWallets() {
  return const PreparedDeterministicWallets(
    wallets: [
      PreparedDeterministicWallet(
        specId: 'product-bitcoin',
        walletId: 'wallet-id',
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        externalPublicDescriptor: 'external-descriptor',
        internalPublicDescriptor: 'internal-descriptor',
        created: true,
      ),
    ],
    derivationPath: "39'/0'/12'/100'",
    parentFingerprint: 'fedcba98',
    childSeedFingerprint: '3f635a63',
    childSeedStoredDuringAttempt: true,
  );
}
