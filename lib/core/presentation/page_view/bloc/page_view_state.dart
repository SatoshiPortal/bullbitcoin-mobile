part of 'page_view_bloc.dart';

enum PageViewStatus { initial, loading, success, failure }

@freezed
class PageViewState with _$PageViewState {
  const factory PageViewState({
    required int currentPage,
    required PageViewStatus status,
  }) = _PageViewState;
  const PageViewState._();
}
