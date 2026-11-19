import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/ark_receive_share.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

Future<BuildContext> host(WidgetTester tester, {String language = 'en'}) async {
  BuildContext? captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      theme: ThemeData(extensions: testBullExtensions),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = captured;
  if (context == null) throw StateError('Missing fixture context');
  return context;
}

void main() {
  for (final status in ShareResultStatus.values) {
    testWidgets(
      'exact text is shared once and $status makes no delivery claim',
      (tester) async {
        final context = await host(tester);
        final calls = <ShareParams>[];
        const text = '  public-ark-or-bolt11-destination  ';
        await shareArkReceive(
          context,
          text,
          isCurrent: () => true,
          share: (params) async {
            calls.add(params);
            return ShareResult('fixture', status);
          },
        );
        await tester.pump();
        expect(calls, hasLength(1));
        expect(calls.single.text, text);
        expect(calls.single.uri, isNull);
        expect(calls.single.files, isNull);
        expect(find.text(context.loc.oopsSomethingWentWrong), findsNothing);
      },
    );
  }
  testWidgets('retired action and empty destination never invoke the plugin', (
    tester,
  ) async {
    final context = await host(tester);
    var calls = 0;
    Future<ShareResult> plugin(ShareParams params) async {
      calls++;
      return ShareResult.unavailable;
    }

    await shareArkReceive(
      context,
      'public-value',
      isCurrent: () => false,
      share: plugin,
    );
    await shareArkReceive(context, '  ', isCurrent: () => true, share: plugin);
    expect(calls, 0);
  });
  testWidgets('plugin exception is localized only for the live owner', (
    tester,
  ) async {
    final context = await host(tester, language: 'fr');
    final expected = context.loc.oopsSomethingWentWrong;
    await shareArkReceive(
      context,
      'public-value',
      isCurrent: () => true,
      share: (_) async => throw PlatformException(
        code: 'fixture',
        message: 'raw fixture detail',
      ),
    );
    await tester.pump();
    expect(find.text(expected), findsOneWidget);
    expect(find.text('raw fixture detail'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
  for (final dispose in [false, true]) {
    testWidgets(
      'late plugin failure after retirement dispose=$dispose has no feedback',
      (tester) async {
        final context = await host(tester);
        final failureText = context.loc.oopsSomethingWentWrong;
        var current = true;
        final reply = Completer<ShareResult>();
        final sharing = shareArkReceive(
          context,
          'public-value',
          isCurrent: () => current,
          share: (_) => reply.future,
        );
        if (dispose) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          current = false;
        }
        reply.completeError(PlatformException(code: 'fixture'));
        await sharing;
        await tester.pump();
        expect(find.text(failureText), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
