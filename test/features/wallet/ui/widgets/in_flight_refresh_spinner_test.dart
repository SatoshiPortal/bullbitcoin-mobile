import 'package:bb_mobile/features/wallet/ui/widgets/in_flight_refresh_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InFlightRefreshSpinner spinner;
  late GlobalKey<RefreshIndicatorState> key;
  late int userRefreshes;
  late int follows;

  Future<void> pumpIndicator(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: RefreshIndicator(
        key: key,
        onRefresh: () => spinner.onRefresh(
          userRefresh: () async => userRefreshes++,
          follow: () async => follows++,
        ),
        child: ListView(children: const [SizedBox(height: 2000)]),
      ),
    ),
  );

  setUp(() {
    spinner = InFlightRefreshSpinner();
    key = GlobalKey<RefreshIndicatorState>();
    userRefreshes = 0;
    follows = 0;
  });

  testWidgets('a spinner shown by the app does not start a user refresh', (
    tester,
  ) async {
    await pumpIndicator(tester);

    spinner.show(key.currentState);
    await tester.pumpAndSettle();

    expect(follows, 1);
    expect(userRefreshes, 0);
  });

  testWidgets('a pull gesture after an app-shown spinner is a user refresh', (
    tester,
  ) async {
    await pumpIndicator(tester);
    spinner.show(key.currentState);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(follows, 1);
    expect(userRefreshes, 1);
  });
}
