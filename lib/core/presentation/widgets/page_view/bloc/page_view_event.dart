part of 'page_view_bloc.dart';

sealed class PageViewEvent {
  const PageViewEvent();
}

final class PageViewNextPagePressed extends PageViewEvent {
  const PageViewNextPagePressed();
}

final class PageViewPreviousPagePressed extends PageViewEvent {
  const PageViewPreviousPagePressed();
}

final class PageViewPageChanged extends PageViewEvent {
  final int page;

  const PageViewPageChanged(this.page);
}
