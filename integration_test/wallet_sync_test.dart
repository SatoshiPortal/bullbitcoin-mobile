import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet_transaction/data/datasources/wallet_transaction_datasource.dart';
import 'package:bb_mobile/core/wallet_transaction/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/recover_or_create_wallet_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lwk/lwk.dart' as lwk;

const mnemonics = [
  'model float claim feature convince exchange truck cream assume fancy swamp offer',
  'evoke tissue neck soap remind method fragile ancient horse tent kick almost',
  'box monitor dirt broken abuse city siege orange twice open save monster',
  'razor agent fruit sing cream love cable moment merit pond boost cloth',
  'elder size gravity quote adjust try gloom welcome just end rebel own',
  'raccoon melt excite series laundry weasel fork student digital useful wing deputy',
  'insect wedding arrive resemble broccoli miss bundle taxi movie print cage hill',
  'indicate calm glimpse buffalo roof found shop silver inquiry hotel hood badge',
  'issue traffic team february time boy galaxy enact melt desert bomb august',
  'category public dutch rhythm sting pottery embody weird travel nation under cable',
  'remain attitude where layer bargain ability pumpkin confirm truly certain lens riot',
  'icon suspect loyal ancient husband short screen state better wide raven leave',
  'loop identify trap view shop report you sibling beef essay castle wolf',
  'cricket company fresh curve hybrid belt sense acoustic direct chest silent time',
];

void main() {
  late final List<PublicBdkWalletModel> bdkWallets = [];
  late final List<PublicLwkWalletModel> lwkWallets = [];
  late ElectrumServerModel bdkElectrum;
  late ElectrumServerModel lwkElectrum;

  setUpAll(() async {
    await dotenv.load(isOptional: true);
    lwk.LibLwk.init();
    await Hive.initFlutter();
    await AppLocator.setup();

    for (final mnemonic in mnemonics) {
      final w = await locator<RecoverOrCreateWalletUsecase>().execute(
        mnemonicWords: mnemonic.split(' '),
        scriptType: ScriptType.bip84,
        network: Network.bitcoinMainnet,
      );

      bdkWallets.add(PublicBdkWalletModel(
        id: w.id,
        externalDescriptor: w.externalPublicDescriptor,
        internalDescriptor: w.internalPublicDescriptor,
        isTestnet: w.isTestnet,
      ));
    }

    for (final mnemonic in mnemonics) {
      final w = await locator<RecoverOrCreateWalletUsecase>().execute(
        mnemonicWords: mnemonic.split(' '),
        scriptType: ScriptType.bip84,
        network: Network.liquidMainnet,
      );

      lwkWallets.add(PublicLwkWalletModel(
        id: w.id,
        combinedCtDescriptor: w.externalPublicDescriptor,
        isTestnet: w.isTestnet,
      ));
    }

    bdkElectrum = ElectrumServerModel.blockstream(
      isTestnet: false,
      isLiquid: false,
    );
    lwkElectrum = ElectrumServerModel.blockstream(
      isTestnet: false,
      isLiquid: true,
    );
  });

  test('Bdk: concurrent sync calls for a wallet should not trigger a new sync',
      () async {
    final realDatasource = BdkWalletDatasource();
    final spyDatasource = SyncSpyBdkWalletDatasource(realDatasource);

    const calls = 20;

    for (final wallet in bdkWallets) {
      final futures = List.generate(
        calls,
        (_) => spyDatasource.sync(wallet: wallet, electrumServer: bdkElectrum),
      );

      await Future.wait(futures);

      final walletCalls = spyDatasource.callCount[wallet.id] ?? 0;
      final walletSyncs = spyDatasource.getActualSyncRuns(wallet.id);

      debugPrint(
          'Wallet: ${wallet.id}, Calls: $walletCalls, Syncs: $walletSyncs');

      expect(walletCalls, equals(calls));
      expect(walletSyncs, equals(1));
    }
  });

  test('Bdk: Syncs are independent for different wallet ids', () async {
    final realDatasource = BdkWalletDatasource();
    final spyDatasource = SyncSpyBdkWalletDatasource(realDatasource);

    await Future.wait(
      bdkWallets.map(
          (w) => spyDatasource.sync(wallet: w, electrumServer: bdkElectrum)),
    );

    for (final wallet in bdkWallets) {
      final calls = spyDatasource.callCount[wallet.id] ?? 0;
      final syncs = spyDatasource.getActualSyncRuns(wallet.id);

      expect(calls, equals(1));
      expect(syncs, equals(1));
    }

    final totalActualSyncs = bdkWallets
        .map((w) => spyDatasource.getActualSyncRuns(w.id))
        .reduce((a, b) => a + b);
    final totalCalls = spyDatasource.callCount.values.reduce((a, b) => a + b);
    expect(totalActualSyncs, equals(bdkWallets.length));
    expect(totalCalls, equals(bdkWallets.length));
    expect(totalActualSyncs, totalCalls);
  });

  test('Bdk: should trigger a second real sync after the first completes',
      () async {
    final realDatasource = BdkWalletDatasource();
    final spyDatasource = SyncSpyBdkWalletDatasource(realDatasource);

    final wallet = bdkWallets.first;

    await spyDatasource.sync(wallet: wallet, electrumServer: bdkElectrum);

    final syncsAfterFirst = spyDatasource.getActualSyncRuns(wallet.id);
    expect(syncsAfterFirst, equals(1));

    await spyDatasource.sync(wallet: wallet, electrumServer: bdkElectrum);

    final syncsAfterSecond = spyDatasource.getActualSyncRuns(wallet.id);
    expect(syncsAfterSecond, equals(2));
  });

  test('Lwk: concurrent sync calls for a wallet should not trigger a new sync',
      () async {
    final realDatasource = LwkWalletDatasource();
    final spyDatasource = SyncSpyLwkWalletDatasource(realDatasource);

    const calls = 20;

    for (final wallet in lwkWallets) {
      final futures = List.generate(
        calls,
        (_) => spyDatasource.sync(wallet: wallet, electrumServer: lwkElectrum),
      );

      await Future.wait(futures);

      final walletCalls = spyDatasource.callCount[wallet.id] ?? 0;
      final walletSyncs = spyDatasource.getActualSyncRuns(wallet.id);

      debugPrint(
          'Wallet: ${wallet.id}, Calls: $walletCalls, Syncs: $walletSyncs');

      expect(walletCalls, equals(calls));
      expect(walletSyncs, equals(1));
    }
  });

  test('Lwk: Syncs are independent for different wallet ids', () async {
    final realDatasource = LwkWalletDatasource();
    final spyDatasource = SyncSpyLwkWalletDatasource(realDatasource);

    await Future.wait(
      lwkWallets.map(
          (w) => spyDatasource.sync(wallet: w, electrumServer: lwkElectrum)),
    );

    for (final wallet in lwkWallets) {
      final calls = spyDatasource.callCount[wallet.id] ?? 0;
      final syncs = spyDatasource.getActualSyncRuns(wallet.id);

      expect(calls, equals(1));
      expect(syncs, equals(1));
    }

    final totalActualSyncs = lwkWallets
        .map((w) => spyDatasource.getActualSyncRuns(w.id))
        .reduce((a, b) => a + b);
    final totalCalls = spyDatasource.callCount.values.reduce((a, b) => a + b);
    expect(totalActualSyncs, equals(lwkWallets.length));
    expect(totalCalls, equals(lwkWallets.length));
    expect(totalActualSyncs, totalCalls);
  });

  test('Lwk: should trigger a second real sync after the first completes',
      () async {
    final realDatasource = LwkWalletDatasource();
    final spyDatasource = SyncSpyLwkWalletDatasource(realDatasource);

    final wallet = lwkWallets.first;

    await spyDatasource.sync(wallet: wallet, electrumServer: lwkElectrum);

    final syncsAfterFirst = spyDatasource.getActualSyncRuns(wallet.id);
    expect(syncsAfterFirst, equals(1));

    await spyDatasource.sync(wallet: wallet, electrumServer: lwkElectrum);

    final syncsAfterSecond = spyDatasource.getActualSyncRuns(wallet.id);
    expect(syncsAfterSecond, equals(2));
  });
}

class SyncSpyBdkWalletDatasource implements WalletTransactionDatasource {
  final BdkWalletDatasource _real;
  final Map<String, int> callCount = {};

  SyncSpyBdkWalletDatasource(this._real);

  @override
  Future<void> sync({
    required PublicWalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) async {
    callCount.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
    await _real.sync(wallet: wallet, electrumServer: electrumServer);
  }

  int getActualSyncRuns(String origin) => _real.syncExecutions[origin] ?? 0;

  @override
  Future<List<WalletTransactionModel>> getTransactions({
    required PublicWalletModel wallet,
    String? toAddress,
  }) =>
      throw UnimplementedError();
}

class SyncSpyLwkWalletDatasource implements WalletTransactionDatasource {
  final LwkWalletDatasource _real;
  final Map<String, int> callCount = {};

  SyncSpyLwkWalletDatasource(this._real);

  @override
  Future<void> sync({
    required PublicWalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) async {
    callCount.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
    await _real.sync(wallet: wallet, electrumServer: electrumServer);
  }

  int getActualSyncRuns(String origin) => _real.syncExecutions[origin] ?? 0;

  @override
  Future<List<WalletTransactionModel>> getTransactions({
    required PublicWalletModel wallet,
    String? toAddress,
  }) =>
      throw UnimplementedError();
}
