import 'package:announcements/src/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:announcements/src/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:announcements/src/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:announcements/src/presentation/announcements_cubit.dart';
import 'package:announcements/src/ui/widgets/announcement_carousel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart' show AnnouncementDismissals;

final class AnnouncementsFeature {
  final DismissAnnouncementUsecase _dismiss;
  final GetVisibleAnnouncementsUsecase _visible;
  final WatchAppUpdateAnnouncementUsecase _watchUpdate;
  final void Function(BuildContext) _openPayjoinSettings;

  const AnnouncementsFeature._(
    this._dismiss,
    this._visible,
    this._watchUpdate,
    this._openPayjoinSettings,
  );

  factory AnnouncementsFeature.mount({
    required AnnouncementDismissals dismissals,
    required bool Function() isAppUpdateRequired,
    required Stream<bool> Function() watchAppUpdateRequired,
    required void Function(BuildContext) openPayjoinSettings,
  }) => AnnouncementsFeature._(
    DismissAnnouncementUsecase(dismissals: dismissals),
    GetVisibleAnnouncementsUsecase(dismissals, isAppUpdateRequired),
    WatchAppUpdateAnnouncementUsecase(watchAppUpdateRequired),
    openPayjoinSettings,
  );

  Widget carousel() => BlocProvider(
    create: (_) => AnnouncementsCubit(
      getVisibleAnnouncementsUsecase: _visible,
      dismissAnnouncementUsecase: _dismiss,
      watchAppUpdateAnnouncementUsecase: _watchUpdate,
    )..refresh(),
    child: Builder(
      builder: (context) => AnnouncementCarousel(
        onOpenPayjoinSettings: () => _openPayjoinSettings(context),
      ),
    ),
  );
}
