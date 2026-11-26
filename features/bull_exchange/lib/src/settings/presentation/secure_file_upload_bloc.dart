import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/get_secure_file_upload_status_usecase.dart';
import '../domain/usecases/upload_exchange_document_usecase.dart';
import '../domain/secure_file_upload_machine.dart';

/// Shell of [transitionSecureUpload]; results after close are dropped.
class SecureUploadBloc extends Bloc<SecureUploadEvent, SecureUploadState> {
  SecureUploadBloc({
    required GetSecureFileUploadStatusUsecase getUploadStatusUsecase,
    required UploadExchangeDocumentUsecase uploadDocumentUsecase,
  }) : this._(
         secureUploadStart(),
         getUploadStatusUsecase,
         uploadDocumentUsecase,
       );

  SecureUploadBloc._(SecureUploadNext start, this._getStatus, this._upload)
    : super(start.state) {
    on<SecureUploadEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final GetSecureFileUploadStatusUsecase _getStatus;
  final UploadExchangeDocumentUsecase _upload;

  void _onEvent(SecureUploadEvent event, Emitter<SecureUploadState> emit) {
    final next = transitionSecureUpload(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<SecureUploadEffect> effects) {
    for (final effect in effects) {
      unawaited(
        _answer(effect).then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  Future<SecureUploadEvent> _answer(SecureUploadEffect effect) async =>
      switch (effect) {
        FetchUploadStatus(:final attempt) => UploadStatusLoaded(
          attempt,
          await _getStatus.execute(),
        ),
        PickUploadDocument(:final userId) => UploadPicked(
          await _upload.pick(userId: userId),
        ),
        SendUploadDocument(:final attempt, :final document) => UploadAnswered(
          attempt,
          await _upload.upload(document),
        ),
      };
}
