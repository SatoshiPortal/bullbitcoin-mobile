// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class ExchangeLocalizationsPt extends ExchangeLocalizations {
  ExchangeLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Falha ao anexar registos. Tente novamente.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Imagem';

  @override
  String get exchangeSupportChatAttachmentUnknownFile =>
      'Ficheiro desconhecido';

  @override
  String get exchangeSupportChatEmptyState =>
      'Ainda não há mensagens. Começa uma conversa!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Falha ao obter os dados do ficheiro.';

  @override
  String get exchangeSupportChatInputHint => 'Escreva uma mensagem...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Não foi possível abrir o anexo. Tente novamente.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Não foi possível carregar as mensagens. Tente novamente.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'A mensagem não pode estar vazia';

  @override
  String get exchangeSupportChatMessageRequired => 'É necessária uma mensagem';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Falha ao escolher ficheiros. Tente novamente.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Não foi possível enviar a sua mensagem. Tente novamente.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Chat de Suporte';

  @override
  String get exchangeSupportChatYesterday => 'Ontem';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Para obter suporte humano, deve primeiro iniciar sessão na sua conta Bull Bitcoin. É 100 % gratuito e não é necessário KYC, apenas um endereço de email.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Algo correu mal';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class ExchangeLocalizationsPtBr extends ExchangeLocalizationsPt {
  ExchangeLocalizationsPtBr() : super('pt_BR');

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Falha ao anexar logs. Tente novamente.';

  @override
  String get exchangeSupportChatAttachmentImage => 'Imagem';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Arquivo desconhecido';

  @override
  String get exchangeSupportChatEmptyState =>
      'Ainda não há mensagens. Começa uma conversa!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Falha ao buscar os dados do arquivo.';

  @override
  String get exchangeSupportChatInputHint => 'Escreva uma mensagem...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Não foi possível abrir o anexo. Tente novamente.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Não foi possível carregar as mensagens. Tente novamente.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'A mensagem não pode estar vazia';

  @override
  String get exchangeSupportChatMessageRequired => 'É necessária uma mensagem';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Falha ao selecionar arquivos. Tente novamente.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Não foi possível enviar sua mensagem. Tente novamente.';

  @override
  String get exchangeSupportChatTitle => 'Chat de Suporte';

  @override
  String get exchangeSupportChatYesterday => 'Ontem';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Para obter suporte humano, você precisa primeiro fazer login na sua conta Bull Bitcoin. É 100% gratuito e não é necessário KYC, apenas um endereço de e-mail.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Algo correu mal';
}
