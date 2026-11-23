// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class ExchangeLocalizationsUk extends ExchangeLocalizations {
  ExchangeLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'Веб-сайт';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'Ім\'я';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Ім\'я';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Неможливо завантажити інформацію';

  @override
  String get exchangeAccountInfoTitle => 'Інформація про обліковий запис';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'Номер користувача копіюється на буфер';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'Номер користувача';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Перевірка ідентичності';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => 'Рівень верифікація';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Перевірка світла';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Обмежена перевірка';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Не перевірено';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel =>
      'Валюта за замовчуванням';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Отримуйте повідомлення електронної пошти для замовлень та оновлення облікового запису';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel =>
      'Повідомлення електронної пошти';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => 'Мова перекладу';

  @override
  String get exchangeAppSettingsSaveButton => 'Зберегти';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Налаштування збережених успішно';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Будь ласка, встановіть мовні та валютні уподобання до збереження.';

  @override
  String get exchangeAuthErrorMessage =>
      'Помилкові помилки, будь ласка, спробуйте увійти знову.';

  @override
  String get exchangeBitcoinWalletsTitle => 'За замовчуванням Bitcoin Wallets';

  @override
  String get exchangeErrorNetwork =>
      'Перевірте підключення до Інтернету та спробуйте ще раз.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Не вдалося зберегти ваші налаштування. Будь ласка, спробуйте ще раз.';

  @override
  String get exchangeFileUploadButton => 'Завантажити';

  @override
  String get exchangeFileUploadDocumentTitle =>
      'Завантажити будь-який документ';

  @override
  String get exchangeFileUploadInstructions =>
      'Якщо вам необхідно надіслати інші документи, завантажте їх тут.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Прийняти';

  @override
  String get exchangeFileUploadStatusInReview => 'Огляд';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Відхилено';

  @override
  String get exchangeFileUploadSuccess => 'Завантажений файл успішно';

  @override
  String get exchangeFileUploadTapToReupload =>
      'Торкніться, щоб завантажити знову';

  @override
  String get exchangeFileUploadTitle => 'Безпечний файл завантаження';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Застосувати вступ до програми тут';

  @override
  String get exchangeReferralsContactSupportMessage => 'Зв\'язатися з нами';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Приєднуйтесь до місії';

  @override
  String get exchangeReferralsMissionLink => 'библбітcoin.com/міс';

  @override
  String get exchangeReferralsTitle => 'Реферальні коди';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Налаштування доступу';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      'Управління 2FA і пароль';

  @override
  String get exchangeSettingsAccountInformationTitle =>
      'Інформація про обліковий запис';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'Документ уже надіслано.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'Цей файл порожній. Виберіть інший.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'Цей файл завеликий. Виберіть менший.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'Цей тип файлу не приймається. Виберіть інший.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'Не вдалося прочитати цей файл. Виберіть інший.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Не вдалося завантажити дані вашого облікового запису. Будь ласка, спробуйте ще раз.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Не вдалося завантажити вашу торгову статистику. Будь ласка, спробуйте ще раз.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Не вдалося завантажити статус вашого вивантаження. Будь ласка, спробуйте ще раз.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'Не вдалося завантажити документ. Будь ласка, спробуйте ще раз.';

  @override
  String get exchangeSettingsLogInTitle => 'Увійти';

  @override
  String get exchangeSettingsRecipientsTitle => 'Отримувачі';

  @override
  String get exchangeSettingsReferralsTitle => 'Реферали';

  @override
  String get exchangeSettingsSecuritySettingsTitle => 'Налаштування безпеки';

  @override
  String get exchangeSettingsTransactionsTitle => 'Твитнуть';

  @override
  String exchangeStatisticsAsOf(String date) {
    return '$date';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Середня ціна';

  @override
  String get exchangeStatisticsBillerStats => 'Статистика рахунків';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Середня ціна за біткоїн під час купівлі';

  @override
  String get exchangeStatisticsBuySellRatio => 'Купити / продати Ratio';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Відсоток загального обсягу між купівлею та продажем';

  @override
  String get exchangeStatisticsBuyStats => 'Статистика';

  @override
  String get exchangeStatisticsBuyTradeCountDesc =>
      'Кількість операцій купівлі біткоїна';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Загальна сума, витрачена на купівлю біткоїна';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Валюта: $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'Немає статистики';

  @override
  String get exchangeStatisticsOrderStats => 'Статистика замовлення';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Середня ціна за біткоїн під час продажу';

  @override
  String get exchangeStatisticsSellStats => 'Статистика продажу';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Кількість операцій продажу біткоїна';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Загальна сума, отримана від продажу біткоїна';

  @override
  String get exchangeStatisticsTitle => 'Статистика';

  @override
  String get exchangeStatisticsTotalAmount => 'Загальна кількість';

  @override
  String get exchangeStatisticsTotalVolume => 'Загальний обсяг торгівлі';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Сукупні обсяги купівлі та продажу у фіатних валютах';

  @override
  String get exchangeStatisticsTradeCount => 'Торговий центр';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count угоди ($currency)',
      many: '$count угод ($currency)',
      few: '$count угоди ($currency)',
      one: '$count угода ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count угоди',
      many: '$count угод',
      few: '$count угоди',
      one: '$count угода',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Об\'єм';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Не вдалося прикріпити журнали. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Зображення';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Невідомий файл';

  @override
  String get exchangeSupportChatEmptyState =>
      'Немає повідомлень. Почати розмову!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Не вдалося отримати дані файлу.';

  @override
  String get exchangeSupportChatInputHint => 'Тип повідомлення...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Не вдалося відкрити вкладення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Не вдалося завантажити повідомлення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Повідомлення не може бути порожнім';

  @override
  String get exchangeSupportChatMessageRequired => 'Необхідне повідомлення';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Не вдалося вибрати файли. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Не вдалося надіслати повідомлення. Спробуйте ще раз.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Підтримка чату';

  @override
  String get exchangeSupportChatYesterday => 'Погода';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Щоб отримати підтримку від живого оператора, спершу потрібно увійти у свій обліковий запис Bull Bitcoin. Це абсолютно безкоштовно, KYC не потрібен — лише адреса електронної пошти.';

  @override
  String get loginButton => 'ЛОГІН';

  @override
  String get notLoggedInTitle => 'Ви не зареєстровані';

  @override
  String get oopsSomethingWentWrong => 'Опери Хтось пішов неправильно';

  @override
  String get retry => 'Птиця';

  @override
  String get settingsAppSettingsTitle => 'Налаштування додатків';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Account Settings';

  @override
  String get settingsErrorSavingSetting =>
      'Не вдалося зберегти це налаштування. Будь ласка, спробуйте ще раз.';

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
