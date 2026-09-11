import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_electrum_datasource.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bb_mobile/features/bullvault/presentation/bitcoin_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/descriptor_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/descriptor_backup_prototype_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bitcoin_backup_prototype_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullPasteInput;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/bullvault/support/bip138_prototype_fixture.dart';
import '../tools/distributed_backups_prototype_app.dart' as prototype;

void main({bool isInitialized = false}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'any one xpub discovers two actual Bitcoin backups and restores both funded wallets',
    (tester) async {
      final fixture = Bip138PrototypeFixture();
      final network = BitcoinBackupNetwork.values.byName(
        const String.fromEnvironment(
          'DISTRIBUTED_NETWORK',
          defaultValue: 'regtest',
        ),
      );
      final expected = [
        for (var generation = 0; generation < 2; generation++)
          BdkFacade.parsePublicTwoPathDescriptor(
            descriptor: fixture.descriptor(generation: generation),
            isTestnet: true,
          ).descriptor,
      ];
      final discovered = <String, String>{};
      final walletIds = <String, String>{};
      for (final signer in fixture.signers) {
        const requiredTxid = String.fromEnvironment('DISTRIBUTED_EXPECT_TXID');
        if (requiredTxid.isNotEmpty) {
          // A duplicate backup has the same policy and is deduplicated by the
          // UI. Independently verify this publication through real Electrum.
          const electrum = BitcoinBackupElectrumDatasource(
            ElectrumSocketConnector(),
          );
          const connection = ElectrumConnection(
            url: String.fromEnvironment('BACKUP_ELECTRUM'),
            retry: 0,
            timeout: 30,
            stopGap: 20,
            validateDomain: true,
            isCustom: true,
          );
          final key = DescriptorBackupKey.parse(signer.accountKey.xpub);
          final session = DescriptorBackupSession();
          try {
            final marker = BitcoinBackupCodec.discovery(key, network);
            final hash = hex.encode(
              sha256.convert(marker.script).bytes.reversed.toList(),
            );
            final history =
                await electrum.request(
                      connection,
                      'blockchain.scripthash.get_history',
                      [hash],
                      session,
                    )
                    as List;
            final row =
                history.singleWhere(
                      (dynamic entry) => entry['tx_hash'] == requiredTxid,
                    )
                    as Map;
            final raw =
                await electrum.request(
                      connection,
                      'blockchain.transaction.get',
                      [row['tx_hash'] as String, false],
                      session,
                    )
                    as String;
            final recovered = BitcoinBackupCodec.recover(
              Uint8List.fromList(hex.decode(raw)),
              row['tx_hash'] as String,
              row['height'] as int,
              key,
              network,
            );
            expect(recovered, hasLength(1));
            expect(recovered.single.descriptor, expected.last);
            expect(recovered.single.txid, requiredTxid);
            expect(recovered.single.outputIndex, 0);
            debugPrint(
              'DISTRIBUTED_PUBLICATION_EMULATOR_PASS role=${signer.role.name} txid=$requiredTxid full_descriptor=true',
            );
          } finally {
            session.cancel();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        // App composition receives no fixture, descriptor, payload or known txid.
        await tester.pumpWidget(
          prototype.distributedPrototypeApp(network: network),
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('bitcoin-xpub-input')),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, signer.accountKey.xpub);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BullPasteInput>(
                find.byKey(const ValueKey('bitcoin-xpub-input')),
              )
              .text,
          signer.accountKey.xpub,
        );
        final fetch = find.byKey(const ValueKey('fetch-bitcoin-backup'));
        await tester.ensureVisible(fetch);
        await tester.tap(fetch);
        await tester.pump();
        final cubit = tester
            .element(find.byType(BitcoinBackupPrototypeScreen))
            .read<BitcoinBackupCubit>();
        expect(cubit.state.busy, isTrue);
        Future<void> finish() async {
          for (var i = 0; i < 480 && cubit.state.busy; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 250)),
            );
            await tester.pump();
          }
          expect(cubit.state.busy, isFalse);
          expect(cubit.state.failure, isNull);
        }

        await finish();
        expect(cubit.state.result, isNotNull);
        expect(cubit.state.result!.incomplete, isFalse);
        for (final descriptor in expected) {
          final index = cubit.state.result!.candidates.indexWhere(
            (c) => c.descriptor == descriptor,
          );
          expect(index, greaterThanOrEqualTo(0));
          final candidate = cubit.state.result!.candidates[index];
          expect(
            discovered.putIfAbsent(descriptor, () => candidate.txid),
            candidate.txid,
          );
          final restore = find.byKey(ValueKey('restore-bitcoin-backup-$index'));
          await tester.ensureVisible(restore);
          await tester.tap(restore);
          await tester.pump();
          expect(cubit.state.busy, isTrue);
          await finish();
          final wallet = cubit.state.restored!;
          expect(
            wallet.balanceSats,
            const int.fromEnvironment(
              'DISTRIBUTED_BALANCE_SATS',
              defaultValue: 300000,
            ),
          );
          expect(wallet.transactionCount, greaterThanOrEqualTo(1));
          expect(walletIds.putIfAbsent(descriptor, () => wallet.id), wallet.id);
          expect(
            find.byKey(const ValueKey('bitcoin-restored')),
            findsOneWidget,
          );
          debugPrint(
            'DISTRIBUTED_EMULATOR_PASS role=${signer.role.name} txid=${candidate.txid} wallet=${wallet.id} balance=${wallet.balanceSats} persisted_reopened=true network=${network.name}',
          );
        }
      }
      if (const bool.fromEnvironment('DISTRIBUTED_NOSTR_LIVE')) {
        final open = find.text('Fetch from Nostr');
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        for (final signer in fixture.signers) {
          final field = find.descendant(
            of: find.byKey(const ValueKey('xpub-input')),
            matching: find.byType(EditableText),
          );
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, signer.accountKey.xpub);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<BullPasteInput>(
                  find.byKey(const ValueKey('xpub-input')),
                )
                .text,
            signer.accountKey.xpub,
          );
          final fetch = find.byKey(const ValueKey('fetch-descriptor'));
          await tester.ensureVisible(fetch);
          await tester.tap(fetch);
          await tester.pump();
          final cubit = tester
              .element(find.byType(DescriptorBackupPrototypeScreen))
              .read<DescriptorBackupCubit>();
          expect(cubit.state.busy, isTrue);
          for (var i = 0; i < 300 && cubit.state.busy; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 250)),
            );
            await tester.pump();
          }
          expect(cubit.state.busy, isFalse);
          expect(cubit.state.failure, isNull);
          final recovered = cubit.state.result!.candidates.firstWhere(
            (c) => c.descriptor == expected.first,
          );
          debugPrint(
            'DISTRIBUTED_NOSTR_EMULATOR_PASS role=${signer.role.name} event=${recovered.eventId}',
          );
        }
      }
      expect(discovered.values.toSet().length, 2);
      expect(walletIds.values.toSet().length, 2);
    },
    skip: !const bool.fromEnvironment('DISTRIBUTED_LIVE'),
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
