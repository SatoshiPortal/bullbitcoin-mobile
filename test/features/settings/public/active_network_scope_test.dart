import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'dart:async';

import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

void main() {
  testWidgets(
    'network change recreates presentation but other settings do not',
    (tester) async {
      final settings = _Settings();
      final changes = StreamController<SettingsState>();
      final mainnet = SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      whenListen(settings, changes.stream, initialState: mainnet);
      addTearDown(changes.close);
      var created = 0;
      var closed = 0;
      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: settings,
          child: ActiveNetworkScope(
            child: BlocProvider<Cubit<int>>(
              create: (_) {
                created++;
                return _NetworkState(() => closed++);
              },
              lazy: false,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      expect(created, 1);
      changes.add(
        mainnet.copyWith(
          storedSettings: mainnet.storedSettings?.copyWith(hideAmounts: true),
        ),
      );
      await tester.pump();
      expect(created, 1);
      // No wallet or sync event is required on the newly selected network.
      changes.add(
        SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      await tester.pump();
      expect(created, 2);
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox());
      expect(closed, 2);
    },
  );
}

class _NetworkState extends Cubit<int> {
  final void Function() onClose;
  _NetworkState(this.onClose) : super(0);
  @override
  Future<void> close() {
    onClose();
    return super.close();
  }
}
