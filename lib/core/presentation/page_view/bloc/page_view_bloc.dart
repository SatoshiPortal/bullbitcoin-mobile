import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'page_view_state.dart';
part 'page_view_event.dart';
part 'page_view_bloc.freezed.dart';

class PageViewBloc extends Bloc<PageViewEvent, PageViewState> {
  final int totalPages;

  PageViewBloc({required this.totalPages})
      : super(
          const PageViewState(
            currentPage: 0,
            status: PageViewStatus.initial,
          ),
        ) {
    on<PageViewNextPagePressed>(_onNextPagePressed);
    on<PageViewPreviousPagePressed>(_onPreviousPagePressed);
    on<PageViewPageChanged>(_onPageChanged);
  }

  void _onNextPagePressed(
    PageViewNextPagePressed event,
    Emitter<PageViewState> emit,
  ) {
    final nextPage = state.currentPage + 1;
    if (nextPage < totalPages - 1) {
      emit(
        PageViewState(
          currentPage: nextPage,
          status: PageViewStatus.loading,
        ),
      );
    } else if (nextPage == totalPages - 1) {
      emit(
        PageViewState(
          currentPage: nextPage,
          status: PageViewStatus.success,
        ),
      );
    } else {
      emit(
        PageViewState(
          currentPage: state.currentPage,
          status: PageViewStatus.failure,
        ),
      );
    }
  }

  void _onPreviousPagePressed(
    PageViewPreviousPagePressed event,
    Emitter<PageViewState> emit,
  ) {
    final previousPage = state.currentPage - 1;
    if (previousPage > 0) {
      emit(
        PageViewState(
          currentPage: previousPage,
          status: PageViewStatus.loading,
        ),
      );
    } else if (previousPage == 0) {
      emit(
        PageViewState(
          currentPage: previousPage,
          status: PageViewStatus.initial,
        ),
      );
    } else {
      emit(
        PageViewState(
          currentPage: state.currentPage,
          status: PageViewStatus.failure,
        ),
      );
    }
  }

  void _onPageChanged(PageViewPageChanged event, Emitter<PageViewState> emit) {
    if (event.page == 0) {
      emit(
        PageViewState(
          currentPage: event.page,
          status: PageViewStatus.initial,
        ),
      );
    } else if (event.page < totalPages - 1) {
      emit(
        PageViewState(
          currentPage: event.page,
          status: PageViewStatus.loading,
        ),
      );
    } else if (event.page == totalPages - 1) {
      emit(
        PageViewState(
          currentPage: event.page,
          status: PageViewStatus.success,
        ),
      );
    } else {
      emit(
        PageViewState(
          currentPage: state.currentPage,
          status: PageViewStatus.failure,
        ),
      );
    }
  }
}
