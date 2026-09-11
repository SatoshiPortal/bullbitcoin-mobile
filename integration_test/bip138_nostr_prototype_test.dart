import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/presentation/descriptor_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/descriptor_backup_prototype_screen.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_ui/bull_ui.dart' show BullPasteInput;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/bullvault/support/bip138_prototype_fixture.dart';
import '../tools/bip138_prototype_app.dart' as prototype;

void main({bool isInitialized = false}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'fresh recovery-only app fetches real Nostr using each account xpub',
    (tester) async {
      final fixture = Bip138PrototypeFixture();
      final expected = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: fixture.descriptor(),
        isTestnet: true,
      );
      await tester.pumpWidget(prototype.prototypeApp(recoveryOnly: true));
      await tester.pumpAndSettle();
      expect(find.text('Publish test descriptor'), findsNothing);
      final eventIds = <String>{};
      for (final signer in fixture.signers) {
        await tester.pumpAndSettle();
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
              .widget<BullPasteInput>(find.byKey(const ValueKey('xpub-input')))
              .text,
          signer.accountKey.xpub,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('fetch-descriptor')),
        );
        await tester.tap(find.byKey(const ValueKey('fetch-descriptor')));
        await tester.pump();
        final cubit = tester
            .element(find.byType(DescriptorBackupPrototypeScreen))
            .read<DescriptorBackupCubit>();
        expect(
          cubit.state.busy,
          isTrue,
          reason: 'Each role must start a new network request',
        );
        for (var i = 0; i < 280 && cubit.state.busy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          await tester.pump();
        }
        expect(
          cubit.state.busy,
          isFalse,
          reason: 'Nostr request must terminate',
        );
        expect(cubit.state.failure, isNull);
        expect(cubit.state.result, isNotNull);
        final candidate = cubit.state.result!.candidates.firstWhere(
          (c) => c.descriptor == expected.descriptor,
        );
        expect(
          eventIds.add(candidate.eventId),
          isTrue,
          reason: 'Each account uses its own encrypted Nostr event',
        );
        expect(find.text(candidate.descriptor), findsOneWidget);
        final recovered = BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: candidate.descriptor,
          isTestnet: true,
        );
        for (final pair in [
          (expected.externalDescriptor, recovered.externalDescriptor),
          (expected.internalDescriptor, recovered.internalDescriptor),
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
              final expectedAddress = a.deriveAddress(
                index: index,
                network: bdk.Network.testnet,
              );
              final actualAddress = b.deriveAddress(
                index: index,
                network: bdk.Network.testnet,
              );
              try {
                expect(actualAddress.toString(), expectedAddress.toString());
              } finally {
                actualAddress.dispose();
                expectedAddress.dispose();
              }
            }
          } finally {
            a.dispose();
            b.dispose();
          }
        }
        debugPrint(
          'BIP138_NOSTR_EMULATOR_PASS role=${signer.role.name} event=${candidate.eventId} receive/change=0,7,111',
        );
      }
      expect(eventIds.length, 3);
    },
    skip: !const bool.fromEnvironment('BIP138_LIVE'),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
