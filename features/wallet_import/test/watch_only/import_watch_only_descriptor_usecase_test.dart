import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:secrets/secrets.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';

final class _Accounts implements WalletProvisioning {
  final List<WatchOnlyAccount> imported = [];
  final Result<void, WalletProvisioningFailure> outcome;

  _Accounts(this.outcome);

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) async {
    imported.add(account);
    return outcome;
  }

  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      throw UnimplementedError();

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) async => throw UnimplementedError();
}

WatchOnlyDescriptorEntity _descriptor(satoshifier.Network network) =>
    WatchOnlyDescriptorEntity(
      watchOnlyDescriptor: satoshifier.WatchOnlyDescriptor(
        descriptor: satoshifier.Descriptor(
          operand: satoshifier.ScriptOperand.wpkh,
          fingerprint: '86241f88',
          pubkey: 'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7',
          network: network,
          derivation: satoshifier.Derivation.bip84,
          account: 0,
        ),
      ),
    );

void main() {
  final entity = _descriptor(satoshifier.Network.bitcoinMainnet);
  test('rejects Liquid descriptors before persistence', () async {
    final accounts = _Accounts(const Ok(null));
    final usecase = ImportWatchOnlyDescriptorUsecase(accounts);
    final result = await usecase.execute(
      watchOnlyDescriptor: _descriptor(satoshifier.Network.liquidMainnet),
    );
    expect(
      result,
      isA<Err<void, ImportWatchOnlyFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<InvalidFormatFailure>(),
      ),
    );
    expect(accounts.imported, isEmpty);
  });

  test('forwards the selected descriptor to provisioning', () async {
    final accounts = _Accounts(const Ok(null));
    final usecase = ImportWatchOnlyDescriptorUsecase(accounts);
    expect(
      await usecase.execute(
        watchOnlyDescriptor: entity.copyWith(label: 'Reviewed wallet'),
      ),
      isA<Ok<void, ImportWatchOnlyFailure>>(),
    );
    final account = accounts.imported.single;
    expect(account.pubkey, entity.pubkey);
    expect(account.network, BitcoinNetwork.mainnet);
    expect(account.scriptType, ScriptType.bip84);
    expect(account.masterFingerprint, '86241f88');
    expect(account.signer, SignerEntity.remote);
    expect(account.signerDevice, isNull);
    expect(account.label, 'Reviewed wallet');
    expect(account.descriptors.external, isNotEmpty);
  });

  for (final (failure, expected) in <(WalletProvisioningFailure, Matcher)>[
    (
      const WalletProvisioningConflictFailure(),
      isA<WalletAlreadyExistsFailure>(),
    ),
    (const WalletProvisioningStorageFailure(), isA<ImportFailedFailure>()),
    (const WalletProvisioningInvalidFailure(), isA<InvalidFormatFailure>()),
    (const WalletProvisioningSecretFailure(), isA<ImportFailedFailure>()),
    (const WalletProvisioningUnsupportedFailure(), isA<ImportFailedFailure>()),
  ]) {
    test('maps ${failure.runtimeType}', () async {
      final usecase = ImportWatchOnlyDescriptorUsecase(_Accounts(Err(failure)));
      expect(
        await usecase.execute(watchOnlyDescriptor: entity),
        isA<Err<void, ImportWatchOnlyFailure>>().having(
          (result) => result.failure,
          'failure',
          expected,
        ),
      );
    });
  }
}
