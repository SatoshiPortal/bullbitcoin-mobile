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
  String get fundExchangeTitle => 'Фінансування';

  @override
  String get fundExchangeAccountTitle => 'Оберіть Ваш рахунок';

  @override
  String get fundExchangeAccountSubtitle => 'Оберіть країну та спосіб оплати';

  @override
  String get fundExchangeRestrictedTitle => 'Поповнення недоступне';

  @override
  String get fundExchangeRestrictedMessage =>
      'Поповнення недоступне для вашого облікового запису. Будь ласка, зверніться до служби підтримки для отримання додаткової інформації.';

  @override
  String get fundExchangeWarningTitle => 'Дивитися для шампанів';

  @override
  String get fundExchangeWarningDescription =>
      'Якщо хтось запитує вас купити Біткойн або \"допомоги вам\", будьте обережні, вони можуть бути намагатися з вами!';

  @override
  String get fundExchangeWarningTacticsTitle => 'Поширена тактика шампана';

  @override
  String get fundExchangeWarningTactic1 =>
      'Вони перспективні повернення інвестицій';

  @override
  String get fundExchangeWarningTactic2 => 'Ми пропонуємо Вам кредит';

  @override
  String get fundExchangeWarningTactic3 =>
      'Повідомляємо, що вони працюють за боргу або податкову збірку';

  @override
  String get fundExchangeWarningTactic4 =>
      'Вони просять надсилати Біткойн на свою адресу';

  @override
  String get fundExchangeWarningTactic5 =>
      'Вони просять надсилати Біткойн на іншій платформі';

  @override
  String get fundExchangeWarningTactic6 =>
      'Вони хочуть поділитися своїм екраном';

  @override
  String get fundExchangeWarningTactic7 => 'Не хвилюйтеся про це попередження';

  @override
  String get fundExchangeWarningTactic8 => 'Натискаємо, щоб діяти швидко';

  @override
  String get fundExchangeWarningConfirmation =>
      'Я підтверджу, що я не зажадав купити Біткойн іншим.';

  @override
  String get fundExchangeContinueButton => 'Продовжити';

  @override
  String get fundExchangeScamConsentError =>
      'Не вдалося зареєструвати вашу згоду. Будь ласка, спробуйте ще раз.';

  @override
  String get fundExchangeDoneButton => 'Сонце';

  @override
  String get fundExchangeJurisdictionCanada => 'Українська';

  @override
  String get fundExchangeJurisdictionEurope => '浜у 涓 蹇';

  @override
  String get fundExchangeJurisdictionMexico => 'Українська';

  @override
  String get fundExchangeJurisdictionCostaRica => 'й Костел Зірки';

  @override
  String get fundExchangeJurisdictionArgentina => 'й';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Колумбія';

  @override
  String get fundExchangeMethodEmailETransfer => 'Електронна пошта';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Найвищий і найшвидший метод (інстант)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Банківський переказ (Wire або EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'Кращий і найнадійніший варіант для збільшення кількості (наприклад, або наступного дня)';

  @override
  String get fundExchangeMethodOnlineBillPayment => 'Онлайн платіж';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'Найменший варіант, але можна зробити через онлайн-банкінг (3-4 робочих днів)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'Особистий готівковий або дебет в Канаді';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Найкращі для тих, хто віддає перевагу оплаті';

  @override
  String get fundExchangeMethodInstantSepa =>
      'Миттєвий і стандартний SEPA-переказ';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Найшвидший - Тільки для операцій нижче €30,000';

  @override
  String get fundExchangeMethodRegularSepa => 'Звичайна СПА';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'Тільки для збільшення операцій над €30,000';

  @override
  String get fundExchangeBankTransferWireTitle => 'Банківський переказ';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації. Введіть номер мобільного, який Ви вказали при укладаннi договору.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Будь-які кошти, які ви надішлемо, будуть додані до Біткойн протягом 1-2 робочих днів.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Ім\'я одержувача';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Використовуйте нашу офіційну назву компанії. Не використовуйте \"Bull Bitcoin\".';

  @override
  String get fundExchangeLabelTransferCode =>
      'Поштовий індекс (за умови оплати)';

  @override
  String get fundExchangeHelpTransferCode => 'Додати це з причини передачі';

  @override
  String get fundExchangeInfoTransferCode =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації.';

  @override
  String get fundExchangeLabelBankAccountDetails =>
      'Деталі банківського рахунку';

  @override
  String get fundExchangeLabelSwiftCode => 'SWIFT код';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Номер установи';

  @override
  String get fundExchangeLabelTransitNumber => 'Кількість переходів';

  @override
  String get fundExchangeLabelRoutingNumber => 'Номер маршрутизації';

  @override
  String get fundExchangeLabelBeneficiaryAddress => 'Адреса отримувача';

  @override
  String get fundExchangeLabelBankName => 'Назва банку';

  @override
  String get fundExchangeLabelBankAddress => 'Адреса банку';

  @override
  String get fundExchangeETransferTitle => 'Деталі E-Transfer';

  @override
  String get fundExchangeETransferDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Використовуйте це як доменне ім\'я E-transfer';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Надіслати E-переказ на електронну пошту';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Таємне питання';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Секрет відповіді';

  @override
  String get fundExchangeOnlineBillPaymentTitle => 'Онлайн платіж';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Додайте цю компанію як Payee - це Біткойн-процесор';

  @override
  String get fundExchangeCanadaPostTitle =>
      'Особистий готівковий або дебет в Канаді';

  @override
  String get fundExchangeCanadaPostStep1 =>
      '1,1 км Перейти на будь-яке місцезнаходження Канади';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2,2 км Запитайте касіра для сканування QR-коду «Loadhub»';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. У Розкажіть касіра суму, яку ви хочете завантажити';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. У Касира попросить бачити шматок державної ідентифікаційної особи та перевірити, що ім\'я на Ваш ідентифікатор відповідає обліковому запису Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostStep5 =>
      '5. Умань Оплата готівкою або дебетовою карткою';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. Жнівень При отриманні грошового посередника ви зможете отримати квитанцію, зберігати її як підтвердження платежу';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. Про нас Кошти будуть додані в баланс облікового запису Bull Bitcoin протягом 30 хвилин';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Код товару:';

  @override
  String get fundExchangeSepaTitle => 'Передача СПА';

  @override
  String get fundExchangeSepaDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації ';

  @override
  String get fundExchangeSepaDescriptionExactly => 'точно.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'Тільки використовуйте для операцій нижче 20 000 євро. Для збільшення операцій використовуйте звичайний варіант СПА.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'Тільки для операцій над €20,000. Для менших операцій використовуйте варіант СПА.';

  @override
  String get fundExchangeLabelIban => 'Номер рахунку IBAN';

  @override
  String get fundExchangeLabelBicCode => 'Код BIC';

  @override
  String get fundExchangeLabelBankAccountCountry =>
      'Країна банківського рахунку';

  @override
  String get fundExchangeInfoBankCountryUk =>
      'EnglishDeutschPусский简体中文中國傳統EspañolالعربيةFrançaisελληνικάDanskАнглійскаябългарски.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'Назва бенефіціара повинна бути LEONOD. Якщо ви поставите щось інше, то ваш платіж буде відхилений.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'У описі платежу додайте код переказу.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Наша офіційна адреса, якщо це необхідно для Вашого банку';

  @override
  String get fundExchangeLabelRecipientName => 'Ім\'я одержувача';

  @override
  String get fundExchangeLabelBankCountry => 'Банк країни';

  @override
  String get fundExchangeLabelRecipientAddress => 'Адреса одержувача';

  @override
  String get fundExchangeSpeiTitle => 'Трансфер SPEI';

  @override
  String get fundExchangeSpeiDescription =>
      'Перерахування коштів за допомогою CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Зробіть депозит за допомогою SPEI переказу (вхід).';

  @override
  String get fundExchangeLabelClabe => 'КЛАБ';

  @override
  String get fundExchangeLabelMemo => 'Мамо';

  @override
  String get fundExchangeSinpeTitle => 'Трансфер SINPE';

  @override
  String get fundExchangeSinpeDescription =>
      'Трансфер Колони за допомогою SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Банківський переказ (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Банківський переказ (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Банківський переказ';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Ім\'я одержувача';

  @override
  String get fundExchangeLabelCvu => 'КВУ';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'У зв\'язку з тим, що платіж не може бути завантажений. Будь ласка, поверніть і спробуйте знову, оберіть інший спосіб оплати або поверніть пізніше.';

  @override
  String get fundExchangeErrorTitleOrdPo404 => 'Спосіб оплати недоступний';

  @override
  String get fundExchangeErrorOrdPo404 => 'Немає доступного способу оплати';

  @override
  String get fundExchangeErrorTitleRcpPo404 => 'Спосіб оплати недоступний';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'У вас немає необхідних дозволів для доступу до цього способу поповнення. Або ваш KYC недостатній, або цей спосіб недоступний для вашого облікового запису';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE недоступний';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'Щоб отримати доступ до цього способу поповнення, ваш номер телефону має бути зареєстрований у мережі SINPE в Коста-Риці.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'Відсутні вимоги KYC';

  @override
  String get fundExchangeErrorOrdKyc400 => 'У вас немає вимог KYC для цієї дії';

  @override
  String get fundExchangeErrorTitleOrdCop400 =>
      'Невірні дані для поповнення в COP';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Невірні дані запиту для поповнення в COP';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'Не вдалося відкрити платіжне посилання. Будь ласка, спробуйте ще раз.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 =>
      'Віртуальний платіж не активовано';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Будь ласка, активуйте опцію віртуального платежу для цього отримувача SEPA';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Невірний запит';

  @override
  String get fundExchangeErrorRcp400 => 'Невірний запит';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Помилка під час отримання банківських кодів. Будь ласка, спробуйте пізніше.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'вона буде відхилена.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Після того, як платіж буде відправлено, він буде додано до Вашого балансу рахунку.';

  @override
  String get fundExchangeSinpeLabelPhone => 'Надіслати номер телефону';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Ім\'я одержувача';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'до';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      'й Кошти будуть додані в баланс Вашого рахунку.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'Номер облікового запису IBAN (тільки лишеклони)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription => 'Опис платежу';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp => 'Поштовий індекс.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації. Якщо ви забуваєте включити цей код, ваш платіж може бути відхилений.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Ім\'я одержувача';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Використовуйте нашу офіційну назву компанії. Не використовуйте \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Кедула Юрійівна';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'до';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      'й Кошти будуть додані в баланс Вашого рахунку.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'Номер рахунку IBAN (тільки тільки США)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription => 'Опис платежу';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp => 'Поштовий індекс.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації. Якщо ви забуваєте включити цей код, ваш платіж може бути відхилений.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Ім\'я одержувача';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Використовуйте нашу офіційну назву компанії. Не використовуйте \"Bull Bitcoin\".';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Кедула Юрійівна';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'СИНПО Мохол';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Трансфер Колони за допомогою SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Коста-Рика (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Трансфер кошти в Коста-Рикан Колон (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Коста-Рика (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Перерахування коштів у доларах США (USD)';

  @override
  String get doneButton => 'Сонце';

  @override
  String get fundExchangeSpeiTransfer => 'Трансфер SPEI';

  @override
  String get fundExchangeSpeiSubtitle =>
      'Перерахування коштів за допомогою CLABE';

  @override
  String get fundExchangeBankTransfer => 'Банківський переказ';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Введіть номер мобільного, який Ви вказали при укладаннi договору з банком - для ідентифікації';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'Якщо ви перевищите денний ліміт транзакцій, транзакція не вдасться. Вам доведеться звернутися до служби підтримки.';

  @override
  String get fundExchangeCopSenderName => 'Ім\'я відправника';

  @override
  String get fundExchangeCopIssuingBank => 'Банк-емітент';

  @override
  String get fundExchangeCopSelectBankError =>
      'Будь ласка, виберіть банк-емітент';

  @override
  String get fundExchangeCopAmount => 'Сума';

  @override
  String get fundExchangeCopEnterAmountError => 'Будь ласка, введіть суму';

  @override
  String get fundExchangeCopValidAmountError =>
      'Будь ласка, введіть дійсну суму';

  @override
  String get fundExchangeCopGeneratePaymentLink =>
      'Створити посилання на оплату';

  @override
  String get fundExchangeCopRedirectMessage =>
      'Вас буде перенаправлено на зовнішню сторінку для здійснення оплати.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Відкрити посилання на оплату';

  @override
  String get fundExchangeErrorNetwork =>
      'Перевірте підключення до Інтернету та спробуйте ще раз.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'Конфіденційний SEPA';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'Особистий віртуальний IBAN для конфіденційного поповнення';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Додати це як номер облікового запису';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'Цей унікальний номер облікового запису створений для вас';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Не покласти';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' слово \"Bitcoin\" або \"Crypto\" в описі платежу. Заблокувати платіж.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Оберіть валюту';

  @override
  String get exchangeCurrencyDropdownValidation => 'Оберіть валюту';

  @override
  String get exchangeAmountInputTitle => 'Вхід';

  @override
  String get exchangeAmountInputValidationEmpty => 'Введіть суму';

  @override
  String get exchangeAmountInputValidationInvalid => 'Сума недійсна';

  @override
  String get exchangeAmountInputValidationZero =>
      'Кількість повинна бути більшою, ніж нуль';

  @override
  String get exchangeAmountInputValidationInsufficient => 'Недостатній баланс';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Bitcoin адреса';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel =>
      'Lightning (LN адреса)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Контакти';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Вхід';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Адреса гаманця успішно збережена';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Встановити адреси за замовчуванням для автоматичного виведення біткойнів.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Bitcoin адреса';

  @override
  String get exchangeDcaAddressLabelLightning => 'Адреса блискавки';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Контакти';

  @override
  String get cancel => 'Зареєструватися';

  @override
  String get delete => 'Видалення';

  @override
  String get save => 'Зберегти';

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
  String get settingsTermsOfServiceTitle => 'Умови надання послуг';

  @override
  String get continueButton => 'Продовжити';

  @override
  String get autoBuyTitle => 'Автоматична купівля';

  @override
  String get autoBuyDescription =>
      'Автоматично купуйте Bitcoin щоразу, коли поповнюєте свій рахунок';

  @override
  String get autoBuyActivate => 'Увімкнути автоматичну купівлю';

  @override
  String get autoBuyDeactivate => 'Вимкнути автоматичну купівлю';

  @override
  String get autoBuyCancelTitle => 'Скасувати автоматичну купівлю?';

  @override
  String get autoBuyCancelMessage =>
      'Наступного разу, коли ви поповните рахунок, Bitcoin не буде куплено автоматично.';

  @override
  String get autoBuyDeactivateConfirm => 'Так, вимкнути';

  @override
  String get autoBuyHowItWorks => 'Як це працює';

  @override
  String get autoBuyConnectWallet =>
      'Підключіть свій гаманець Bitcoin, Lightning або Liquid';

  @override
  String get autoBuyPurchaseCreated =>
      'Щоразу, коли ви поповнюєте свій рахунок Bull Bitcoin, автоматично створюється купівля Bitcoin.';

  @override
  String get autoBuyBitcoinSent =>
      'Bitcoin надсилається напряму на ваш власний гаманець.';

  @override
  String get autoBuyRiskDisclaimer =>
      'Виконання ордера не гарантується. Затримки або зміни ціни між поповненням і купівлею можуть змінити фактичний курс.';

  @override
  String get autoBuyGetStarted => 'Почніть з автоматичної купівлі';

  @override
  String get autoBuyConfirmTitle => 'Підтвердити автоматичну купівлю';

  @override
  String get autoBuyInfoMessage =>
      'Будь-яка сума, додана на ваш рахунок, буде конвертована в Bitcoin за поточним обмінним курсом і надіслана на ваш гаманець.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Ваш рахунок Bull Bitcoin недоступний. Спробуйте пізніше.';

  @override
  String get autoBuyWalletRequiredError =>
      'Додайте щонайменше одну адресу Bitcoin, Lightning або Liquid за замовчуванням.';

  @override
  String get autoBuyUpdateError =>
      'Не вдалося оновити автоматичну купівлю. Спробуйте пізніше.';

  @override
  String get exchangeAuthLoginFailedTitle => 'Логін';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'Помилкові помилки, будь ласка, спробуйте увійти знову.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'ЗАРЕЄСТРУВАТИСЯ';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';
}
