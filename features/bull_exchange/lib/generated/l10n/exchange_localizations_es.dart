// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class ExchangeLocalizationsEs extends ExchangeLocalizations {
  ExchangeLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Adjuntar un archivo';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'No se pudieron adjuntar los registros. Inténtalo de nuevo.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Adjuntar registros';

  @override
  String get exchangeSupportChatAttachmentImage => 'Imagen';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Archivo desconocido';

  @override
  String get exchangeSupportChatEmptyState =>
      'Aún no hay mensajes. ¡Inicia una conversación!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'No se pudieron obtener los datos del archivo.';

  @override
  String get exchangeSupportChatInputHint => 'Escribe un mensaje...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'No se pudo abrir el archivo adjunto. Inténtalo de nuevo.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'No se pudieron cargar los mensajes. Inténtalo de nuevo.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'El mensaje no puede estar vacío';

  @override
  String get exchangeSupportChatMessageRequired => 'Se requiere un mensaje';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'No se pudieron seleccionar los archivos. Inténtalo de nuevo.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'No se pudo enviar tu mensaje. Inténtalo de nuevo.';

  @override
  String get exchangeSupportChatSendTooltip => 'Enviar mensaje';

  @override
  String get exchangeSupportChatTitle => 'Chat de Soporte';

  @override
  String get exchangeSupportChatYesterday => 'Ayer';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Para obtener soporte humano, primero debe iniciar sesión en su cuenta de Bull Bitcoin. Es 100 % gratuito y no se requiere KYC, solo una dirección de correo electrónico.';

  @override
  String get oopsSomethingWentWrong => '¡Ups! Algo salió mal';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
