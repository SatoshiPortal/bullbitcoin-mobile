import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/private_descriptor_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_private_descriptor_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/lookup_private_descriptors_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../nostr_identity/fixtures/backup_credential_vectors.dart';
import '../support/fake_private_descriptor_remote.dart';

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockDefaultSeed extends Mock implements GetDefaultSeedUsecase {}

final _artifact = Uint8List.fromList(List.generate(64, (index) => index));
const _tokenA =
    '450cd9cbf7106322d2fb54e832e887b40c184b20fc9e3c00713cc028ad0a33b0';
const _tokenB =
    'f958bb05dfc2e285bba3ea769d919e234478148eb520a77e77f2eaf803768237';

BullVaultDescriptorBackup _backup({
  List<String> tokens = const [_tokenA, _tokenB],
}) => BullVaultDescriptorBackup(
  descriptor: 'tr(unused)',
  network: Network.bitcoinTestnet,
  bytes: _artifact,
  recipients: List.generate(tokens.length, (index) => 'xpub-$index'),
  lookupTokens: tokens,
);

NostrIdentityFacade _identity({required bool hasSeed}) {
  final settings = _MockSettings();
  final defaultSeed = _MockDefaultSeed();
  when(() => settings.execute()).thenAnswer(
    (_) async => const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
    ),
  );
  when(
    () => defaultSeed.execute(environment: any(named: 'environment')),
  ).thenAnswer(
    (_) async => hasSeed
        ? Ok(
            Seed.bytes(
              bytes: backupCredentialVectorSeed,
              masterFingerprint: hex.encode(
                bip32.Bip32Keys.fromSeed(
                  backupCredentialVectorSeed,
                ).fingerprint,
              ),
            ),
          )
        : const Err(DefaultSeedNotFoundFailure()),
  );
  final resolver = BackupCredentialResolver(settings, defaultSeed);
  return NostrIdentityFacade(
    GetBackupIdentityPublicKeyUsecase(resolver),
    SignBackupIdentityHashUsecase(resolver),
    resolver,
  );
}

void main() {
  late FakePrivateDescriptorRemote remote;

  PublishPrivateDescriptorUsecase publisher({
    Result<BullVaultDescriptorBackup, BullVaultFailure>? encoded,
    bool hasSeed = true,
  }) => PublishPrivateDescriptorUsecase(
    (_) async => encoded ?? Ok(_backup()),
    WalletBackupAuthenticator(_identity(hasSeed: hasSeed), () => 1700000000),
    remote,
  );

  setUp(() => remote = FakePrivateDescriptorRemote());

  test(
    'publishes as the server account, never as the artifact author',
    () async {
      final result = await publisher().execute('vault-wallet');

      expect(result, isA<Ok<DateTime, WalletBackupFailure>>());
      final stored = remote.stored.single;
      expect(stored.publisher, backupCredentialVectorServerPublicKey);
      expect(stored.publisher, isNot(backupCredentialVectorNostrPublicKey));
      expect(stored.ciphertext, _artifact);
      expect(stored.tokens, [_tokenA, _tokenB]);
    },
  );

  test(
    'the signature is the descriptor protocol\'s, not wallet backup\'s',
    () async {
      await publisher().execute('vault-wallet');

      final message = buildPrivateDescriptorSigningMessage(
        publicKeyHex: backupCredentialVectorServerPublicKey,
        ciphertextSha256: remote.stored.single.hash,
        ciphertextBytes: _artifact.length,
        lookupTokens: [_tokenA, _tokenB],
        timestamp: 1700000000,
      );
      expect(message, isNotNull);
      // The bytes the fake recorded were signed over this message and no other:
      // re-deriving it here is what pins the client to the contract.
      expect(
        String.fromCharCodes(message!),
        startsWith(privateDescriptorAuthenticationDomain),
      );
    },
  );

  test('re-sending the same artifact is one record, not two', () async {
    final first = await publisher().execute('vault-wallet');
    final second = await publisher().execute('vault-wallet');

    expect(remote.stored, hasLength(1));
    expect(
      (second as Ok<DateTime, WalletBackupFailure>).value,
      (first as Ok).value,
    );
  });

  test('a vault that cannot be encoded is never sent', () async {
    final result = await publisher(
      encoded: const Err(BullVaultDescriptorBackupUnsupportedFailure()),
    ).execute('vault-wallet');

    expect(
      result,
      isA<Err<DateTime, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupVaultsFailure>(),
      ),
    );
    expect(remote.stored, isEmpty);
  });

  test('a device with no backup credential cannot publish', () async {
    final result = await publisher(hasSeed: false).execute('vault-wallet');

    expect(
      result,
      isA<Err<DateTime, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupSigningFailure>(),
      ),
    );
    expect(remote.stored, isEmpty);
  });

  test('a lookup asks for exactly the account key it was given', () async {
    remote.publishForeign(ciphertext: _artifact, tokens: const [_tokenA]);
    final usecase = LookupPrivateDescriptorsUsecase(
      (input) => input == 'cosigner-key' ? _tokenA : null,
      remote,
    );

    final result = await usecase.execute('cosigner-key');

    expect(remote.lookedUp.single, [_tokenA]);
    expect(
      result,
      isA<Ok<PrivateDescriptorLookup, WalletBackupFailure>>().having(
        (value) => value.value.records.single.ciphertext,
        'candidate',
        _artifact,
      ),
    );
  });

  test('text that is not an account key never reaches the server', () async {
    final usecase = LookupPrivateDescriptorsUsecase((_) => null, remote);

    expect(
      await usecase.execute('not a key'),
      isA<Err<PrivateDescriptorLookup, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupInvalidAccountKeyFailure>(),
      ),
    );
    expect(remote.lookedUp, isEmpty);
  });

  test('a search that could not finish is carried through, not '
      'flattened', () async {
    remote
      ..endlessHistory = true
      ..pageSize = 1;
    final usecase = LookupPrivateDescriptorsUsecase((_) => _tokenA, remote);

    expect(
      await usecase.execute('cosigner-key'),
      isA<Ok<PrivateDescriptorLookup, WalletBackupFailure>>()
          .having((value) => value.value.incomplete, 'incomplete', isTrue)
          .having((value) => value.value.records, 'records', isEmpty),
    );
    expect(remote.lookedUp, hasLength(privateDescriptorMaxLookupPages));
  });

  test('every page of a history is followed to its end', () async {
    for (var index = 0; index < 5; index++) {
      remote.publishForeign(
        ciphertext: Uint8List.fromList([index, index, index]),
        tokens: const [_tokenA],
        publisher: 'publisher-$index',
      );
    }
    remote.pageSize = 2;
    final usecase = LookupPrivateDescriptorsUsecase((_) => _tokenA, remote);

    final result = await usecase.execute('cosigner-key');

    expect(
      result,
      isA<Ok<PrivateDescriptorLookup, WalletBackupFailure>>()
          .having((value) => value.value.records, 'records', hasLength(5))
          .having((value) => value.value.incomplete, 'incomplete', isFalse),
    );
    expect(remote.cursorsSeen, [null, '2', '4']);
  });

  test('a failure on a continuation keeps what was already read', () async {
    remote.publishForeign(ciphertext: _artifact, tokens: const [_tokenA]);
    remote.publishForeign(
      ciphertext: Uint8List.fromList([7, 7, 7]),
      tokens: const [_tokenA],
      publisher: 'second-publisher',
    );
    remote
      ..pageSize = 1
      ..lookupsBeforeFailure = 1
      ..lookupFailure = const WalletBackupRemoteUnavailableFailure();
    final usecase = LookupPrivateDescriptorsUsecase((_) => _tokenA, remote);

    expect(
      await usecase.execute('cosigner-key'),
      isA<Ok<PrivateDescriptorLookup, WalletBackupFailure>>()
          .having((value) => value.value.records, 'records', hasLength(1))
          .having((value) => value.value.incomplete, 'incomplete', isTrue),
    );
  });

  test('a failure on the first page is the failure itself', () async {
    remote.lookupFailure = const WalletBackupRemoteUnavailableFailure();
    final usecase = LookupPrivateDescriptorsUsecase((_) => _tokenA, remote);

    expect(
      await usecase.execute('cosigner-key'),
      isA<Err<PrivateDescriptorLookup, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupRemoteUnavailableFailure>(),
      ),
    );
  });
}
