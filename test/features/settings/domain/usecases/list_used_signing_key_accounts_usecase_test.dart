import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/bip48_account_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bip48_account_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_usage.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/list_used_signing_key_accounts_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _Labels extends Fake implements LabelsFacade {
  List<Label> labels = [];
  bool fail = false;
  @override
  Future<Result<List<Label>, LabelFailure>> fetchAllOrFailure() async =>
      fail ? const Err(LabelUnexpectedFailure()) : Ok(labels);
}

class _Accounts extends Fake implements Bip48AccountRepository {
  final reserved = <int>{};
  final writes = <int>[];
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<Result<Set<int>, Bip48AccountAllocationFailure>> reservedAccounts({
    required String seedFingerprint,
    required int coinType,
  }) async => failRead
      ? const Err(Bip48AccountAllocationFailure())
      : Ok(Set.of(reserved));
  @override
  Future<Result<void, Bip48AccountAllocationFailure>> reserve({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async {
    if (failWrite) return const Err(Bip48AccountAllocationFailure());
    writes.add(account);
    reserved.add(account);
    return const Ok(null);
  }
}

class _Usages extends Fake implements Bip48AccountUsagePort {
  List<Bip48AccountUsage> usages = [];
  bool fail = false;
  @override
  Future<List<Bip48AccountUsage>> getBip48AccountUsages() async {
    if (fail) throw Exception('unavailable');
    return usages;
  }
}

class _Wallets extends Fake implements GetWalletsUsecase {
  List<Wallet> wallets = [];
  bool fail = false;
  @override
  Future<List<Wallet>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool includeHidden = false,
    bool sync = false,
  }) async {
    expect(includeHidden, isTrue);
    expect(sync, isFalse);
    if (fail) throw GetWalletsException('unavailable');
    return wallets;
  }
}

class _Storage extends Fake implements KeyValueStorageDatasource<String> {
  final values = <String, String>{};
  @override
  Future<String?> getValue(String key) async => values[key];
  @override
  Future<void> saveValue({required String key, required String value}) async =>
      values[key] = value;
}

class _SeedVerification extends Fake implements SeedVerificationPort {}

Label _memo(
  int account, {
  String fingerprint = 'deadbeef',
  int coin = 0,
  String? origin,
}) => Label(
  id: account,
  type: LabelType.extendedPublicKey,
  label: 'Memo $account',
  reference: 'xpub-$account',
  origin: origin ?? "[$fingerprint/48'/$coin'/$account'/2']",
);

Bip48AccountUsage _usage(int account) => Bip48AccountUsage(
  seedFingerprint: 'deadbeef',
  coinType: 0,
  account: account,
  derivationPath: "m/48'/0'/$account'/2'",
  xpub: 'wallet-xpub-$account',
);

Wallet _wallet(int account) => Wallet(
  origin: 'wallet-$account',
  label: 'Family vault',
  network: Network.bitcoinMainnet,
  scriptType: null,
  publicDescriptor: 'unused',
  balanceSat: BigInt.zero,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'DEADBEEF',
      xpubFingerprint: '',
      xpub: 'wallet-xpub-$account',
      derivationPath: "m/48'/0'/$account'/2'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
);

void main() {
  late _Labels labels;
  late _Accounts accounts;
  late _Usages usages;
  late _Wallets wallets;
  late ListUsedSigningKeyAccountsUsecase usecase;
  setUp(() {
    labels = _Labels();
    accounts = _Accounts();
    usages = _Usages();
    wallets = _Wallets();
    usecase = ListUsedSigningKeyAccountsUsecase(
      labels: labels,
      accounts: accounts,
      usages: usages,
      getWallets: wallets,
    );
  });
  Future<({List<UsedSigningKeyAccount> accounts, bool incomplete})> load() =>
      usecase.execute(seedFingerprint: 'DEADBEEF', coinType: 0);

  test(
    'merges memo, named wallet and sparse legacy rows in account order',
    () async {
      labels.labels = [_memo(2), _memo(1)];
      usages.usages = [_usage(0), _usage(2)];
      wallets.wallets = [_wallet(0), _wallet(2)];
      accounts.reserved.addAll([2, 50]);
      final result = await load();
      expect(result.accounts.map((a) => (a.account, a.source, a.description)), [
        (0, UsedSigningKeySource.wallet, 'Family vault'),
        (1, UsedSigningKeySource.memo, 'Memo 1'),
        (2, UsedSigningKeySource.memo, 'Memo 2'),
        (50, UsedSigningKeySource.legacy, null),
      ]);
      expect(result.incomplete, isFalse);
      expect(accounts.writes, unorderedEquals([0, 1]));
      await load();
      expect(accounts.writes, unorderedEquals([0, 1]));
    },
  );

  test(
    'ignores foreign and malformed origins but accepts hardened h syntax',
    () async {
      labels.labels = [
        _memo(1, fingerprint: 'cafebabe'),
        _memo(2, coin: 1),
        _memo(3, origin: "[deadbeef/84'/0'/3']"),
        _memo(4, origin: "[deadbeef/48'/0'/2147483648'/2']"),
        _memo(5, origin: '[DEADBEEF/48h/0h/5h/2h]'),
        Label(
          id: 6,
          type: LabelType.address,
          label: 'wrong type',
          reference: 'address',
          origin: "[deadbeef/48'/0'/6'/2']",
        ),
      ];
      final result = await load();
      expect(result.accounts.map((a) => a.account), [5]);
      expect(accounts.writes, [5]);
    },
  );

  test(
    'label failure retains wallet and legacy rows with incomplete status',
    () async {
      labels.fail = true;
      usages.usages = [_usage(0)];
      wallets.wallets = [_wallet(0)];
      accounts.reserved.add(50);
      final result = await load();
      expect(result.accounts.map((a) => a.account), [0, 50]);
      expect(result.incomplete, isTrue);
    },
  );

  test('wallet read failures retain memo and legacy rows', () async {
    labels.labels = [_memo(1)];
    accounts.reserved.add(50);
    usages.fail = true;
    final result = await load();
    expect(result.accounts.map((a) => a.account), [1, 50]);
    expect(result.incomplete, isTrue);
  });

  test(
    'wallet name failure retains the usage with fallback and incomplete status',
    () async {
      usages.usages = [_usage(0)];
      wallets.fail = true;
      final result = await load();
      expect(result.accounts.single.source, UsedSigningKeySource.wallet);
      expect(result.accounts.single.description, isNull);
      expect(result.incomplete, isTrue);
    },
  );

  for (final readFailure in [true, false]) {
    test(
      'reservation failure retains known rows (read failure: $readFailure)',
      () async {
        labels.labels = [_memo(1)];
        accounts.failRead = readFailure;
        accounts.failWrite = !readFailure;
        final result = await load();
        expect(result.accounts.single.account, 1);
        expect(result.incomplete, isTrue);
      },
    );
  }

  test(
    'restored memos rebuild empty local reservations and survive restart',
    () async {
      final storage = _Storage();
      Bip48AccountRepository repository() => Bip48AccountRepositoryImpl(
        Bip48AccountDatasource(storage),
        usages,
        _SeedVerification(),
      );
      final repositoryBeforeRestart = repository();
      labels.labels = [_memo(1), _memo(0)];
      usecase = ListUsedSigningKeyAccountsUsecase(
        labels: labels,
        accounts: repositoryBeforeRestart,
        usages: usages,
        getWallets: wallets,
      );
      expect(storage.values, isEmpty);
      final result = await load();
      expect(result.accounts.map((a) => a.account), [0, 1]);
      expect(result.incomplete, isFalse);
      final next = await repository().nextAvailable(
        seedFingerprint: 'deadbeef',
        coinType: 0,
      );
      expect((next as Ok).value, 2);
    },
  );
}
