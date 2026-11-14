import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_transaction_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Labels extends Mock implements LabelsFacade {}

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

WalletMetadataModel _row(String id, String networkCode) => WalletMetadataModel(
  networkCode: networkCode,
  id: id,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public)',
  internalPublicDescriptor: 'wpkh(change)',
  signer: Signer.none,
  isDefault: false,
);

void main() {
  final readable = _row('readable', 'bitcoinTestnet');
  // The schema 16 column default, kept for rows the backfill cannot resolve.
  final unreadable = _row('unreadable', 'unresolved');

  setUpAll(() => registerFallbackValue(WalletModel.fromMetadata(readable)));

  late _Metadata metadata;
  late _Bdk bdk;
  late List<WalletMetadataModel> synchronized;
  late WalletTransactionRepositoryImpl repository;

  setUp(() {
    metadata = _Metadata();
    bdk = _Bdk();
    synchronized = [];
    when(
      () => bdk.getTransactions(
        wallet: any(named: 'wallet'),
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) async => []);
    repository = WalletTransactionRepositoryImpl(
      walletMetadataDatasource: metadata,
      labelsFacade: _Labels(),
      bdkWalletTransactionDatasource: bdk,
      lwkWalletTransactionDatasource: _Lwk(),
      synchronize: (row) async => synchronized.add(row),
    );
  });

  test('an unreadable network row does not hide the other wallets', () async {
    when(metadata.fetchAll).thenAnswer((_) async => [unreadable, readable]);

    expect(await repository.getWalletTransactions(sync: true), isEmpty);

    final read = verify(
      () => bdk.getTransactions(
        wallet: captureAny(named: 'wallet'),
        toAddress: any(named: 'toAddress'),
      ),
    ).captured;
    expect(read.map((wallet) => (wallet as WalletModel).id), ['readable']);
    expect(synchronized.map((row) => row.id), ['readable']);
  });

  test('a wallet asked for by id with an unreadable network fails', () async {
    when(() => metadata.fetch('unreadable'))
        .thenAnswer((_) async => unreadable);

    await expectLater(
      repository.getWalletTransactions(walletId: 'unreadable'),
      throwsA(isA<FormatException>()),
    );
    verifyNever(
      () => bdk.getTransactions(
        wallet: any(named: 'wallet'),
        toAddress: any(named: 'toAddress'),
      ),
    );
  });
}
