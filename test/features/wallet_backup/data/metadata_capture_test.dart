import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart'
    as settings_data;
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart' show Sats;
import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_metadata_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class Policy extends Mock implements PayjoinPolicyAccess {}

class Swaps extends Mock implements AutoSwapSettingsRepository {}

void main() {
  late SqliteDatabase db;
  late GetIt registry;
  late SettingsDatasource settings;
  late FrozenWalletUtxoDatasource frozen;
  late ElectrumServerStorageDatasource electrum;
  late MempoolServerStorageDatasource mempool;
  late Policy policy;
  late Swaps swaps;
  late WalletMetadataBackupRepositoryImpl repository;
  late StreamController<AutoSwap> swapChanges;
  late StreamController<Result<PayjoinPolicy, PayjoinFailure>> policyChanges;
  const reference = 'source-wallet-id';

  setUpAll(() {
    registerFallbackValue(const AutoSwap());
    registerFallbackValue(Sats.zero);
    registerFallbackValue(Duration.zero);
  });
  setUp(() async {
    db = SqliteDatabase(NativeDatabase.memory());
    registry = GetIt.asNewInstance()..registerSingleton<SqliteDatabase>(db);
    LabelsLocator.registerPorts(registry);
    LabelsLocator.registerFrameworks(registry);
    LabelsLocator.registerUseCases(registry);
    LabelsLocator.registerFacade(registry);
    settings = SettingsDatasource(sqlite: db);
    frozen = FrozenWalletUtxoDatasource(db: db);
    electrum = ElectrumServerStorageDatasource(sqlite: db);
    mempool = MempoolServerStorageDatasource(sqlite: db);
    policy = Policy();
    swaps = Swaps();
    swapChanges = StreamController.broadcast();
    policyChanges = StreamController.broadcast();
    when(policy.load).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(policy.watch).thenAnswer((_) => policyChanges.stream);
    when(swaps.getAutoSwapParams).thenAnswer((_) async => const AutoSwap());
    when(swaps.watchAutoSwapParams).thenAnswer((_) => swapChanges.stream);
    when(
      () => policy.setMinimumAmount(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(
      () => policy.setSessionLifetime(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(
      () => policy.setEnabled(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    when(() => swaps.updateAutoSwapParams(any())).thenAnswer((_) async {});
    final settingsWriter = settings_data.SettingsRepository(
      settingsDatasource: settings,
    );
    addTearDown(settingsWriter.close);
    repository = WalletMetadataBackupRepositoryImpl(
      database: db,
      labels: registry(),
      frozen: frozen,
      settings: settings,
      settingsWriter: settingsWriter,
      autoSwap: swaps,
      payjoin: policy,
      electrumServers: electrum,
      electrumSettings: ElectrumSettingsStorageDatasource(sqlite: db),
      mempoolServers: mempool,
      mempoolSettings: MempoolSettingsStorageDatasource(sqlite: db),
    );
    await settings.fetch();
  });
  tearDown(() async {
    await registry.reset();
    await swapChanges.close();
    await policyChanges.close();
    await db.close();
  });
  Future<WalletMetadataBackup> capture([Map<String, String>? refs]) async =>
      switch (await repository.capture(refs ?? {'local-wallet': reference})) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          'Capture failed: ${failure.runtimeType}',
        ),
      };

  test(
    'capture keeps portable preferences and remaps owner references',
    () async {
      expect(
        await registry<LabelsFacade>().store(
          NewLabel.tx(
            transactionId: 'a' * 64,
            label: 'Invoice',
            origin: 'local-wallet',
          ),
        ),
        isA<Ok>(),
      );
      expect(
        await registry<LabelsFacade>().store(
          NewLabel.tx(
            transactionId: 'b' * 64,
            label: 'System label',
            origin: 'payjoin',
          ),
        ),
        isA<Ok>(),
      );
      await frozen.freezeOutpoints(
        walletId: 'local-wallet',
        outpoints: [(txId: 'c' * 64, vout: 3)],
      );
      await frozen.freezeOutpoints(
        walletId: '',
        outpoints: [(txId: 'd' * 64, vout: 0)],
      );
      await settings.setCurrency('USD');
      await settings.setLanguage(Language.franceFrench);
      await settings.setHideAmounts(true);
      when(swaps.getAutoSwapParams).thenAnswer(
        (_) async => const AutoSwap(
          recipientWalletId: 'local-wallet',
          blockTillNextExecution: true,
          showWarning: false,
        ),
      );
      await electrum.storeBatch([
        ElectrumServerModel(
          url: 'ssl://two.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
          priority: 8,
        ),
        ElectrumServerModel(
          url: 'ssl://one.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
          priority: 2,
        ),
      ]);
      await mempool.store(
        MempoolServerModel(
          url: 'mempool.example:8080',
          isTestnet: false,
          isLiquid: false,
          isCustom: true,
          enableSsl: false,
        ),
      );
      final result = await capture();
      expect(
        result.labels.map((l) => l.origin),
        containsAll([reference, 'payjoin']),
      );
      expect(result.labels.map((l) => l.id), everyElement(0));
      expect(
        result.frozenOutputs.map((f) => f.walletReference),
        containsAll([reference, null]),
      );
      expect(result.settings.app.currency, 'USD');
      expect(result.settings.app.language, Language.franceFrench);
      expect(result.settings.app.hideAmounts, isTrue);
      expect(result.settings.autoSwap.recipientWalletReference, reference);
      final bitcoin = result.settings.electrum.singleWhere(
        (s) => s.network == ElectrumServerNetwork.bitcoinMainnet,
      );
      expect(bitcoin.servers.map((s) => (s.url, s.priority)), [
        ('ssl://one.example:50002', 2),
        ('ssl://two.example:50002', 8),
      ]);
      expect(
        result.settings.mempool
            .singleWhere(
              (s) => s.network == MempoolServerNetwork.bitcoinMainnet,
            )
            .customUrl,
        'http://mempool.example:8080',
      );
      expect(result.settings.payjoin.minimumAmount.value.toInt(), 10000);
    },
  );
  test(
    'a corrupt label or failed owner read never becomes an empty backup',
    () async {
      await db
          .into(db.labels)
          .insert(
            LabelsCompanion.insert(
              type: LabelTypeColumn.tx,
              reference: 'broken',
              label: 'Broken',
            ),
          );
      expect(await repository.capture({}), isA<Err>());
      await db.delete(db.labels).go();
      when(
        policy.load,
      ).thenAnswer((_) async => const Err(PayjoinStorageFailure()));
      expect(await repository.capture({}), isA<Err>());
      when(policy.load).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
      await db.customStatement('DROP TABLE frozen_utxos');
      expect(await repository.capture({}), isA<Err>());
    },
  );
  test(
    'an unknown attributed wallet or recipient is an incomplete inventory',
    () async {
      await frozen.freezeOutpoints(
        walletId: 'unmapped',
        outpoints: [(txId: 'a' * 64, vout: 0)],
      );
      expect(await repository.capture({}), isA<Err>());
      await frozen.unfreezeOutpoints(
        walletId: 'unmapped',
        outpoints: [(txId: 'a' * 64, vout: 0)],
      );
      when(
        swaps.getAutoSwapParams,
      ).thenAnswer((_) async => const AutoSwap(recipientWalletId: 'unmapped'));
      expect(await repository.capture({}), isA<Err>());
    },
  );
  test(
    'configuration-only capture keeps empty metadata and initial auto-swap defaults',
    () async {
      final result = await capture({});
      expect(result.labels, isEmpty);
      expect(result.frozenOutputs, isEmpty);
      expect(result.settings.autoSwap.recipientWalletReference, isNull);
      expect(result.settings.electrum, hasLength(4));
      expect(result.settings.mempool, hasLength(4));
    },
  );
  test(
    'metadata owner signals include settings, policy and auto-swap edits',
    () async {
      var changes = 0;
      final subscription = repository.changes.listen((_) => changes++);
      addTearDown(subscription.cancel);
      await settings.setHideAmounts(true);
      await Future<void>.delayed(Duration.zero);
      expect(changes, greaterThan(0));
      var before = changes;
      policyChanges.add(Ok(PayjoinPolicy.defaults()));
      await Future<void>.delayed(Duration.zero);
      expect(changes, greaterThan(before));
      before = changes;
      swapChanges.add(const AutoSwap(enabled: false));
      await Future<void>.delayed(Duration.zero);
      expect(changes, greaterThan(before));
    },
  );
  test(
    'apply remaps labels, frozen outputs and recipient while preserving runtime state',
    () async {
      expect(
        await registry<LabelsFacade>().store(
          NewLabel.tx(
            transactionId: 'e' * 64,
            label: 'Recovered',
            origin: 'local-wallet',
          ),
        ),
        isA<Ok>(),
      );
      await frozen.freezeOutpoints(
        walletId: 'local-wallet',
        outpoints: [(txId: 'e' * 64, vout: 7)],
      );
      when(swaps.getAutoSwapParams).thenAnswer(
        (_) async => const AutoSwap(recipientWalletId: 'local-wallet'),
      );
      await settings.setCurrency('USD');
      final backup = await capture();
      final oldLabel = (await registry<LabelsFacade>().fetchAll()).single;
      expect(await registry<LabelsFacade>().trash(oldLabel.id), isA<Ok>());
      await frozen.unfreezeOutpoints(
        walletId: 'local-wallet',
        outpoints: [(txId: 'e' * 64, vout: 7)],
      );
      await frozen.freezeOutpoints(
        walletId: 'other-wallet',
        outpoints: [(txId: 'a' * 64, vout: 0)],
      );
      await settings.setCurrency('CAD');
      await settings.setScreenCaptureProtectionEnabled(false);
      when(swaps.getAutoSwapParams).thenAnswer(
        (_) async =>
            const AutoSwap(blockTillNextExecution: true, showWarning: false),
      );
      expect(
        await repository.apply(backup, {reference: 'new-wallet'}),
        isA<Ok>(),
      );
      expect(
        (await registry<LabelsFacade>().fetchAll()).single.origin,
        'new-wallet',
      );
      expect(
        (await frozen.getAllFrozen()).map((o) => o.walletId),
        containsAll(['new-wallet', 'other-wallet']),
      );
      final restored = await settings.fetch();
      expect(restored.currency, 'USD');
      expect(restored.screenCaptureProtectionEnabled, isFalse);
      final params =
          verify(() => swaps.updateAutoSwapParams(captureAny())).captured.single
              as AutoSwap;
      expect(params.recipientWalletId, 'new-wallet');
      expect(params.blockTillNextExecution, isTrue);
      expect(params.showWarning, isFalse);
    },
  );
  test(
    'apply validates all wallet references before the first mutation',
    () async {
      await frozen.freezeOutpoints(
        walletId: 'local-wallet',
        outpoints: [(txId: 'b' * 64, vout: 1)],
      );
      final backup = await capture();
      await settings.setCurrency('USD');
      expect(
        await repository.apply(backup, {}),
        isA<Err<void, WalletBackupFailure>>(),
      );
      expect((await settings.fetch()).currency, 'USD');
      verifyNever(() => policy.setEnabled(any()));
    },
  );
  test(
    'apply preserves existing label identity and reports conflicting origin',
    () async {
      expect(
        await registry<LabelsFacade>().store(
          NewLabel.tx(
            transactionId: 'c' * 64,
            label: 'Same',
            origin: 'local-wallet',
          ),
        ),
        isA<Ok>(),
      );
      final backup = await capture();
      expect(
        await registry<LabelsFacade>().store(
          NewLabel.tx(
            transactionId: 'c' * 64,
            label: 'Same',
            origin: 'edited-origin',
          ),
        ),
        isA<Ok>(),
      );
      expect(
        await repository.apply(backup, {reference: 'new-wallet'}),
        isA<Err>(),
      );
      expect(
        (await registry<LabelsFacade>().fetchAll()).single.origin,
        'edited-origin',
      );
      verifyNever(() => policy.setEnabled(any()));
    },
  );
  test('a late owner failure stays incomplete and retry can finish', () async {
    await settings.setCurrency('USD');
    final backup = await capture({});
    await settings.setCurrency('CAD');
    when(
      () => policy.setEnabled(any()),
    ).thenAnswer((_) async => const Err(PayjoinStorageFailure()));
    expect(await repository.apply(backup, {}), isA<Err>());
    expect((await settings.fetch()).currency, 'USD');
    when(
      () => policy.setEnabled(any()),
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    expect(await repository.apply(backup, {}), isA<Ok>());
    final params =
        verify(() => swaps.updateAutoSwapParams(captureAny())).captured.last
            as AutoSwap;
    expect(params.enabled, isFalse);
  });
  test(
    'apply replaces custom servers and fee selection but preserves default servers and local proxy',
    () async {
      const bitcoin = ElectrumServerNetwork.bitcoinMainnet;
      const mempoolBitcoin = MempoolServerNetwork.bitcoinMainnet;
      await electrum.store(
        ElectrumServerModel(
          url: 'ssl://backup.example:50002',
          network: bitcoin,
          isCustom: true,
          priority: 9,
        ),
      );
      await mempool.store(
        MempoolServerModel(
          url: 'backup.example',
          isTestnet: false,
          isLiquid: false,
          isCustom: true,
          enableSsl: false,
        ),
      );
      final feeOwner = MempoolSettingsStorageDatasource(sqlite: db);
      await feeOwner.store(
        MempoolSettingsModel(
          network: mempoolBitcoin.networkString,
          useForFeeEstimation: false,
        ),
      );
      final backup = await capture({});
      final defaults = await electrum.fetchAllServers(isCustom: false);
      await electrum.deleteServer('ssl://backup.example:50002');
      await electrum.store(
        ElectrumServerModel(
          url: 'ssl://local.example:50002',
          network: bitcoin,
          isCustom: true,
          priority: 0,
        ),
      );
      await mempool.deleteCustomServer(mempoolBitcoin);
      await feeOwner.store(
        MempoolSettingsModel(
          network: mempoolBitcoin.networkString,
          useForFeeEstimation: true,
        ),
      );
      final electrumPrefs = ElectrumSettingsStorageDatasource(sqlite: db);
      await electrumPrefs.store(
        ElectrumSettingsModel(
          network: bitcoin,
          validateDomain: false,
          stopGap: 88,
          timeout: 4,
          retry: 2,
          socks5: '127.0.0.1:19050',
        ),
      );
      expect(await repository.apply(backup, {}), isA<Ok>());
      final servers = await electrum.fetchCustomServersByNetwork(bitcoin);
      expect(servers.map((s) => (s.url, s.priority)), [
        ('ssl://backup.example:50002', 9),
      ]);
      expect(
        (await electrum.fetchAllServers(
          isCustom: false,
        )).map((s) => s.url).toSet(),
        defaults.map((s) => s.url).toSet(),
      );
      expect(
        (await electrumPrefs.fetchByNetwork(bitcoin)).socks5,
        '127.0.0.1:19050',
      );
      expect(
        (await mempool.fetchCustomServerByNetwork(
          mempoolBitcoin,
        ))!.toEntity().fullUrl,
        'http://backup.example',
      );
      expect(
        (await feeOwner.fetchByNetwork(mempoolBitcoin)).useForFeeEstimation,
        isFalse,
      );
    },
  );
}
