import 'dart:async';

import 'package:bb_mobile/features/wallet/data/ark_display_data.dart';
import 'package:bb_mobile/features/wallet/data/ark_source_label.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show SyncReason;

import 'ark_board_source_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ['absent', 'blank', 'throw', 'label', 'other-source']) {
    test(
      'real display producer keeps valid balance with optional label $mode',
      () async {
        final rig = await boardSourceRig();
        await rig.source.synchronizeWithRevision(
          rig.row,
          reason: SyncReason.manual,
        );
        final changes = StreamController<String>.broadcast();
        final labels = ArkSourceLabelCache()
          ..observe(
            mode == 'other-source' ? 'retired-source' : rig.row.id,
            'Current source',
          );
        final display = WalletArkDisplayData(
          runtime: rig.runtime,
          account: rig.opened.account,
          currencyChanges: changes.stream,
          selectedSource: (_) async => Ok(rig.row.id),
          currency: () async => 'unsupported-fixture-currency',
          isActive: () => true,
          sourceLabel: switch (mode) {
            'absent' => null,
            'blank' => (_) => ' ',
            'throw' => (_) => throw Exception('optional label unavailable'),
            _ => labels.read,
          },
        );
        addTearDown(() async {
          await display.close();
          await changes.close();
        });
        final result = await display.read(rig.opened.account);
        final ArkDisplayData observation = switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'Display unexpectedly refused ${failure.runtimeType}',
          ),
        };
        expect(observation.account, rig.opened.account);
        expect(observation.walletId, rig.row.id);
        expect(observation.available, Sats.fromInt(100000));
        expect(
          observation.sourceLabel,
          mode == 'label' ? 'Current source' : null,
        );
      },
    );
  }
}
