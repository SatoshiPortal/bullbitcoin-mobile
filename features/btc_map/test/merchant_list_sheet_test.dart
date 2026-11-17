import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/testing.dart';
import 'package:btc_map/src/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/sync_merchants_usecase.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:btc_map/src/ui/widgets/merchant_list_sheet.dart';
import 'package:btc_map/generated/l10n/btc_map_localizations.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

/// Nothing cached, and a first download that stays in flight until
/// [finish] is called.
class _SlowFirstSync {
  final _done = Completer<Result<List<Merchant>, BullMapFailure>>();

  void finish(List<Merchant> merchants) => _done.complete(Ok(merchants));

  Future<Result<List<Merchant>, BullMapFailure>> cached() async => const Ok([]);

  Future<Result<List<Merchant>, BullMapFailure>> sync() => _done.future;
}

class _FakeRepository {
  _FakeRepository(this.merchants);

  final List<Merchant> merchants;

  Future<Result<List<Merchant>, BullMapFailure>> cached() async =>
      Ok(merchants);

  Future<Result<List<Merchant>, BullMapFailure>> sync() async => Ok(merchants);
}

void main() {
  final merchants = [
    Merchant(
      id: 1,
      location: GeoPoint(latitude: 0.1, longitude: 0),
      name: 'Bean There',
      address: '1 Main St',
      category: MerchantCategory.coffee,
      verifiedAt: DateTime.now().toUtc(),
    ),
    Merchant(
      id: 2,
      location: GeoPoint(latitude: 0.2, longitude: 0),
      name: 'Sleep Inn',
      category: MerchantCategory.hotels,
    ),
  ];

  Future<MapCubit> pump(
    WidgetTester tester,
    ValueChanged<Merchant> onSelected,
  ) async {
    final repository = _FakeRepository(merchants);
    final cubit = MapCubit(
      LoadCachedMerchantsUsecase(repository.cached),
      SyncMerchantsUsecase(repository.sync),
    );
    await cubit.start();
    cubit.viewportChanged(
      GeoBounds(south: -0.25, west: -0.25, north: 0.25, east: 0.25),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        locale: const Locale('en'),
        localizationsDelegates: BtcMapLocalizations.localizationsDelegates,
        supportedLocales: BtcMapLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MerchantListSheet(onMerchantSelected: onSelected),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('shows the count, the categories in view and the places', (
    tester,
  ) async {
    final cubit = await pump(tester, (_) {});
    addTearDown(cubit.close);

    // Collapsed, only the search field is in view.
    expect(find.byKey(const ValueKey('merchant-search-field')), findsOne);
    expect(find.text('All').hitTestable(), findsNothing);
    expect(find.text('Bean There'), findsNothing);

    // Pull the sheet up to see the list.
    await tester.drag(
      find.byKey(const ValueKey('merchant-list-handle')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Places nearby: 2'), findsOne);
    expect(find.text('All').hitTestable(), findsOne);
    expect(find.text('Coffee'), findsOne);
    expect(find.text('Hotels'), findsOne);
    // No place in view is a restaurant, so its chip is left out.
    expect(find.text('Restaurants'), findsNothing);
    expect(find.text('Bean There'), findsOne);
    expect(find.text('Verified'), findsOne);
    expect(find.text('Not verified'), findsOne);
  });

  testWidgets('zoomed out, asks to zoom in and still offers every category', (
    tester,
  ) async {
    final cubit = await pump(tester, (_) {});
    addTearDown(cubit.close);

    cubit.viewportChanged(GeoBounds(south: -5, west: -5, north: 5, east: 5));
    await tester.drag(
      find.byKey(const ValueKey('merchant-list-handle')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zoom in on the map to see places nearby'), findsOne);
    expect(find.text('Restaurants'), findsOne);
    expect(find.text('Bean There'), findsNothing);
  });

  testWidgets('a category chip narrows the list', (tester) async {
    final cubit = await pump(tester, (_) {});
    addTearDown(cubit.close);
    // The chips sit just below the collapsed sheet.
    await tester.drag(
      find.byKey(const ValueKey('merchant-list-handle')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hotels'));
    await tester.pumpAndSettle();

    expect(cubit.state.category, MerchantCategory.hotels);
    expect(find.text('Places nearby: 1'), findsOne);
    expect(find.text('Sleep Inn'), findsOne);
    expect(find.text('Bean There'), findsNothing);
  });

  testWidgets('tapping a place hands it to the screen', (tester) async {
    Merchant? selected;
    final cubit = await pump(tester, (merchant) => selected = merchant);
    addTearDown(cubit.close);
    await tester.drag(
      find.byKey(const ValueKey('merchant-list-handle')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bean There'));
    await tester.pumpAndSettle();

    expect(selected?.id, 1);
  });

  testWidgets('says it is loading in the search bar on the first download', (
    tester,
  ) async {
    final repository = _SlowFirstSync();
    final cubit = MapCubit(
      LoadCachedMerchantsUsecase(repository.cached),
      SyncMerchantsUsecase(repository.sync),
    );
    addTearDown(cubit.close);
    unawaited(cubit.start());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        locale: const Locale('en'),
        localizationsDelegates: BtcMapLocalizations.localizationsDelegates,
        supportedLocales: BtcMapLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MerchantListSheet(onMerchantSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading merchants…'), findsOne);
    expect(find.text('Search places'), findsNothing);

    repository.finish(merchants);
    await tester.pumpAndSettle();

    expect(find.text('Search places'), findsOne);
  });
}
