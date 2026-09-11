import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_electrum_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_wallet_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bitcoin_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bip138_prototype_fixture.dart';

void main() {
  test(
    'real stock Electrum recovers both funded policies through every account and reopens SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'distributed-backup-wallets-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = BitcoinDescriptorBackupRepositoryImpl(
        const BitcoinBackupElectrumDatasource(ElectrumSocketConnector()),
        BitcoinBackupWalletDatasource(() async => directory.path),
      );
      const connection = ElectrumConnection(
        url: String.fromEnvironment(
          'BACKUP_ELECTRUM',
          defaultValue: 'tcp://127.0.0.1:51401',
        ),
        retry: 0,
        timeout: 10,
        stopGap: 20,
        validateDomain: true,
        isCustom: true,
      );
      final network = BitcoinBackupNetwork.values.byName(
        const String.fromEnvironment(
          'DISTRIBUTED_NETWORK',
          defaultValue: 'regtest',
        ),
      );
      final fixture = Bip138PrototypeFixture();
      final identities = <String, String>{};
      final transactions = <String, String>{};
      final evidence = <Map<String, Object>>[];
      for (final signer in fixture.signers) {
        final result = await FetchBitcoinBackupUsecase(repository).execute(
          input: signer.accountKey.xpub,
          network: network,
          connection: connection,
          session: DescriptorBackupSession(),
        );
        expect(result, isA<Ok<BitcoinBackupFetch, dynamic>>());
        final fetched = (result as Ok).value as BitcoinBackupFetch;
        expect(fetched.incomplete, isFalse);
        for (var generation = 0; generation < 2; generation++) {
          final expected = BdkFacade.parsePublicTwoPathDescriptor(
            descriptor: fixture.descriptor(generation: generation),
            isTestnet: true,
          );
          final candidate = fetched.candidates.singleWhere(
            (c) => c.descriptor == expected.descriptor,
          );
          expect(
            transactions.putIfAbsent(
              candidate.descriptor,
              () => candidate.txid,
            ),
            candidate.txid,
          );
          final restored = await RestoreBitcoinBackupUsecase(repository)
              .execute(
                descriptor: candidate.descriptor,
                network: network,
                connection: connection,
                session: DescriptorBackupSession(),
              );
          expect(restored, isA<Ok<RestoredBackupWallet, dynamic>>());
          final wallet = (restored as Ok).value as RestoredBackupWallet;
          expect(
            wallet.balanceSats,
            const int.fromEnvironment(
              'DISTRIBUTED_BALANCE_SATS',
              defaultValue: 300000,
            ),
          );
          expect(wallet.transactionCount, 1);
          expect(
            identities.putIfAbsent(candidate.descriptor, () => wallet.id),
            wallet.id,
          );
          expect(
            File('${directory.path}/${wallet.id}.sqlite').existsSync(),
            isTrue,
          );
          evidence.add({
            'role': signer.role.name,
            'network': network.name,
            'generation': generation,
            'txid': candidate.txid,
            'walletId': wallet.id,
            'balanceSats': wallet.balanceSats,
            'persistedReopened': true,
            'receive': wallet.receiveAddress,
            'change': wallet.changeAddress,
          });
        }
      }
      expect(identities.length, 2);
      const output = String.fromEnvironment('BACKUP_EVIDENCE');
      if (output.isNotEmpty) {
        File(output).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
        );
      }
    },
    skip: !const bool.fromEnvironment('DISTRIBUTED_LIVE'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
