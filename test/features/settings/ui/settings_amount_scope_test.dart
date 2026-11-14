import 'dart:async';

import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
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
  Widget build(BuildContext context) =>
      BullAmount(magnitude: Sats.fromInt(12345));
}

void main() {
  setUpAll(() => registerFallbackValue(BitcoinUnit.btc));

  testWidgets(
    'loading preserves state and unrelated failure keeps loaded amounts visible',
    (tester) async {
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
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: bullUiLocalizationsDelegates,
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
      expect(find.text('** BTC'), findsOneWidget);
      state = _loaded();
      controller.add(state);
      await tester.pump();
      await tester.pump();
      expect(tester.state(find.byType(_Child)), same(original));
      scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
      expect(scope.snapshot.isReady, isTrue);
      expect(scope.snapshot.hideAmounts, isFalse);
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      state = _loaded(failure: const SettingsStorageFailure());
      controller.add(state);
      await tester.pump();
      await tester.pump();
      scope = tester.widget<BullAmountScope>(find.byType(BullAmountScope));
      expect(scope.snapshot.isReady, isTrue);
      expect(scope.snapshot.hideAmounts, isFalse);
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      expect(find.text('** BTC'), findsNothing);
    },
  );

  testWidgets('same-target failed write reports failure', (tester) async {
    final cubit = _SettingsCubit();
    when(() => cubit.state).thenReturn(_loaded());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.setBitcoinUnit(any())).thenAnswer(
      (_) async => const Err<void, SettingsFailure>(SettingsStorageFailure()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: bullUiLocalizationsDelegates,
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
  testWidgets(
    'unit write failure reports error without hiding loaded amounts',
    (tester) async {
      final cubit = _SettingsCubit();
      final controller = StreamController<SettingsState>.broadcast();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await controller.close();
      });
      var state = _loaded();
      when(() => cubit.state).thenAnswer((_) => state);
      when(() => cubit.stream).thenAnswer((_) => controller.stream);
      when(() => cubit.setBitcoinUnit(BitcoinUnit.sats)).thenAnswer((_) async {
        state = _loaded(failure: const SettingsStorageFailure());
        controller.add(state);
        return const Err<void, SettingsFailure>(SettingsStorageFailure());
      });
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: bullUiLocalizationsDelegates,
          home: BlocProvider<SettingsCubit>.value(
            value: cubit,
            child: SettingsFacade.amountScope(
              navigatorKey: navigatorKey,
              child: const _Child(),
            ),
          ),
        ),
      );
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      await tester.longPress(find.text('0.00012345 BTC'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not change the amount unit. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      expect(find.text('** BTC'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      verify(() => cubit.setBitcoinUnit(BitcoinUnit.sats)).called(1);
    },
  );
}
