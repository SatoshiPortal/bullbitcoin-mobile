import 'dart:io';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ExchangeSupportChatCubit extends Cubit<ExchangeSupportChatState> {
  ExchangeSupportChatCubit({
    required GetSupportChatMessagesUsecase getMessagesUsecase,
    required SendSupportChatMessageUsecase sendMessageUsecase,
    required GetSupportChatMessageAttachmentUsecase getAttachmentUsecase,
    required GetExchangeUserSummaryUsecase getUserSummaryUsecase,
  }) : _getMessagesUsecase = getMessagesUsecase,
       _sendMessageUsecase = sendMessageUsecase,
       _getAttachmentUsecase = getAttachmentUsecase,
       _getUserSummaryUsecase = getUserSummaryUsecase,
       super(const ExchangeSupportChatState());

  final GetSupportChatMessagesUsecase _getMessagesUsecase;
  final SendSupportChatMessageUsecase _sendMessageUsecase;
  final GetSupportChatMessageAttachmentUsecase _getAttachmentUsecase;
  final GetExchangeUserSummaryUsecase _getUserSummaryUsecase;

  bool _limitFetchingOlderMessages = false;

  Future<void> loadMessages({int? page}) async {
    try {
      emit(state.copyWith(loadingMessages: true, errorLoadingMessages: ''));

      if (state.userId == null) {
        try {
          final userSummary = await _getUserSummaryUsecase.execute();
          final userId = userSummary.userId;
          if (userId == null) {
            throw Exception('User ID not found in user summary');
          }
          emit(state.copyWith(userId: userId));
        } catch (_) {}
      }

      final pageToLoad = page ?? 1;
      final messages = await _getMessagesUsecase.execute(
        page: pageToLoad,
        pageSize: 10,
      );

      final updatedMessages = pageToLoad == 1
          ? messages
          : [...state.messages, ...messages];

      emit(
        state.copyWith(
          messages: updatedMessages,
          loadingMessages: false,
          currentPage: pageToLoad,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingMessages: false,
          errorLoadingMessages: e.toString(),
        ),
      );
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.loadingOlderMessages || _limitFetchingOlderMessages) {
      return;
    }

    _limitFetchingOlderMessages = true;
    final nextPage = state.currentPage + 1;
    emit(state.copyWith(loadingOlderMessages: true));

    try {
      final messages = await _getMessagesUsecase.execute(
        page: nextPage,
        pageSize: 10,
      );

      if (messages.isEmpty) {
        emit(state.copyWith(loadingOlderMessages: false));
        return;
      }

      emit(
        state.copyWith(
          messages: [...state.messages, ...messages],
          loadingOlderMessages: false,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingOlderMessages: false));
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _limitFetchingOlderMessages = false;
      });
    }
  }

  void updateMessageText(String text) {
    emit(state.copyWith(newMessageText: text));
  }

  static const String errorMessageEmpty =
      'EXCHANGE_SUPPORT_CHAT_MESSAGE_EMPTY_ERROR';

  Future<bool> _requestPhotoLibraryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) {
        return true;
      }
      if (status.isPermanentlyDenied) {
        return false;
      }
      final requestedStatus = await Permission.photos.request();
      return requestedStatus.isGranted;
    } else if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted) {
        return true;
      }
      if (photosStatus.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        if (storageStatus.isPermanentlyDenied) {
          return false;
        }
        final requestedStorageStatus = await Permission.storage.request();
        return requestedStorageStatus.isGranted;
      }
      final requestedStatus = await Permission.photos.request();
      if (requestedStatus.isGranted) {
        return true;
      }
      if (requestedStatus.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        if (storageStatus.isPermanentlyDenied) {
          return false;
        }
        final requestedStorageStatus = await Permission.storage.request();
        return requestedStorageStatus.isGranted;
      }
      return false;
    }
    return true;
  }

  Future<void> addAttachment() async {
    try {
      emit(state.copyWith(errorPermissionDenied: ''));

      if (Platform.isAndroid) {
        final hasPermission = await _requestPhotoLibraryPermission();
        if (!hasPermission) {
          final photosStatus = await Permission.photos.status;
          final storageStatus = await Permission.storage.status;
          if (photosStatus.isPermanentlyDenied &&
              storageStatus.isPermanentlyDenied) {
            emit(
              state.copyWith(
                errorPermissionDenied:
                    'Permission denied. Please grant photo library access in Settings.',
              ),
            );
            return;
          }
          emit(state.copyWith(errorPermissionDenied: 'Permission denied.'));
          return;
        }
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) {
        return;
      }

      final newAttachments = <SupportChatMessageAttachment>[];

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final fileName = image.name;
        final extension = fileName.split('.').last.toLowerCase();
        String fileType;

        switch (extension) {
          case 'jpg':
          case 'jpeg':
            fileType = 'image/jpeg';
            break;
          case 'png':
            fileType = 'image/png';
            break;
          case 'gif':
            fileType = 'image/gif';
            break;
          default:
            fileType = 'image/jpeg';
        }

        newAttachments.add(
          SupportChatMessageAttachment(
            attachmentId:
                'temp_attachment_${fileName}_${DateTime.now().millisecondsSinceEpoch}',
            fileName: fileName,
            fileType: fileType,
            fileSize: bytes.length,
            fileData: bytes,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (newAttachments.isEmpty) return;

      emit(
        state.copyWith(
          newMessageAttachments: [
            ...state.newMessageAttachments,
            ...newAttachments,
          ],
        ),
      );
    } on Exception catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied')) {
        emit(
          state.copyWith(
            errorPermissionDenied:
                'Permission denied. Please grant photo library access in Settings.',
          ),
        );
      } else {
        emit(
          state.copyWith(
            errorPermissionDenied: 'Failed to pick files. Please try again.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorPermissionDenied: 'Failed to pick files. Please try again.',
        ),
      );
    }
  }

  void removeAttachment(String attachmentId) {
    emit(
      state.copyWith(
        newMessageAttachments: state.newMessageAttachments
            .where((att) => att.attachmentId != attachmentId)
            .toList(),
      ),
    );
  }

  Future<void> downloadAttachment(String attachmentId) async {
    try {
      emit(
        state.copyWith(
          loadingAttachmentId: attachmentId,
          errorLoadingAttachment: '',
        ),
      );

      final attachment = await _getAttachmentUsecase.execute(attachmentId);

      if (attachment.fileData != null && attachment.fileName != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${attachment.fileName}');
        await tempFile.writeAsBytes(attachment.fileData!);
        final xFile = XFile(tempFile.path);
        await SharePlus.instance.share(
          ShareParams(files: [xFile], subject: attachment.fileName),
        );
      } else {
        emit(
          state.copyWith(
            loadingAttachmentId: null,
            errorLoadingAttachment: 'Failed to fetch file data',
          ),
        );
        return;
      }

      emit(state.copyWith(loadingAttachmentId: null));
    } catch (e) {
      emit(
        state.copyWith(
          loadingAttachmentId: null,
          errorLoadingAttachment: e.toString(),
        ),
      );
    }
  }

  Future<void> sendMessage() async {
    final messageText = state.newMessageText.trim();
    final attachmentsToSend = List<SupportChatMessageAttachment>.from(
      state.newMessageAttachments,
    );
    final hasAttachments = attachmentsToSend.isNotEmpty;

    if (messageText.isEmpty) {
      emit(state.copyWith(errorSendingMessage: errorMessageEmpty));
      return;
    }

    try {
      emit(state.copyWith(sendingMessage: true, errorSendingMessage: ''));

      final tempMessage = SupportChatMessage(
        messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        text: messageText.isEmpty ? null : messageText,
        fromUserId: state.userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isAdmin: false,
        attachments: attachmentsToSend,
      );

      emit(
        state.copyWith(
          messages: [tempMessage, ...state.messages],
          newMessageText: '',
          newMessageAttachments: [],
        ),
      );

      await _sendMessageUsecase.execute(
        text: messageText,
        attachments: hasAttachments ? attachmentsToSend : null,
      );

      await loadMessages(page: 1);

      emit(state.copyWith(sendingMessage: false));
    } catch (e) {
      emit(
        state.copyWith(
          sendingMessage: false,
          errorSendingMessage: e.toString(),
          newMessageText: messageText,
          newMessageAttachments: attachmentsToSend,
          messages: state.messages
              .where((msg) => !msg.messageId!.startsWith('temp'))
              .toList(),
        ),
      );
    }
  }
}
