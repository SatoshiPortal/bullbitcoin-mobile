import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/sqlite_ark_funding_reservations.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

// Synthetic public PSBT; no key or cryptographically valid signature fixture.
const publicFundingPsbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
const fundingWalletId = '[00112233/84h/1h/0h]:regtest';
const fundingMetadata = WalletMetadataModel(
  id: fundingWalletId,
  networkCode: 'bitcoinRegtest',
  masterFingerprint: '00112233',
  xpubFingerprint: '00112233',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public-test-metadata',
  externalPublicDescriptor: 'public-external',
  internalPublicDescriptor: 'public-internal',
  signer: Signer.local,
  isDefault: true,
);
WalletKey get fundingKey =>
    WalletKey(id: fundingWalletId, network: BitcoinNetwork.regtest);
WalletRevision get fundingStamp =>
    WalletRevision(key: fundingKey, generation: 1, revision: 1);
T sourceOk<T>(Result<T, SyncFailure> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Unexpected ${failure.runtimeType}'),
};

final class FundingFixture {
  final Directory directory;
  final SqliteArkFundingReservations store;
  FundingFixture._(this.directory, this.store);
  factory FundingFixture() {
    final dir = Directory.systemTemp.createTempSync('ark-source-authority-');
    return FundingFixture._(
      dir,
      sourceOk(
        SqliteArkFundingReservations.open(
          '${dir.path}/authority.sqlite',
          foreground: true,
          initializeNew: true,
        ),
      ),
    );
  }
  String get path => '${directory.path}/authority.sqlite';
  Future<ArkFundingBinding> reserve(
    String operation, {
    String psbt = publicFundingPsbt,
    String context = 'public-context',
    String account = 'public-account',
  }) async {
    sourceOk(
      inspectBitcoinPsbt(psbt),
    ); // Codec failure is a prerequisite failure.
    sourceOk(
      await store.begin(
        operationId: operation,
        accountIdentity: account,
        sourceParent: Fingerprint('00112233'),
        key: fundingKey,
        generation: 1,
        context: context,
      ),
    );
    sourceOk(
      await store.reserve(
        key: fundingKey,
        spend: UnsignedSpend(
          revision: fundingStamp,
          encoded: psbt,
          inputs: decodeBitcoinPsbt(psbt).inputs,
          owner: SpendOwner(protocol: 'ark', session: operation),
        ),
        context: context,
      ),
    );
    return sourceOk(await store.readBinding(operation));
  }

  void close() {
    store.close();
    directory.deleteSync(recursive: true);
  }
}

String otherUnsignedTransaction() {
  final bytes = base64Decode(publicFundingPsbt);
  // First unsigned output amount byte; previous-output data is unchanged.
  bytes[55] ^= 1;
  return base64Encode(bytes);
}

String structuralFinalWitness() {
  final bytes = base64Decode(publicFundingPsbt);
  return base64Encode([
    ...bytes.take(bytes.length - 2),
    1,
    8,
    3,
    1,
    1,
    0x42,
    0,
    0,
  ]);
}
