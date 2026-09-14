import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/portable_backup/data/portable_backup_repository_impl.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_cubit.dart';
import 'package:bb_mobile/features/portable_backup/ui/portable_backup_prototype_screen.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/bullvault/support/bip138_prototype_fixture.dart';
import '../test/features/wallet_backup/support/canonical_backup_snapshot.dart';
import '../tools/portable_backup_prototype_app.dart';

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'RecoverBull files and fresh password-only recovery over real Nostr',
    (tester) async {
      // Use one input source: otherwise the real Android IME can overwrite
      // values injected by tester.enterText while focus moves between fields.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final fixture = Bip138PrototypeFixture();
      final descriptor = fixture.descriptor();
      final repository = PortableBackupRepositoryImpl(
        const RecoverBullEncryption(),
        const NostrRelayDatasource(),
      );
      final derived = await tester.runAsync(
        () => repository.derivePassword(fixture.publishingRoot),
      );
      expect(derived, isA<Ok<String, dynamic>>());
      final words = (derived! as Ok).value as String;
      final metadata = canonicalCodec().encode(canonicalFullSnapshot());
      final prepared = await tester.runAsync(
        () => repository.prepare(
          words: words,
          metadataJson: metadata,
          descriptor: descriptor,
          network: 'testnet4',
        ),
      );
      expect(prepared, isA<Ok<PortableBackupFiles, dynamic>>());
      final files = (prepared! as Ok).value as PortableBackupFiles;
      final opened = await tester.runAsync(
        () => repository.open(
          words: words,
          file: files.metadata,
          network: 'testnet4',
          kind: PortableBackupKind.metadata,
        ),
      );
      expect(opened, isA<Ok<PortableBackupArtifact, dynamic>>());
      expect(
        ((opened! as Ok).value as PortableBackupArtifact).contents,
        metadata,
      );
      final relay = Uri.parse(
        const String.fromEnvironment(
          'PORTABLE_BACKUP_RELAY',
          defaultValue: 'wss://nos.lol',
        ),
      );
      final published = await tester.runAsync(
        () => repository.publish(
          words: words,
          encryptedFile: files.vault,
          relay: relay,
          session: NostrSession(),
        ),
      );
      expect(
        published,
        isA<Ok<String, dynamic>>(),
        reason: 'Real relay must acknowledge the signed event',
      );
      final eventId = (published! as Ok).value as String;

      // Fresh UI has no fixture, root seed, descriptor, files or publishing state.
      await tester.pumpWidget(portableBackupPrototypeApp(recoveryOnly: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('portable-publish')), findsNothing);
      final field = find.descendant(
        of: find.byKey(const ValueKey('portable-words')),
        matching: find.byType(EditableText),
      );
      if (relay.toString() != 'wss://nos.lol') {
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('portable-relay')),
            matching: find.byType(EditableText),
          ),
          relay.toString(),
        );
      }
      await tester.enterText(field, words);
      await tester.pumpAndSettle();
      final fetch = find.byKey(const ValueKey('portable-fetch'));
      await tester.ensureVisible(fetch);
      await tester.tap(fetch);
      await tester.pump();
      final cubit = tester
          .element(find.byType(PortableBackupPrototypeScreen))
          .read<PortableBackupCubit>();
      expect(
        cubit.state.busy,
        isTrue,
        reason: 'Action must start a new operation',
      );
      await _finish(tester, cubit);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.recovered, isNotNull);
      final recovered = cubit.state.recovered!.candidates.firstWhere(
        (candidate) => candidate.eventId == eventId,
      );
      expect(recovered.artifact.contents, descriptor);
      expect(
        find.byKey(ValueKey('portable-descriptor-$eventId')),
        findsOneWidget,
      );
      _sameAddresses(descriptor, recovered.artifact.contents);
      debugPrint(
        'PORTABLE_BACKUP_NOSTR_FETCH_PASS relay=$relay event=$eventId receive/change=0,7,111',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      await tester.enterText(field, words);
      await tester.pumpAndSettle();
      final fileField = find.descendant(
        of: find.byKey(const ValueKey('portable-metadata-file')),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(fileField);
      await tester.enterText(fileField, base64Encode(files.metadata));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).controller.text, words);
      expect(
        tester.widget<EditableText>(fileField).controller.text,
        base64Encode(files.metadata),
      );
      final open = find.byKey(const ValueKey('portable-open-metadata'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump();
      expect(
        cubit.state.busy || cubit.state.metadataOpened,
        isTrue,
        reason: 'Action must start or complete metadata decryption',
      );
      await _finish(tester, cubit);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.metadataOpened, isTrue);
      debugPrint(
        'PORTABLE_BACKUP_NOSTR_EMULATOR_PASS relay=$relay event=$eventId vaultBytes=${files.vault.length} metadataBytes=${files.metadata.length} receive/change=0,7,111',
      );
    },
    skip: !const bool.fromEnvironment('PORTABLE_BACKUP_LIVE'),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _finish(WidgetTester tester, PortableBackupCubit cubit) async {
  for (var i = 0; i < 720 && cubit.state.busy; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }
  expect(cubit.state.busy, isFalse, reason: 'Operation must terminate');
}

void _sameAddresses(String original, String restored) {
  final expected = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: original,
    isTestnet: true,
  );
  final actual = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: restored,
    isTestnet: true,
  );
  for (final pair in [
    (expected.externalDescriptor, actual.externalDescriptor),
    (expected.internalDescriptor, actual.internalDescriptor),
  ]) {
    final a = bdk.Descriptor(
      descriptor: pair.$1,
      networkKind: bdk.NetworkKind.test,
    );
    final b = bdk.Descriptor(
      descriptor: pair.$2,
      networkKind: bdk.NetworkKind.test,
    );
    try {
      for (final index in [0, 7, 111]) {
        final x = a.deriveAddress(index: index, network: bdk.Network.testnet);
        final y = b.deriveAddress(index: index, network: bdk.Network.testnet);
        try {
          expect(y.toString(), x.toString());
        } finally {
          x.dispose();
          y.dispose();
        }
      }
    } finally {
      a.dispose();
      b.dispose();
    }
  }
}
