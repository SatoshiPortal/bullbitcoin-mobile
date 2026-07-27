import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/cards/tag_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    List<String> tags = const [],
    double width = 400,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: BackupOptionCard(
                icon: const Icon(Icons.lock),
                title: 'Encrypted vault',
                description: 'Stored on a server, unlocked with your PIN.',
                tags: tags,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders every tag it is given', (tester) async {
    await pumpCard(tester, tags: ['Easy and simple (1 minute)', 'Uses Tor']);

    expect(find.byType(OptionsTag), findsNWidgets(2));
    expect(find.text('Easy and simple (1 minute)'), findsOneWidget);
    expect(find.text('Uses Tor'), findsOneWidget);
  });

  testWidgets('renders a single tag', (tester) async {
    await pumpCard(tester, tags: ['Takes 10 minutes']);

    expect(find.byType(OptionsTag), findsOneWidget);
    expect(find.text('Takes 10 minutes'), findsOneWidget);
  });

  testWidgets('renders no tag widget at all when given none', (tester) async {
    await pumpCard(tester);

    expect(find.byType(OptionsTag), findsNothing);
    // The rest of the card is unaffected.
    expect(find.text('Encrypted vault'), findsOneWidget);
  });

  testWidgets('lays two tags side by side when there is room', (tester) async {
    await pumpCard(
      tester,
      tags: ['Easy and simple (1 minute)', 'Uses Tor'],
      width: 600,
    );

    final first = tester.getTopLeft(find.byType(OptionsTag).at(0));
    final second = tester.getTopLeft(find.byType(OptionsTag).at(1));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('wraps the second tag onto its own row when the card is narrow', (
    tester,
  ) async {
    await pumpCard(
      tester,
      tags: ['Easy and simple (1 minute)', 'Uses Tor'],
      width: 260,
    );

    final first = tester.getTopLeft(find.byType(OptionsTag).at(0));
    final second = tester.getTopLeft(find.byType(OptionsTag).at(1));
    expect(second.dy, greaterThan(first.dy));
    // Wrapping, not overflowing: no layout exception and both are still there.
    expect(find.byType(OptionsTag), findsNWidgets(2));
  });
}
