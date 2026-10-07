import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels the close button with the app close label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnnouncementCard(
            announcement: Announcement(
              id: AnnouncementId.payjoinPrivacy,
              priority: 0,
              tone: AnnouncementTone.info,
              action: const NoAction(),
              dismissPolicy: SnoozeDismiss(const Duration(days: 1)),
            ),
            onTap: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AnnouncementCard));
    final close = find.bySemanticsLabel(
      AppLocalizations.of(context).closeDialogButton,
    );
    expect(close, findsOneWidget);
    expect(
      tester.getSemantics(close),
      matchesSemantics(isButton: true, hasTapAction: true),
    );
  });
}
