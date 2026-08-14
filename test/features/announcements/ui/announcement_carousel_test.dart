import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_carousel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetVisibleAnnouncementsUsecase extends Mock
    implements GetVisibleAnnouncementsUsecase {}

class _MockDismissAnnouncementUsecase extends Mock
    implements DismissAnnouncementUsecase {}

class _MockWatchAppUpdateAnnouncementUsecase extends Mock
    implements WatchAppUpdateAnnouncementUsecase {}

void main() {
  testWidgets('shows the update warning on wallet home after HTTP 418', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final getVisible = _MockGetVisibleAnnouncementsUsecase();
    final dismiss = _MockDismissAnnouncementUsecase();
    final watchUpdate = _MockWatchAppUpdateAnnouncementUsecase();
    final updateSignals = StreamController<bool>.broadcast();
    addTearDown(updateSignals.close);
    when(() => watchUpdate.execute()).thenAnswer((_) => updateSignals.stream);
    when(() => getVisible.execute()).thenAnswer(
      (_) async => Ok<List<Announcement>, AnnouncementsFailure>([
        Announcement(
          id: AnnouncementId.appUpdateRequired,
          priority: 0,
          tone: AnnouncementTone.warning,
          action: const NoAction(),
          dismissPolicy: SnoozeDismiss(const Duration(days: 1)),
        ),
      ]),
    );
    final cubit = AnnouncementsCubit(
      getVisibleAnnouncementsUsecase: getVisible,
      dismissAnnouncementUsecase: dismiss,
      watchAppUpdateAnnouncementUsecase: watchUpdate,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const AnnouncementCarousel(),
          ),
        ),
      ),
    );
    updateSignals.add(true);
    await tester.pumpAndSettle();

    expect(find.text('Update BULL'), findsOneWidget);
    expect(
      find.text(
        'To use the Lightning payment and swap service, please update the '
        'BULL mobile app with the new version.',
      ),
      findsOneWidget,
    );
  });
}
