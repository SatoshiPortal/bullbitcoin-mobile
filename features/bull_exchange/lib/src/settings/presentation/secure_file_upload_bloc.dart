import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/get_secure_file_upload_status_usecase.dart';
import '../domain/usecases/pick_exchange_document_usecase.dart';
import '../domain/usecases/upload_exchange_document_usecase.dart';
import '../domain/secure_file_upload_machine.dart';

/// Shell of [transitionSecureUpload]; results after close are dropped.
class SecureUploadBloc extends Bloc<SecureUploadEvent, SecureUploadState> {
  SecureUploadBloc({
    required ExchangeSession? session,
    required GetSecureFileUploadStatusUsecase getUploadStatus,
    required PickExchangeDocumentUsecase pickDocument,
    required UploadExchangeDocumentUsecase uploadDocument,
  }) : this._(
         secureUploadStart(),
         session,
         getUploadStatus,
         pickDocument,
         uploadDocument,
       );

  SecureUploadBloc._(
    SecureUploadNext start,
    this._session,
    this._getUploadStatus,
    this._pickDocument,
    this._uploadDocument,
  ) : super(start.state) {
    on<SecureUploadEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final ExchangeSession? _session;
  final GetSecureFileUploadStatusUsecase _getUploadStatus;
  final PickExchangeDocumentUsecase _pickDocument;
  final UploadExchangeDocumentUsecase _uploadDocument;

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
          await _getUploadStatus.execute(_session),
        ),
        PickUploadDocument(:final userId) => UploadPicked(
          await _pickDocument.execute(userId: userId),
        ),
        SendUploadDocument(:final attempt, :final document) => UploadAnswered(
          attempt,
          await _uploadDocument.execute(document),
        ),
      };
}
