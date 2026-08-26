import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/allow_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/router/recoverbull_flow.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:bull_recoverbull/src/ui/pages/settings_page.dart';
import 'package:bull_recoverbull/l10n/recoverbull_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements RecoverBullRepository {}

void main() {
  testWidgets('caches the permission Future across rebuilds', (tester) async {
    final repository = _Repository();
    var fetchCount = 0;
    when(() => repository.fetchPermission()).thenAnswer((_) async {
      fetchCount++;
      return false;
    });

    var rebuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              TextButton(
                onPressed: () => setState(() => rebuilds++),
                child: const Text('Rebuild'),
              ),
              Expanded(
                child: _navigator(repository, key: const ValueKey('flow')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rebuild'));
    await tester.pumpAndSettle();

    expect(fetchCount, 1);
  });

  testWidgets('back pops an internal page before the GoRoute', (tester) async {
    final repository = _Repository();
    when(() => repository.fetchPermission()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      _TestHost(
        repository: repository,
        builder: (context, navigator) => navigator,
      ),
    );
    await tester.pumpAndSettle();

    final nestedNavigator = find.byType(Navigator).last;
    Navigator.of(tester.element(nestedNavigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Internal page')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Internal page'), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(RecoverBullFlowNavigator), findsOneWidget);
  });
}

RecoverBullFlowNavigator _navigator(_Repository repository, {Key? key}) =>
    RecoverBullFlowNavigator(
      key: key,
      flow: RecoverBullFlow.settings,
      fetchPermissionUsecase: FetchPermissionUsecase(
        recoverBullRepository: repository,
      ),
      allowPermissionUsecase: AllowPermissionUsecase(
        recoverBullRepository: repository,
      ),
      fetchUrlUsecase: FetchRecoverbullUrlUsecase(
        recoverBullRepository: repository,
      ),
      storeUrlUsecase: StoreRecoverbullUrlUsecase(
        recoverBullRepository: repository,
      ),
    );

class _TestHost extends StatelessWidget {
  final _Repository repository;
  final Widget Function(BuildContext context, Widget navigator) builder;

  const _TestHost({required this.repository, required this.builder});

  @override
  Widget build(BuildContext context) {
    final navigator = _navigator(repository);
    return MaterialApp(
      localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
      supportedLocales: RecoverBullLocalizations.supportedLocales,
      home: Builder(builder: (context) => builder(context, navigator)),
    );
  }
}
