import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _SettingsCubit extends Mock implements SettingsCubit {}

SettingsState _loaded({SettingsFailure? failure}) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.btc,
    currencyCode: 'USD',
    hideAmounts: false,
  ),
  failure: failure,
);

class _Child extends StatefulWidget {
  const _Child();

  @override
  State<_Child> createState() => _ChildState();
}

class _ChildState extends State<_Child> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUpAll(() => registerFallbackValue(BitcoinUnit.btc));

  testWidgets('loading preserves descendant state and masks until ready', (
    tester,
  ) async {
    final cubit = _SettingsCubit();
    final controller = StreamController<SettingsState>.broadcast();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await controller.close();
    });
    var state = const SettingsState();
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => controller.stream);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: SettingsFacade.amountScope(
            navigatorKey: GlobalKey<NavigatorState>(),
            child: const _Child(),
          ),
        ),
      ),
    );
    final original = tester.state(find.byType(_Child));
    var scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
    expect(scope.snapshot.isReady, isFalse);
    expect(scope.snapshot.hideAmounts, isTrue);
    state = _loaded();
    controller.add(state);
    await tester.pump();
    await tester.pump();
    expect(tester.state(find.byType(_Child)), same(original));
    scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
    expect(scope.snapshot.isReady, isTrue);
    expect(scope.snapshot.hideAmounts, isFalse);
    state = _loaded(failure: const SettingsStorageFailure());
    controller.add(state);
    await tester.pump();
    await tester.pump();
    scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
    expect(scope.snapshot.isReady, isFalse);
    expect(scope.snapshot.hideAmounts, isTrue);
  });

  testWidgets('same-target failed write reports failure', (tester) async {
    final cubit = _SettingsCubit();
    when(() => cubit.state).thenReturn(_loaded());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.setBitcoinUnit(any())).thenAnswer(
      (_) async => const Err<void, SettingsFailure>(SettingsStorageFailure()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: SettingsFacade.amountScope(
            navigatorKey: GlobalKey<NavigatorState>(),
            child: const SizedBox(),
          ),
        ),
      ),
    );
    final scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
    expect(await scope.writeUnit(BitcoinUnit.btc), isFalse);
    verify(() => cubit.setBitcoinUnit(BitcoinUnit.btc)).called(1);
  });
}
