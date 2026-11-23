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

  @override
  String get settingsTermsOfServiceTitle => 'Условия службы';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get autoBuyTitle => 'Автопокупка';

  @override
  String get autoBuyDescription =>
      'Автоматически покупайте Bitcoin каждый раз, когда пополняете свой счёт';

  @override
  String get autoBuyActivate => 'Включить автопокупку';

  @override
  String get autoBuyDeactivate => 'Отключить автопокупку';

  @override
  String get autoBuyCancelTitle => 'Отменить автопокупку?';

  @override
  String get autoBuyCancelMessage =>
      'При следующем пополнении счёта Bitcoin не будет куплен автоматически.';

  @override
  String get autoBuyDeactivateConfirm => 'Да, отключить';

  @override
  String get autoBuyHowItWorks => 'Как это работает';

  @override
  String get autoBuyConnectWallet =>
      'Подключите свой кошелёк Bitcoin, Lightning или Liquid';

  @override
  String get autoBuyPurchaseCreated =>
      'Каждый раз, когда вы пополняете свой счёт Bull Bitcoin, автоматически создаётся покупка Bitcoin.';

  @override
  String get autoBuyBitcoinSent =>
      'Bitcoin отправляется напрямую в ваш собственный кошелёк.';

  @override
  String get autoBuyRiskDisclaimer =>
      'Исполнение ордера не гарантируется. Задержки или изменения цены между пополнением и покупкой могут изменить итоговый курс.';

  @override
  String get autoBuyGetStarted => 'Начните с автопокупки';

  @override
  String get autoBuyConfirmTitle => 'Подтвердить автопокупку';

  @override
  String get autoBuyInfoMessage =>
      'Любая сумма, добавленная на ваш счёт, будет конвертирована в Bitcoin по текущему обменному курсу и отправлена в ваш кошелёк.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Ваш счёт Bull Bitcoin недоступен. Попробуйте позже.';

  @override
  String get autoBuyWalletRequiredError =>
      'Добавьте хотя бы один адрес Bitcoin, Lightning или Liquid по умолчанию.';

  @override
  String get autoBuyUpdateError =>
      'Не удалось обновить автопокупку. Попробуйте позже.';

  @override
  String get exchangeAuthLoginFailedTitle => 'Не удалось';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'Произошла ошибка, пожалуйста, попробуйте снова войти.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'ХОРОШО';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';

  @override
  String get settingsScreenTitle => 'Настройка';

  @override
  String get transactionHistoryTitle => 'История транзакций';

  @override
  String get exchangeHomeDepositButton => 'Депозит';

  @override
  String get exchangeHomeWithdrawButton => 'Выделить';

  @override
  String get exchangeDcaUnableToGetConfig =>
      'Невозможно получить конфигурацию DCA';

  @override
  String get exchangeDcaDeactivateTitle => 'Отключение покупки';

  @override
  String get exchangeDcaActivateTitle => 'Активировать покупку';

  @override
  String get exchangeDcaHideSettings => 'Настройки вызова';

  @override
  String get exchangeDcaViewSettings => 'Параметры просмотра';

  @override
  String get exchangeDcaCancelDialogTitle => 'Отменить покупку Bitcoin?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Ваш повторяющийся план покупки Bitcoin прекратится, и запланированные покупки закончатся. Чтобы перезапустить, вам нужно будет настроить новый план.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Отмена';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Да, деактивация';

  @override
  String get exchangeDcaFrequencyHour => 'час';

  @override
  String get exchangeDcaFrequencyDay => 'день';

  @override
  String get exchangeDcaFrequencyWeek => 'неделя';

  @override
  String get exchangeDcaFrequencyMonth => 'месяц';

  @override
  String get exchangeDcaNetworkBitcoin => 'Bitcoin Network';

  @override
  String get exchangeDcaNetworkLightning => 'Сеть освещения';

  @override
  String get exchangeDcaNetworkLiquid => 'Жидкая сеть';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'Вы покупаете $amount каждый $frequency через $network, если на вашем счете есть средства.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel: $address';
  }

  @override
  String get exchangeKycLevelLight => 'Свет';

  @override
  String get exchangeKycLevelLimited => 'Limited';

  @override
  String get exchangeKycCardTitle => 'Заполните KYC';

  @override
  String get exchangeKycCardSubtitle => 'Удаление лимитов транзакций';

  @override
  String get homeActionBuy => 'Купить';

  @override
  String get homeActionSell => 'Продать';

  @override
  String get homeActionPay => 'Оплатить';

  @override
  String get homeActionTransfer => 'Своп';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => 'Поиск получателей по имени или этикетке';

  @override
  String get recipientsScreenTitle => 'Выбрать получателя';

  @override
  String get recipientsScreenSubtitle => 'Кому вы платите?';

  @override
  String get recipientsTabNew => 'Новый получатель';

  @override
  String get recipientsTabList => 'Мои фиатные получатели';

  @override
  String get recipientsPayoutMethod => 'Способ выплаты';

  @override
  String get recipientsFilterByJurisdiction => 'Фильтр по юрисдикции:';

  @override
  String get recipientsListEmpty => 'Получатели не найдены.';

  @override
  String get recipientsContinue => 'Продолжить';

  @override
  String get recipientsJurisdictionAll => 'Все юрисдикции';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Канада';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Европа (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Мексика';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Коста-Рика';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Аргентина';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Колумбия';

  @override
  String get recipientsTypeInteracEmail => 'Денежный перевод по email';

  @override
  String get recipientsTypeBillPayment => 'Оплата счёта';

  @override
  String get recipientsTypeBankTransfer => 'Банковский перевод';

  @override
  String get recipientsTypeSepa => 'SEPA-перевод';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Карта';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Аргентина';

  @override
  String get recipientsTypeBankAccountCo => 'Банковский счёт COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'Эл. почта';

  @override
  String get recipientsInfoPayee => 'Получатель';

  @override
  String get recipientsInfoAccount => 'Счёт';

  @override
  String get recipientsInfoPhone => 'Телефон';

  @override
  String get recipientsInfoCard => 'Карта';

  @override
  String get recipientsInfoLabel => 'Метка';

  @override
  String get recipientsValidationFieldRequired =>
      'Это поле не может быть пустым';

  @override
  String get recipientsLabelOptional => 'Метка (необязательно)';

  @override
  String get recipientsLabelHint => 'Введите метку для этого получателя';

  @override
  String get recipientsFieldName => 'Имя';

  @override
  String get recipientsFieldNameHint => 'Введите имя получателя';

  @override
  String get recipientsFieldRecipientNameLabel => 'Имя получателя';

  @override
  String get recipientsFieldPhoneNumber => 'Номер телефона';

  @override
  String get recipientsFieldPhoneNumberHint => 'Введите номер телефона';

  @override
  String get recipientsFieldSinpePhoneNumberHint => '8 цифр без кода страны';

  @override
  String get recipientsFieldDocumentType => 'Тип ID получателя';

  @override
  String get recipientsFieldDocumentNumberHint => 'Введите номер ID получателя';

  @override
  String get recipientsFieldOwnerName => 'Имя владельца';

  @override
  String get recipientsFieldOwnerNameHint => 'Введите имя владельца';

  @override
  String get recipientsAccountOwnerQuestion => 'Кому принадлежит этот счёт?';

  @override
  String get recipientsAccountOwnerMine => 'Это мой счёт';

  @override
  String get recipientsAccountOwnerSomeoneElse => 'Это счёт другого лица';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'Введите IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'Введите номер CLABE';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Введите номер CVU/CBU';

  @override
  String get recipientsFieldBankInstitution => 'Банковское учреждение';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Выберите банковское учреждение';

  @override
  String get recipientsValidationBankInstitution =>
      'Пожалуйста, выберите банковское учреждение';

  @override
  String get recipientsFieldAccountType => 'Тип счёта';

  @override
  String get recipientsAccountTypeSavings => 'Сберегательный';

  @override
  String get recipientsAccountTypeChecking => 'Расчётный';

  @override
  String get recipientsFieldBankAccountNumber => 'Номер банковского счёта';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Введите номер банковского счёта';

  @override
  String get recipientsCopDocCc =>
      'Удостоверение гражданина (Cédula de Ciudadanía)';

  @override
  String get recipientsCopDocCe =>
      'Удостоверение иностранца (Cédula de Extranjería)';

  @override
  String get recipientsCopDocNit => 'Налоговый идентификатор (NIT)';

  @override
  String get recipientsCopDocPassport => 'Паспорт';

  @override
  String get recipientsCopDocTi =>
      'Удостоверение личности (Tarjeta de Identidad)';

  @override
  String get recipientsCopDocRegistroCivil =>
      'Запись актов гражданского состояния (Registro Civil)';

  @override
  String get recipientsCopDocCcRecipientNumber => 'Номер cédula получателя';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Номер cédula de extranjería получателя';

  @override
  String get recipientsCopDocNitRecipientNumber => 'Налоговый ID получателя';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Номер паспорта получателя';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Номер удостоверения личности получателя';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Номер записи гражданского реестра получателя';

  @override
  String get recipientsFieldDebitCard => 'Номер дебетовой карты';

  @override
  String get recipientsFieldDebitCardHint => 'Введите номер дебетовой карты';

  @override
  String get recipientsFieldOwnerNameSinpeHint =>
      'Имя владельца появится здесь';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Удалите код страны (+506). Введите только 8-значный номер';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Используйте только цифры (без букв или символов)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Введите все 8 цифр номера телефона';

  @override
  String get recipientsValidationSinpeOwner =>
      'Пожалуйста, подтвердите номер телефона';

  @override
  String get recipientsFieldEmailAddress => 'Адрес электронной почты';

  @override
  String get recipientsFieldEmailAddressHint =>
      'Введите адрес электронной почты';

  @override
  String get recipientsFieldSecurityQuestion => 'Контрольный вопрос';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Введите контрольный вопрос (10-40 символов)';

  @override
  String get recipientsFieldSecurityAnswer => 'Ответ на контрольный вопрос';

  @override
  String get recipientsFieldSecurityAnswerHint =>
      'Введите ответ на контрольный вопрос';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'Контрольный вопрос должен содержать не менее 10 символов';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 символов';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Код учреждения';

  @override
  String get recipientsFieldInstitutionCodeHint => 'Введите код учреждения';

  @override
  String get recipientsFieldInstitutionNumber => 'Номер учреждения';

  @override
  String get recipientsFieldInstitutionNumberHint => 'Введите номер учреждения';

  @override
  String get recipientsFieldTransitNumber => 'Транзитный номер';

  @override
  String get recipientsFieldTransitNumberHint => 'Введите транзитный номер';

  @override
  String get recipientsFieldAccountNumber => 'Номер счёта';

  @override
  String get recipientsFieldAccountNumberHint => 'Введите номер счёта';

  @override
  String get recipientsFieldDefaultComment =>
      'Комментарий по умолчанию (необязательно)';

  @override
  String get recipientsFieldDefaultCommentHint =>
      'Введите комментарий по умолчанию';

  @override
  String get recipientsFieldCorporateAccount => 'Корпоративный счёт';

  @override
  String get recipientsFieldFirstName => 'Имя';

  @override
  String get recipientsFieldFirstNameHint => 'Введите имя';

  @override
  String get recipientsFieldLastName => 'Фамилия';

  @override
  String get recipientsFieldLastNameHint => 'Введите фамилию';

  @override
  String get recipientsFieldCorporateName => 'Название организации';

  @override
  String get recipientsFieldCorporateNameHint => 'Введите название организации';

  @override
  String get recipientsFieldBillerName => 'Название поставщика';

  @override
  String get recipientsFieldBillerNameHint => 'Найдите и выберите поставщика';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Введите 3 или более символов для поиска';

  @override
  String get recipientsValidationBillerSelect =>
      'Пожалуйста, выберите поставщика из списка';

  @override
  String get recipientsFieldPayeeAccountNumber => 'Номер счёта получателя';

  @override
  String get recipientsErrorLoadFailed =>
      'Не удалось загрузить ваших получателей. Попробуйте ещё раз.';

  @override
  String get recipientsErrorSaveFailed =>
      'Не удалось сохранить этого получателя. Проверьте данные и попробуйте ещё раз.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'Не удалось проверить этот номер телефона. Проверьте его и попробуйте ещё раз.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'Не удалось выполнить поиск получателей платежей. Попробуйте ещё раз.';

  @override
  String get recipientsErrorNetwork =>
      'Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get recipientsListPullToRetry => 'Потяните вниз, чтобы повторить.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'Получатель сохранён, но продолжить не удалось. Найдите его в списке, чтобы продолжить.';

  @override
  String get recipientsTypeConfidentialSepa => 'Конфиденциальный SEPA';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'У вас нет необходимых разрешений для доступа к этому способу пополнения. Либо ваш KYC недостаточен, либо этот способ недоступен для вашего аккаунта';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'Чтобы активировать конфиденциальный SEPA, вы должны быть резидентом Европейского союза.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Активация получателя';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Ваш получатель активируется для Конфиденциального SEPA. Это может занять несколько минут.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Получатель не активирован для Конфиденциального SEPA';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'Этот получатель ещё не активирован для Конфиденциального SEPA. Сейчас мы его активируем. Это может занять несколько минут. Пока вы можете использовать Мгновенный и обычный SEPA.';

  @override
  String get recipientsConfidentialSepaActivatedTitle =>
      'Получатель активирован';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Ваш получатель теперь активен для Конфиденциального SEPA.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Использовать Мгновенный и обычный SEPA вместо этого';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle =>
      'Активировать Конфиденциальный SEPA?';

  @override
  String get recipientsVirtualIbanNewBadge => 'Новое';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Пополняйте счёт конфиденциально с помощью личного виртуального IBAN на ваше имя. Это бесплатно.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'Когда вы отправляете средства из своего банка в Bull Bitcoin, это выглядит как перевод самому себе.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'Код перевода не нужен.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Важно: имя должно совпадать';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Имя владельца банковского счёта должно точно совпадать с именем вашего виртуального IBAN в Bull Bitcoin, иначе перевод будет автоматически возвращён. Имена не совпадают? Свяжитесь с поддержкой.';

  @override
  String get recipientsVirtualIbanAccountOwnerName => 'Имя владельца счёта';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'Подтверждаю, что имя совпадает с моим банковским счётом (счетами)';

  @override
  String get recipientsVirtualIbanActivate =>
      'Активировать Конфиденциальный SEPA';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Активация Конфиденциального SEPA...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Создаём ваш виртуальный IBAN. Это может занять несколько минут.';

  @override
  String get recipientsVirtualIbanActivatedTitle =>
      'Конфиденциальный SEPA активирован';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'Теперь вы можете использовать личный виртуальный IBAN, чтобы выводить деньги конфиденциально.';

  @override
  String get recipientsVirtualIbanCopied => 'Копируется в буфер обмена';

  @override
  String get recipientsVirtualIbanDone => 'Дон';

  @override
  String get recipientsVirtualIbanRecipientName => 'Имя получателя';

  @override
  String get recipientsVirtualIbanIbanLabel => 'Номер виртуального счёта IBAN';

  @override
  String get recipientsVirtualIbanCountry => 'Страна с банковским счетом';

  @override
  String get recipientsVirtualIbanBic => 'Код BIC';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'Теперь вы можете использовать личный виртуальный IBAN, чтобы вносить деньги конфиденциально.';

  @override
  String get recipientsVirtualIbanShowDetails =>
      'Показать реквизиты моего виртуального IBAN';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Пополняйте счёт конфиденциально с помощью личного виртуального IBAN на ваше имя. Пополнение будет выглядеть как платёж самому себе, без кода перевода.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Адрес банка';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'Официальный адрес банка, если ваш банк его запросит.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'Имена в вашем банке и в виртуальном IBAN должны совпадать, иначе переводы будут автоматически возвращены.';

  @override
  String get recipientsFieldBankAccountIban => 'Номер банковского счёта (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'Выводы средств отображаются как перевод самому себе с именем вашего счёта';

  @override
  String get withdrawAmountTitle => 'Цикл:';

  @override
  String get withdrawAmountContinue => 'Продолжить';

  @override
  String get withdrawConfirmTitle => 'Подтвердить вывод';

  @override
  String get withdrawConfirmRecipientName => 'Имя получателя';

  @override
  String get withdrawConfirmAmount => 'Сумма';

  @override
  String get withdrawConfirmEmail => 'Email';

  @override
  String get withdrawConfirmPayee => 'Payee';

  @override
  String get withdrawConfirmAccount => 'Счет';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => 'Телефон';

  @override
  String get withdrawConfirmCard => 'Карта';

  @override
  String get withdrawConfirmButton => 'Подтвердить вывод';

  @override
  String get withdrawSuccessTitle => 'Вывод';

  @override
  String get withdrawSuccessOrderDetails => 'Детали заказа';

  @override
  String get withdrawConfirmBankAccount => 'Банковский счет';

  @override
  String get withdrawOwnershipQuestion => 'Кому принадлежит этот счет?';

  @override
  String get withdrawOwnershipMyAccount => 'Это мой счет';

  @override
  String get withdrawOwnershipOtherAccount => 'Это чей-то счет';

  @override
  String get withdrawUnauthenticatedError =>
      'Вы не проверены. Пожалуйста, зайдите, чтобы продолжить.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'Минимальная сумма $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'Максимальная сумма $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle =>
      'Данные безопасности перевода';

  @override
  String get withdrawInteracSaveAsDefault =>
      'Сохранить эти данные по умолчанию';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'Контрольный вопрос должен содержать от 3 до 40 символов';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'Контрольный ответ должен содержать от 3 до 40 символов';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Используйте буквы, цифры или дефисы без пробелов';

  @override
  String get withdrawUnexpectedError =>
      'Ваш вывод средств сейчас не удалось выполнить. Пожалуйста, попробуйте снова или обратитесь в поддержку.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Пожалуйста, активируйте опцию конфиденциального платежа для этого получателя SEPA.';

  @override
  String get limitOrdersTitle => 'Limit orders';

  @override
  String get limitOrdersActiveTitle => 'Active limit orders';

  @override
  String get limitOrdersCreateNew => 'Create new';

  @override
  String get limitOrdersMaximumActiveHint =>
      'Cancel an active order before creating another one.';

  @override
  String limitOrdersBuyAt(String price) {
    return 'Buy at $price';
  }

  @override
  String get limitOrdersCancelAll => 'Cancel all';

  @override
  String get limitOrdersCancelAllTitle => 'Cancel all active limit orders?';

  @override
  String get limitOrdersCancelAllMessage =>
      'This is permanent. None of these orders will execute after cancellation.';

  @override
  String get limitOrdersDialogConfirm => 'Confirm';

  @override
  String get limitOrdersDone => 'Done';

  @override
  String get limitOrdersTargetPrice => 'Target price';

  @override
  String get limitOrdersFiatAmount => 'Amount';

  @override
  String get limitOrdersEstimatedBuyPrice => 'Estimated buy price';

  @override
  String get limitOrderDetailsTitle => 'Limit order details';

  @override
  String get limitOrderDetailsStatus => 'Status';

  @override
  String get limitOrderDetailsNumber => 'Order number';

  @override
  String get limitOrderDetailsAddress => 'Payout address';

  @override
  String get limitOrderDetailsCreated => 'Created';

  @override
  String get limitOrderDetailsExpires => 'Expires';

  @override
  String get limitOrderCancel => 'Cancel limit order';

  @override
  String get limitOrderCancelTitle => 'Cancel this limit order?';

  @override
  String get limitOrderCancelMessage =>
      'Cancellation is permanent and this order will no longer execute.';

  @override
  String get limitOrderStatusActive => 'Active';

  @override
  String get limitOrderStatusExecuted => 'Executed';

  @override
  String get limitOrderStatusCancelled => 'Cancelled';

  @override
  String get limitOrderStatusExpired => 'Expired';

  @override
  String get limitOrderStatusFailed => 'Failed';

  @override
  String get limitOrdersAccountUnavailableError =>
      'Your Bull Bitcoin account or balances could not be loaded. Please try again.';

  @override
  String get limitOrderNotFoundError => 'This limit order could not be found.';

  @override
  String get limitOrdersLoadError =>
      'Limit orders could not be loaded. Please try again.';

  @override
  String get limitOrderCancellationError =>
      'The limit order could not be cancelled. Please try again.';

  @override
  String get limitOrderDetailsEstimatedBitcoin => 'Estimated bitcoin';

  @override
  String get limitOrdersMaximumActiveError =>
      'You already have five active limit orders. Cancel one before creating another.';

  @override
  String get limitOrderInvalidAddressError =>
      'The selected payout address is not valid.';

  @override
  String get limitOrderCreationError =>
      'The limit order could not be created. Please try again.';

  @override
  String get exchangeSettingsLogOutTitle => 'Выход';

  @override
  String get logoutConfirmationTitle => 'Подтвердить выход';

  @override
  String get logoutConfirmationDescription =>
      'Вы уверены, что хотите выйти из своей учетной записи Bull Bitcoin? Вам нужно будет снова войти в систему, чтобы получить доступ к функциям обмена.';

  @override
  String get logoutConfirmationCancel => 'Отмена';

  @override
  String get logoutConfirmationLogout => 'Выйти';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationDescription =>
      'Это отправит запрос на удаление учётной записи в нашу службу поддержки. Ваша учётная запись будет удалена в течение 5 рабочих дней.';

  @override
  String get deleteAccountConfirmationCancel => 'Cancel';

  @override
  String get deleteAccountConfirmationDelete => 'Delete Account';

  @override
  String get deleteAccountSuccessTitle =>
      'Запрос на удаление учётной записи отправлен';

  @override
  String get deleteAccountSuccessDescription =>
      'Ваш запрос на удаление учётной записи был отправлен. Он будет обработан в течение 5 рабочих дней.';

  @override
  String get deleteAccountSuccessClose => 'Close';
}
