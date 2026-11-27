import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show ViewId, ViewSummary;
import 'package:views/setup.dart';
import 'package:views/src/domain/views_failure.dart';
import 'package:views/src/domain/views_port.dart';
import 'package:views/src/presentation/views_cubit.dart';
import 'package:views/src/ui/view_switcher.dart';
import 'package:views/src/ui/views_screen.dart';
import 'package:views/views.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class _FakePort implements ViewsPort {
  final _changes = StreamController<void>.broadcast();
  final calls = <String>[];
  ViewsFailure? refuse;

  @override
  List<ViewSummary> views = const [
    ViewSummary(
      id: ViewId('a'),
      name: 'Personal',
      isProtected: false,
      backgroundEnabled: true,
    ),
    ViewSummary(
      id: ViewId('b'),
      name: 'Work',
      isProtected: true,
      backgroundEnabled: false,
    ),
  ];

  @override
  ViewId? active = const ViewId('a');

  @override
  Stream<void> get changes => _changes.stream;

  Future<Result<T, ViewsFailure>> _do<T>(String call, T value) async {
    calls.add(call);
    final failure = refuse;
    return failure == null ? Ok(value) : Err(failure);
  }

  @override
  Future<Result<void, ViewsFailure>> activate(ViewId id) async {
    final result = await _do('activate:${id.value}', null);
    if (result is Ok) active = id;
    return result;
  }

  @override
  Future<Result<ViewSummary, ViewsFailure>> create(String name) => _do(
    'create:$name',
    ViewSummary(
      id: const ViewId('c'),
      name: name,
      isProtected: false,
      backgroundEnabled: true,
    ),
  );

  @override
  Future<Result<void, ViewsFailure>> delete(ViewId id) =>
      _do('delete:${id.value}', null);

  @override
  Future<Result<void, ViewsFailure>> rename(ViewId id, String name) =>
      _do('rename:${id.value}:$name', null);

  @override
  Future<Result<void, ViewsFailure>> setBackground(bool enabled) =>
      _do('background:$enabled', null);
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: const [
    bullUiLocalizationsDelegate,
    ViewsLocalizations.delegate,
  ],
  supportedLocales: ViewsLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late _FakePort port;

  setUp(() => port = _FakePort());

  Widget screen() => BlocProvider(
    create: (_) => ViewsCubit(port),
    child: ViewsScreen(onBack: () {}),
  );

  testWidgets('lists every opened view with its protection and the one in '
      'use', (tester) async {
    await tester.pumpWidget(_app(screen()));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Protected'), findsOneWidget);
    expect(find.text('No PIN'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
  });

  testWidgets('every control has a name and a 48 dp target', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(screen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rename'), findsNWidgets(2));
    expect(find.byTooltip('Delete'), findsNWidgets(2));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('tapping another view switches to it, the view in use cannot '
      'be deleted', (tester) async {
    await tester.pumpWidget(_app(screen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(port.calls, ['activate:b']);
    final deleteInUse = tester.widget<IconButton>(
      find.byKey(const ValueKey('view-delete-b')),
    );
    expect(deleteInUse.onPressed, isNull);
  });

  testWidgets('a refusal shows a translated message, never the cause', (
    tester,
  ) async {
    port.refuse = const ViewsHoldsSecretsFailure();
    await tester.pumpWidget(_app(screen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This view holds a seed no other view holds. Move it to another '
        'view first.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the background switch acts on the view in use', (tester) async {
    await tester.pumpWidget(_app(screen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(port.calls, ['background:false']);
  });

  testWidgets('the switcher is silent with one view and names the view in '
      'use with two', (tester) async {
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => ViewsCubit(port),
          child: const ViewSwitcher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    port.views = [port.views.first];
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => ViewsCubit(port),
          child: const ViewSwitcher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsNothing);
  });

  test('a closed gate contributes no route and no widget', () {
    final feature = ViewsFeature.forPort(port, enabled: false);
    expect(feature.routes, isEmpty);
    expect(feature.switcher(), isA<SizedBox>());
    final open = ViewsFeature.forPort(port, enabled: true);
    expect(open.routes, hasLength(1));
  });
}
