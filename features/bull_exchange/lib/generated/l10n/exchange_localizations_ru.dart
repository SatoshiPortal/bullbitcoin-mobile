// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class ExchangeLocalizationsRu extends ExchangeLocalizations {
  ExchangeLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'Email';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'Имя';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Имя';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Невозможно загрузить информацию о счете';

  @override
  String get exchangeAccountInfoTitle => 'Информация об учетной записи';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'Номер пользователя скопирован в буфер обмена';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'Номер пользователя';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Проверка подлинности';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => 'Уровень проверки';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Легкая проверка';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Ограниченная проверка';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Не подтверждена';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel => 'По умолчанию';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Получение уведомлений по электронной почте для заказов и обновлений учетной записи';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel =>
      'Уведомления по электронной почте';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel =>
      'Предпочтительный язык';

  @override
  String get exchangeAppSettingsSaveButton => 'Сохранить';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Настройки сохранены успешно';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Пожалуйста, установите как языковые, так и валютные предпочтения перед сохранением.';

  @override
  String get exchangeAuthErrorMessage =>
      'Произошла ошибка, пожалуйста, попробуйте снова войти.';

  @override
  String get exchangeBitcoinWalletsTitle => 'По умолчанию Bitcoin Wallets';

  @override
  String get exchangeErrorNetwork =>
      'Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Не удалось сохранить ваши настройки. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeFileUploadButton => 'Загрузка';

  @override
  String get exchangeFileUploadDocumentTitle => 'Загрузить любой документ';

  @override
  String get exchangeFileUploadInstructions =>
      'Если вам нужно отправить любые другие документы, загрузите их здесь.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Принята';

  @override
  String get exchangeFileUploadStatusInReview => 'Обзор';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Отклонено';

  @override
  String get exchangeFileUploadSuccess => 'Файл успешно загружен';

  @override
  String get exchangeFileUploadTapToReupload =>
      'Нажмите, чтобы загрузить снова';

  @override
  String get exchangeFileUploadTitle => 'Загрузка файла';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Применить, чтобы присоединиться к программе здесь';

  @override
  String get exchangeReferralsContactSupportMessage =>
      'Контактная поддержка, чтобы узнать о нашей реферальной программе';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Присоединяйтесь к миссии';

  @override
  String get exchangeReferralsMissionLink => 'bullbitcoin.com/mission';

  @override
  String get exchangeReferralsTitle => 'Коды';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Параметры доступа';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      'Управление 2FA и пароль';

  @override
  String get exchangeSettingsAccountInformationTitle => 'Информация';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'Документ уже отправлен.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'Этот файл пуст. Выберите другой.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'Этот файл слишком большой. Выберите файл поменьше.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'Этот тип файла не принимается. Выберите другой.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'Не удалось прочитать этот файл. Выберите другой.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Не удалось загрузить данные вашего аккаунта. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Не удалось загрузить вашу торговую статистику. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Не удалось загрузить статус вашей загрузки. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'Не удалось загрузить документ. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeSettingsLogInTitle => 'Войти';

  @override
  String get exchangeSettingsRecipientsTitle => 'Получатели';

  @override
  String get exchangeSettingsReferralsTitle => 'Рефералы';

  @override
  String get exchangeSettingsSecuritySettingsTitle => 'Параметры безопасности';

  @override
  String get exchangeSettingsTransactionsTitle => 'Операции';

  @override
  String exchangeStatisticsAsOf(String date) {
    return '$date';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Средняя цена';

  @override
  String get exchangeStatisticsBillerStats => 'Статистика';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Средняя цена за биткоин при покупке';

  @override
  String get exchangeStatisticsBuySellRatio => 'Купить/продавать Соотношение';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Процент общего объёма между покупками и продажами';

  @override
  String get exchangeStatisticsBuyStats => 'Купить статистику';

  @override
  String get exchangeStatisticsBuyTradeCountDesc =>
      'Количество операций покупки биткоина';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Общая сумма, потраченная на покупку биткоина';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Валюта: $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'Статистические данные отсутствуют';

  @override
  String get exchangeStatisticsOrderStats => 'Статистика заказа';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Средняя цена за биткоин при продаже';

  @override
  String get exchangeStatisticsSellStats => 'Статистика';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Количество операций продажи биткоина';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Общая сумма, полученная от продажи биткоина';

  @override
  String get exchangeStatisticsTitle => 'Статистика';

  @override
  String get exchangeStatisticsTotalAmount => 'Общая сумма';

  @override
  String get exchangeStatisticsTotalVolume => 'Общий объем торговли';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Совокупные объёмы покупки и продажи в фиатных валютах';

  @override
  String get exchangeStatisticsTradeCount => 'Торговый счет';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сделки ($currency)',
      many: '$count сделок ($currency)',
      few: '$count сделки ($currency)',
      one: '$count сделка ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сделки',
      many: '$count сделок',
      few: '$count сделки',
      one: '$count сделка',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Объем';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Не удалось прикрепить журналы. Попробуйте снова.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Изображение';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Неизвестный файл';

  @override
  String get exchangeSupportChatEmptyState =>
      'Пока никаких сообщений. Начинайте разговор!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Не удалось получить данные файла.';

  @override
  String get exchangeSupportChatInputHint => 'Введите сообщение...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Не удалось открыть вложение. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Не удалось загрузить сообщения. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Сообщение не может быть пустым';

  @override
  String get exchangeSupportChatMessageRequired => 'Требуется сообщение';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Не удалось выбрать файлы. Попробуйте снова.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Не удалось отправить сообщение. Попробуйте ещё раз.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Поддержка чат';

  @override
  String get exchangeSupportChatYesterday => 'Вчера';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Чтобы получить поддержку от живого оператора, необходимо сначала войти в свой аккаунт Bull Bitcoin. Это полностью бесплатно, KYC не требуется — только адрес электронной почты.';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get notLoggedInTitle => 'Вы не вошли';

  @override
  String get oopsSomethingWentWrong => 'Упс! Что-то не так';

  @override
  String get retry => 'Retry';

  @override
  String get settingsAppSettingsTitle => 'Параметры приложения';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Account Settings';

  @override
  String get settingsErrorSavingSetting =>
      'Не удалось сохранить эту настройку. Пожалуйста, попробуйте снова.';

  @override
  String get exchangeAccessSettingsTitle => 'BULL Exchange';

  @override
  String get exchangeAccessSettingsLabel => 'Exchange features';

  @override
  String get exchangeAccessSettingsDescription =>
      'Show Buy, Sell and Pay on the home screen. Swap remains available.';

  @override
  String get exchangeAccessSettingsOffHint =>
      'Enable to sign in or create a Bull Bitcoin account.';

  @override
  String get exchangeAccessSettingsOnHint => 'Exchange features are enabled.';

  @override
  String get exchangeAccessSignIn => 'Sign in or create an account';

  @override
  String get exchangeAccessDisableTitle => 'Disable exchange features?';

  @override
  String get exchangeAccessDisableBody =>
      'This signs you out on this device. Existing orders, AutoBuy and recurring buys are not cancelled.';

  @override
  String get exchangeAccessDisableConfirm => 'Sign out and disable';

  @override
  String get exchangeTradingRetry => 'Retry';

  @override
  String get exchangeAccessUnreadable =>
      'Exchange access could not be read. Retry or reset it.';

  @override
  String get exchangeAccessReset => 'Reset exchange access';

  @override
  String get exchangeAccessLogoutIncomplete =>
      'Sign out is incomplete. Finish signing out before enabling exchange.';

  @override
  String get exchangeAccessRetryLogout => 'Finish signing out';
}
