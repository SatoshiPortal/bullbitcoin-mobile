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

  @override
  String get fundExchangeTitle => 'Финансирование';

  @override
  String get fundExchangeAccountTitle => 'Фонд вашего счета';

  @override
  String get fundExchangeAccountSubtitle =>
      'Выберите свою страну и способ оплаты';

  @override
  String get fundExchangeRestrictedTitle => 'Пополнение недоступно';

  @override
  String get fundExchangeRestrictedMessage =>
      'Пополнение недоступно для вашего аккаунта. Пожалуйста, свяжитесь со службой поддержки для получения дополнительной информации.';

  @override
  String get fundExchangeWarningTitle => 'Следите за мошенниками';

  @override
  String get fundExchangeWarningDescription =>
      'Если кто-то просит вас купить биткойн или «помочь вам», будьте осторожны, они могут попытаться обмануть вас!';

  @override
  String get fundExchangeWarningTacticsTitle => 'Общая тактика мошенничества';

  @override
  String get fundExchangeWarningTactic1 => 'Они обещают прибыль от инвестиций';

  @override
  String get fundExchangeWarningTactic2 => 'Они предлагают вам кредит';

  @override
  String get fundExchangeWarningTactic3 =>
      'Они говорят, что работают на сбор долгов или налогов';

  @override
  String get fundExchangeWarningTactic4 =>
      'Они просят отправить биткойн на их адрес';

  @override
  String get fundExchangeWarningTactic5 =>
      'Они просят отправить биткойн на другую платформу';

  @override
  String get fundExchangeWarningTactic6 =>
      'Они хотят, чтобы вы делились своим экраном';

  @override
  String get fundExchangeWarningTactic7 =>
      'Они говорят вам не беспокоиться об этом предупреждении';

  @override
  String get fundExchangeWarningTactic8 =>
      'Они заставляют вас действовать быстро';

  @override
  String get fundExchangeWarningConfirmation =>
      'Я подтверждаю, что меня не просят купить биткойн кем-то еще.';

  @override
  String get fundExchangeContinueButton => 'Продолжить';

  @override
  String get fundExchangeScamConsentError =>
      'Не удалось зарегистрировать ваше согласие. Пожалуйста, попробуйте ещё раз.';

  @override
  String get fundExchangeDoneButton => 'Дон';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 Канада';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 Европа (SEPA)';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 Мексика';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Коста-Рика 1998 год';

  @override
  String get fundExchangeJurisdictionArgentina => '🇦🇷 Аргентина';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Колумбия';

  @override
  String get fundExchangeMethodEmailETransfer => 'Email E-Transfer';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Самый простой и быстрый метод (мгновенный)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Банковский перевод (Wire or EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'Лучший и самый надежный вариант для больших сумм (как и на следующий день)';

  @override
  String get fundExchangeMethodOnlineBillPayment => 'Оплата онлайн-билей';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'Самый простой вариант, но его можно сделать с помощью онлайн-банкинга (3-4 рабочих дня)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'Наличные деньги или дебет в Canada Post';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Лучшее для тех, кто предпочитает платить лично';

  @override
  String get fundExchangeMethodInstantSepa =>
      'Мгновенный и стандартный SEPA-перевод';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Самый быстрый - только для транзакций ниже €30,000';

  @override
  String get fundExchangeMethodRegularSepa => 'Регулярный SEPA';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'Только для более крупных транзакций выше €30,000';

  @override
  String get fundExchangeBankTransferWireTitle => 'Банковский перевод (провод)';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Отправьте телеграфный перевод с вашего банковского счета, используя банковские данные Bull Bitcoin ниже. Ваш банк может потребовать только некоторых частей этих деталей.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Любые средства, которые вы отправляете, будут добавлены в ваш Bull Bitcoin в течение 1-2 рабочих дней.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Имя бенефициара';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Используйте наше официальное фирменное имя. Не используйте «Bull Bitcoin».';

  @override
  String get fundExchangeLabelTransferCode =>
      'Код передачи (добавьте это как описание оплаты)';

  @override
  String get fundExchangeHelpTransferCode =>
      'Добавить это в качестве причины для передачи';

  @override
  String get fundExchangeInfoTransferCode =>
      'Вы должны добавить код передачи как «сообщение» или «разум» при совершении платежа.';

  @override
  String get fundExchangeLabelBankAccountDetails => 'Детали банковского счета';

  @override
  String get fundExchangeLabelSwiftCode => 'Код SWIFT';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Число учреждений';

  @override
  String get fundExchangeLabelTransitNumber => 'Транзитный номер';

  @override
  String get fundExchangeLabelRoutingNumber => 'Номер маршрута';

  @override
  String get fundExchangeLabelBeneficiaryAddress => 'Адрес бенефициаров';

  @override
  String get fundExchangeLabelBankName => 'Название банка';

  @override
  String get fundExchangeLabelBankAddress => 'Адрес нашего банка';

  @override
  String get fundExchangeETransferTitle => 'E-Transfer details';

  @override
  String get fundExchangeETransferDescription =>
      'Любая сумма, которую вы отправляете из своего банка через Email E-Transfer, используя нижеприведенную информацию, будет зачислена на баланс вашего счета Bull Bitcoin в течение нескольких минут.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Используйте это как имя бенефициара E-transfer';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Отправить E-трансфер на эту электронную почту';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Секретный вопрос';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Секретный ответ';

  @override
  String get fundExchangeOnlineBillPaymentTitle => 'Оплата онлайн-билей';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Любая сумма, которую вы отправляете через функцию онлайн-платежей вашего банка, используя информацию ниже, будет зачислена на ваш баланс счета Bull Bitcoin в течение 3-4 рабочих дней.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Поиск списка билеров вашего банка на это имя';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Добавить эту компанию в качестве плательщика - это платежный процессор Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostTitle =>
      'Наличные деньги или дебет в Canada Post';

  @override
  String get fundExchangeCanadaPostStep1 => '1. Перейти в любую точку Канады';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. Попросите кассира отсканировать код QR «Loadhub»';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. Скажите кассиру сумму, которую вы хотите загрузить';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. Кассир попросит увидеть часть выданного правительством ID и убедиться, что имя на вашем ID соответствует вашей учетной записи Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostStep5 =>
      '5. Оплата наличными или дебетовой картой';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. Кассир даст вам квитанцию, держите ее в качестве доказательства оплаты';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. Средства будут добавлены к балансу счета Bull Bitcoin в течение 30 минут';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Код QR';

  @override
  String get fundExchangeSepaTitle => 'SEPA transfer';

  @override
  String get fundExchangeSepaDescription =>
      'Отправка SEPA с вашего банковского счета с использованием деталей ниже ';

  @override
  String get fundExchangeSepaDescriptionExactly => 'точно.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'Использовать только для транзакций ниже €20 000. Для более крупных транзакций используйте вариант регулярного SEPA.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'Использовать только для транзакций выше €20 000. Для небольших транзакций используйте опцию Instant SEPA.';

  @override
  String get fundExchangeLabelIban => 'Номер счета IBAN';

  @override
  String get fundExchangeLabelBicCode => 'Код BIC';

  @override
  String get fundExchangeLabelBankAccountCountry =>
      'Страна с банковским счетом';

  @override
  String get fundExchangeInfoBankCountryUk => 'Наша страна - Великобритания.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'Имя бенефициара должно быть LEONOD. Если вы положите что-нибудь еще, ваш платеж будет отклонен.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'В описании оплаты добавьте код передачи.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Наш официальный адрес, если это требуется вашим банком';

  @override
  String get fundExchangeLabelRecipientName => 'Имя получателя';

  @override
  String get fundExchangeLabelBankCountry => 'Страна';

  @override
  String get fundExchangeLabelRecipientAddress => 'Адрес получателя';

  @override
  String get fundExchangeSpeiTitle => 'Перевод SPEI';

  @override
  String get fundExchangeSpeiDescription =>
      'Перенос средств с помощью вашего CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Сделайте депозит с помощью SPEI-передачи (instant).';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Memo';

  @override
  String get fundExchangeSinpeTitle => 'SINPE Transfer';

  @override
  String get fundExchangeSinpeDescription => 'Трансфер Колонны с помощью SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Bank Transfer (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Bank Transfer (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Банковский перевод';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Отправьте банковский перевод с вашего банковского счета, используя точные банковские данные Аргентины ниже.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Имя получателя';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'Детали оплаты не могут быть загружены в данный момент. Пожалуйста, возвращайтесь и попробуйте снова, выберите другой способ оплаты или вернемся позже.';

  @override
  String get fundExchangeErrorTitleOrdPo404 => 'Способ оплаты недоступен';

  @override
  String get fundExchangeErrorOrdPo404 => 'Нет доступного способа оплаты';

  @override
  String get fundExchangeErrorTitleRcpPo404 => 'Способ оплаты недоступен';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'У вас нет необходимых разрешений для доступа к этому способу пополнения. Либо ваш KYC недостаточен, либо этот способ недоступен для вашего аккаунта';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE недоступен';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'Чтобы использовать этот способ пополнения, ваш номер телефона должен быть зарегистрирован в сети SINPE в Коста-Рике.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'Отсутствуют требования KYC';

  @override
  String get fundExchangeErrorOrdKyc400 =>
      'У вас нет требований KYC для этого действия';

  @override
  String get fundExchangeErrorTitleOrdCop400 =>
      'Неверные данные для пополнения в COP';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Неверные данные запроса для пополнения в COP';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'Не удалось открыть платёжную ссылку. Пожалуйста, попробуйте снова.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 =>
      'Виртуальный платёж не активирован';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Пожалуйста, активируйте опцию виртуального платежа для этого получателя SEPA';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Неверный запрос';

  @override
  String get fundExchangeErrorRcp400 => 'Неверный запрос';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Ошибка при получении банковских кодов. Пожалуйста, попробуйте позже.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'он будет отвергнут.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Как только платеж будет отправлен, он будет добавлен к балансу вашего счета.';

  @override
  String get fundExchangeSinpeLabelPhone => 'Отправить этот номер телефона';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Имя получателя';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Отправка банковского перевода с вашего банковского счета с использованием данных ниже ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'точно';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      '... Средства будут добавлены в ваш баланс.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'Номер счета IBAN (только Колонны)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription => 'Описание оплаты';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp => 'Ваш код передачи.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'Вы должны добавить код передачи как «сообщение» или «разум» или «описание» при совершении платежа. Если вы забыли включить этот код, ваш платеж может быть отклонен.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Имя получателя';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Используйте наше официальное фирменное имя. Не используйте «Bull Bitcoin».';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Отправка банковского перевода с вашего банковского счета с использованием данных ниже ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'точно';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      '... Средства будут добавлены в ваш баланс.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'Номер счета IBAN (только доллары США)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription => 'Описание оплаты';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp => 'Ваш код передачи.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'Вы должны добавить код передачи как «сообщение» или «разум» или «описание» при совершении платежа. Если вы забыли включить этот код, ваш платеж может быть отклонен.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Имя получателя';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Используйте наше официальное фирменное имя. Не используйте «Bull Bitcoin».';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'SINPE Móvil';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Трансфер Колонны с помощью SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Перевод средств в Коста-Рике';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Costa Rica (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Перевод средств в долларах США (USD)';

  @override
  String get doneButton => 'Дон';

  @override
  String get fundExchangeSpeiTransfer => 'Перевод SPEI';

  @override
  String get fundExchangeSpeiSubtitle =>
      'Перенос средств с помощью вашего CLABE';

  @override
  String get fundExchangeBankTransfer => 'Банковский перевод';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Отправить банковский перевод с вашего банковского счета';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'Если вы превысите дневной лимит транзакций, транзакция не пройдет. Вам придется обратиться в службу поддержки.';

  @override
  String get fundExchangeCopSenderName => 'Имя отправителя';

  @override
  String get fundExchangeCopIssuingBank => 'Банк-эмитент';

  @override
  String get fundExchangeCopSelectBankError =>
      'Пожалуйста, выберите банк-эмитент';

  @override
  String get fundExchangeCopAmount => 'Сумма';

  @override
  String get fundExchangeCopEnterAmountError => 'Пожалуйста, введите сумму';

  @override
  String get fundExchangeCopValidAmountError =>
      'Пожалуйста, введите действительную сумму';

  @override
  String get fundExchangeCopGeneratePaymentLink => 'Создать ссылку для оплаты';

  @override
  String get fundExchangeCopRedirectMessage =>
      'Вы будете перенаправлены на внешнюю страницу для совершения платежа.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Открыть ссылку для оплаты';

  @override
  String get fundExchangeErrorNetwork =>
      'Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'Конфиденциальный SEPA';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'Личный виртуальный IBAN для конфиденциального пополнения';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Добавить это как номер счета';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'Этот уникальный номер аккаунта создан только для вас';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Не поставить';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' слово «Bitcoin» или «Crypto» в описании оплаты. Это блокирует вашу оплату.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Выберите валюту';

  @override
  String get exchangeCurrencyDropdownValidation =>
      'Пожалуйста, выберите валюту';

  @override
  String get exchangeAmountInputTitle => 'Введите сумму';

  @override
  String get exchangeAmountInputValidationEmpty => 'Пожалуйста, введите сумму';

  @override
  String get exchangeAmountInputValidationInvalid => 'Неверная сумма';

  @override
  String get exchangeAmountInputValidationZero =>
      'Сумма должна быть больше нуля';

  @override
  String get exchangeAmountInputValidationInsufficient =>
      'Недостаточный баланс';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Bitcoin Адрес';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel => 'Молния (LN-адрес)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Liquid адрес';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Введите адрес';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Настенный адрес сохранен успешно';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Установить адреса кошелька по умолчанию для автоматического снятия Bitcoin.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Bitcoin адрес';

  @override
  String get exchangeDcaAddressLabelLightning => 'Адрес освещения';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Жидкий адрес';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get save => 'Сохранить';

  @override
  String get exchangeBitcoinWalletsLoadFailed =>
      'Failed to load default wallets';

  @override
  String get exchangeBitcoinWalletsAddressEmpty => 'Address cannot be empty';

  @override
  String get exchangeBitcoinWalletsSaveFailed =>
      'Failed to save wallet address';

  @override
  String get exchangeBitcoinWalletsDeleteFailed =>
      'Failed to delete wallet address';

  @override
  String destinationExpectedType(String type) {
    return 'Enter or scan a valid $type.';
  }

  @override
  String get wizardExchangeTitle => 'BULL Exchange';

  @override
  String get wizardExchangeDescription =>
      'Buy, sell and pay with Bull Bitcoin directly from your wallet.';
}
