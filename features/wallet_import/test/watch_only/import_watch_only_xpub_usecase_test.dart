import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:secrets/secrets.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';

final class _LiquidExtendedPubkey extends Fake
    implements satoshifier.ExtendedPubkey {
  @override
  satoshifier.Network get network => satoshifier.Network.liquidMainnet;
}

final class _Accounts implements WalletProvisioning {
  final List<
    ({String xpub, BitcoinNetwork network, ScriptType script, String label})
  >
  imported = [];
  final Result<void, WalletProvisioningFailure> outcome;

  _Accounts(this.outcome);

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) async {
    imported.add((
      xpub: xpub,
      network: network,
      script: scriptType,
      label: label,
    ));
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
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) async => throw UnimplementedError();
}

void main() {
  final extendedPubkey = satoshifier.ExtendedPubkey(
    pubkey: List<int>.filled(78, 0),
    derivation: satoshifier.Derivation.bip84,
    network: satoshifier.Network.bitcoinMainnet,
  );
  final entity = WatchOnlyXpubEntity(
    watchOnlyXpub: satoshifier.WatchOnlyXpub(extendedPubkey: extendedPubkey),
    label: 'My xpub wallet',
  );

  test('rejects a Liquid xpub before provisioning', () async {
    final accounts = _Accounts(const Ok(null));
    final usecase = ImportWatchOnlyXpubUsecase(accounts);
    final liquid = WatchOnlyXpubEntity(
      watchOnlyXpub: satoshifier.WatchOnlyXpub(
        extendedPubkey: _LiquidExtendedPubkey(),
      ),
      label: '',
    );
    expect(
      await usecase.execute(watchOnlyXpub: liquid),
      isA<Err<void, ImportWatchOnlyFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<InvalidFormatFailure>(),
      ),
    );
    expect(accounts.imported, isEmpty);
  });

  test('forwards the selected xpub to provisioning', () async {
    final accounts = _Accounts(const Ok(null));
    final usecase = ImportWatchOnlyXpubUsecase(accounts);
    expect(
      await usecase.execute(watchOnlyXpub: entity),
      isA<Ok<void, ImportWatchOnlyFailure>>(),
    );
    final imported = accounts.imported.single;
    expect(imported.xpub, entity.pubkey);
    expect(imported.network, BitcoinNetwork.mainnet);
    expect(imported.script, ScriptType.bip84);
    expect(imported.label, 'My xpub wallet');
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
      final usecase = ImportWatchOnlyXpubUsecase(_Accounts(Err(failure)));
      expect(
        await usecase.execute(watchOnlyXpub: entity),
        isA<Err<void, ImportWatchOnlyFailure>>().having(
          (result) => result.failure,
          'failure',
          expected,
        ),
      );
    });
  }
}
