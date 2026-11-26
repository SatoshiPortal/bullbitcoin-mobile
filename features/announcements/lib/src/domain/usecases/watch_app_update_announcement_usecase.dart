class WatchAppUpdateAnnouncementUsecase {
  final Stream<bool> Function() _watchAppUpdateRequired;

  WatchAppUpdateAnnouncementUsecase(this._watchAppUpdateRequired);

  Stream<bool> execute() => _watchAppUpdateRequired();
}
