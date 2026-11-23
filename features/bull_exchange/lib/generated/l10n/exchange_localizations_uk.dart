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

  @override
  String get settingsScreenTitle => 'Налаштування';

  @override
  String get transactionHistoryTitle => 'Історія транзакцій';

  @override
  String get exchangeHomeDepositButton => 'Депозити';

  @override
  String get exchangeHomeWithdrawButton => 'Зняття';

  @override
  String get exchangeDcaUnableToGetConfig =>
      'Неможливо отримати конфігурацію DCA';

  @override
  String get exchangeDcaDeactivateTitle => 'Deactivate Recurring Купити';

  @override
  String get exchangeDcaActivateTitle => 'Активувати продаж';

  @override
  String get exchangeDcaHideSettings => 'Приховати налаштування';

  @override
  String get exchangeDcaViewSettings => 'Перегляд налаштувань';

  @override
  String get exchangeDcaCancelDialogTitle =>
      'Скасувати Bitcoin Recurring Купити?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Зареєструвати тарифний план біткойн-продажу буде припинено, а регулярні покупки будуть завершені. Щоб перезапустити, потрібно налаштувати новий план.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Зареєструватися';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Так, деактивація';

  @override
  String get exchangeDcaFrequencyHour => 'час';

  @override
  String get exchangeDcaFrequencyDay => 'день';

  @override
  String get exchangeDcaFrequencyWeek => 'тиждень';

  @override
  String get exchangeDcaFrequencyMonth => 'місяць';

  @override
  String get exchangeDcaNetworkBitcoin => 'Bitcoin мережа';

  @override
  String get exchangeDcaNetworkLightning => 'Мережа Lightning';

  @override
  String get exchangeDcaNetworkLiquid => 'Мережа рідин';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'Ви купуєте $amount кожен $frequency через $network до тих пір, поки є кошти в обліковому записі.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel: $address';
  }

  @override
  String get exchangeKycLevelLight => 'Світло';

  @override
  String get exchangeKycLevelLimited => 'Об\'єм';

  @override
  String get exchangeKycCardTitle => 'Завершіть КИЇВ';

  @override
  String get exchangeKycCardSubtitle => 'Щоб видалити ліміти транзакцій';

  @override
  String get homeActionBuy => 'Купити';

  @override
  String get homeActionSell => 'Продати';

  @override
  String get homeActionPay => 'Сплатити';

  @override
  String get homeActionTransfer => 'Обміняти';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => 'Пошук одержувачів за ім’ям або міткою';

  @override
  String get recipientsScreenTitle => 'Вибрати одержувача';

  @override
  String get recipientsScreenSubtitle => 'Кому ти платиш?';

  @override
  String get recipientsTabNew => 'Новий одержувач';

  @override
  String get recipientsTabList => 'Мої фіатні одержувачі';

  @override
  String get recipientsPayoutMethod => 'Спосіб виплати';

  @override
  String get recipientsFilterByJurisdiction => 'Фільтр за юрисдикцією:';

  @override
  String get recipientsListEmpty => 'Одержувачів не знайдено.';

  @override
  String get recipientsContinue => 'Продовжити';

  @override
  String get recipientsJurisdictionAll => 'Усі юрисдикції';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Канада';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Європа (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Мексика';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Коста-Рика';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Аргентина';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Колумбія';

  @override
  String get recipientsTypeInteracEmail =>
      'Грошовий переказ електронною поштою';

  @override
  String get recipientsTypeBillPayment => 'Оплата рахунку';

  @override
  String get recipientsTypeBankTransfer => 'Банківський переказ';

  @override
  String get recipientsTypeSepa => 'SEPA-переказ';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Картка';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Аргентина';

  @override
  String get recipientsTypeBankAccountCo => 'Банківський рахунок COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'Ел. пошта';

  @override
  String get recipientsInfoPayee => 'Одержувач';

  @override
  String get recipientsInfoAccount => 'Рахунок';

  @override
  String get recipientsInfoPhone => 'Телефон';

  @override
  String get recipientsInfoCard => 'Картка';

  @override
  String get recipientsInfoLabel => 'Мітка';

  @override
  String get recipientsValidationFieldRequired =>
      'Це поле не може бути порожнім';

  @override
  String get recipientsLabelOptional => 'Мітка (необов\'язково)';

  @override
  String get recipientsLabelHint => 'Введіть мітку для цього одержувача';

  @override
  String get recipientsFieldName => 'Ім\'я';

  @override
  String get recipientsFieldNameHint => 'Введіть ім\'я одержувача';

  @override
  String get recipientsFieldRecipientNameLabel => 'Ім\'я одержувача';

  @override
  String get recipientsFieldPhoneNumber => 'Номер телефону';

  @override
  String get recipientsFieldPhoneNumberHint => 'Введіть номер телефону';

  @override
  String get recipientsFieldSinpePhoneNumberHint => '8 цифр без коду країни';

  @override
  String get recipientsFieldDocumentType => 'Тип ID отримувача';

  @override
  String get recipientsFieldDocumentNumberHint => 'Введіть номер ID отримувача';

  @override
  String get recipientsFieldOwnerName => 'Ім\'я власника';

  @override
  String get recipientsFieldOwnerNameHint => 'Введіть ім\'я власника';

  @override
  String get recipientsAccountOwnerQuestion => 'Кому належить цей рахунок?';

  @override
  String get recipientsAccountOwnerMine => 'Це мій рахунок';

  @override
  String get recipientsAccountOwnerSomeoneElse => 'Це рахунок іншої особи';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'Введіть IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'Введіть номер CLABE';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Введіть номер CVU/CBU';

  @override
  String get recipientsFieldBankInstitution => 'Банківська установа';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Виберіть банківську установу';

  @override
  String get recipientsValidationBankInstitution =>
      'Будь ласка, виберіть банківську установу';

  @override
  String get recipientsFieldAccountType => 'Тип рахунку';

  @override
  String get recipientsAccountTypeSavings => 'Ощадний';

  @override
  String get recipientsAccountTypeChecking => 'Поточний';

  @override
  String get recipientsFieldBankAccountNumber => 'Номер банківського рахунку';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Введіть номер банківського рахунку';

  @override
  String get recipientsCopDocCc =>
      'Посвідчення громадянина (Cédula de Ciudadanía)';

  @override
  String get recipientsCopDocCe =>
      'Посвідчення іноземця (Cédula de Extranjería)';

  @override
  String get recipientsCopDocNit => 'Податковий ідентифікатор (NIT)';

  @override
  String get recipientsCopDocPassport => 'Паспорт';

  @override
  String get recipientsCopDocTi => 'Посвідчення особи (Tarjeta de Identidad)';

  @override
  String get recipientsCopDocRegistroCivil =>
      'Реєстр актів цивільного стану (Registro Civil)';

  @override
  String get recipientsCopDocCcRecipientNumber => 'Номер cédula отримувача';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Номер cédula de extranjería отримувача';

  @override
  String get recipientsCopDocNitRecipientNumber => 'Податковий ID отримувача';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Номер паспорта отримувача';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Номер посвідчення особи отримувача';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Номер запису цивільного реєстру отримувача';

  @override
  String get recipientsFieldDebitCard => 'Номер дебетової картки';

  @override
  String get recipientsFieldDebitCardHint => 'Введіть номер дебетової картки';

  @override
  String get recipientsFieldOwnerNameSinpeHint =>
      'Ім\'я власника з\'явиться тут';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Видаліть код країни (+506). Введіть лише 8-значний номер';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Використовуйте лише цифри (без літер чи символів)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Введіть усі 8 цифр номера телефону';

  @override
  String get recipientsValidationSinpeOwner =>
      'Будь ласка, підтвердьте номер телефону';

  @override
  String get recipientsFieldEmailAddress => 'Адреса електронної пошти';

  @override
  String get recipientsFieldEmailAddressHint =>
      'Введіть адресу електронної пошти';

  @override
  String get recipientsFieldSecurityQuestion => 'Контрольне запитання';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Введіть контрольне запитання (10-40 символів)';

  @override
  String get recipientsFieldSecurityAnswer =>
      'Відповідь на контрольне запитання';

  @override
  String get recipientsFieldSecurityAnswerHint =>
      'Введіть відповідь на контрольне запитання';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'Контрольне запитання повинно містити щонайменше 10 символів';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 символів';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Код установи';

  @override
  String get recipientsFieldInstitutionCodeHint => 'Введіть код установи';

  @override
  String get recipientsFieldInstitutionNumber => 'Номер установи';

  @override
  String get recipientsFieldInstitutionNumberHint => 'Введіть номер установи';

  @override
  String get recipientsFieldTransitNumber => 'Транзитний номер';

  @override
  String get recipientsFieldTransitNumberHint => 'Введіть транзитний номер';

  @override
  String get recipientsFieldAccountNumber => 'Номер рахунку';

  @override
  String get recipientsFieldAccountNumberHint => 'Введіть номер рахунку';

  @override
  String get recipientsFieldDefaultComment =>
      'Коментар за замовчуванням (необов\'язково)';

  @override
  String get recipientsFieldDefaultCommentHint =>
      'Введіть коментар за замовчуванням';

  @override
  String get recipientsFieldCorporateAccount => 'Корпоративний рахунок';

  @override
  String get recipientsFieldFirstName => 'Ім\'я';

  @override
  String get recipientsFieldFirstNameHint => 'Введіть ім\'я';

  @override
  String get recipientsFieldLastName => 'Прізвище';

  @override
  String get recipientsFieldLastNameHint => 'Введіть прізвище';

  @override
  String get recipientsFieldCorporateName => 'Назва компанії';

  @override
  String get recipientsFieldCorporateNameHint => 'Введіть назву компанії';

  @override
  String get recipientsFieldBillerName => 'Назва постачальника';

  @override
  String get recipientsFieldBillerNameHint =>
      'Знайдіть і виберіть постачальника';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Введіть 3 або більше символів для пошуку';

  @override
  String get recipientsValidationBillerSelect =>
      'Будь ласка, виберіть постачальника зі списку';

  @override
  String get recipientsFieldPayeeAccountNumber => 'Номер рахунку одержувача';

  @override
  String get recipientsErrorLoadFailed =>
      'Не вдалося завантажити ваших одержувачів. Спробуйте ще раз.';

  @override
  String get recipientsErrorSaveFailed =>
      'Не вдалося зберегти цього одержувача. Перевірте дані та спробуйте ще раз.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'Не вдалося перевірити цей номер телефону. Перевірте його та спробуйте ще раз.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'Не вдалося виконати пошук отримувачів платежів. Спробуйте ще раз.';

  @override
  String get recipientsErrorNetwork =>
      'Перевірте підключення до Інтернету та спробуйте ще раз.';

  @override
  String get recipientsListPullToRetry => 'Потягніть вниз, щоб повторити.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'Одержувача збережено, але продовжити не вдалося. Знайдіть його у списку, щоб продовжити.';

  @override
  String get recipientsTypeConfidentialSepa => 'Конфіденційний SEPA';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'У вас немає необхідних дозволів для доступу до цього способу поповнення. Або ваш KYC недостатній, або цей спосіб недоступний для вашого облікового запису';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'Щоб активувати конфіденційний SEPA, ви маєте бути резидентом Європейського Союзу.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Активація одержувача';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Вашого одержувача активують для Конфіденційного SEPA. Це може зайняти кілька хвилин.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Одержувача не активовано для Конфіденційного SEPA';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'Цього одержувача ще не активовано для Конфіденційного SEPA. Ми активуємо його зараз. Це може зайняти кілька хвилин. Тим часом ви можете скористатися Миттєвим і звичайним SEPA.';

  @override
  String get recipientsConfidentialSepaActivatedTitle =>
      'Одержувача активовано';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Ваш одержувач тепер активний для Конфіденційного SEPA.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Скористатися Миттєвим і звичайним SEPA замість цього';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle =>
      'Активувати Конфіденційний SEPA?';

  @override
  String get recipientsVirtualIbanNewBadge => 'Нове';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Поповнюйте рахунок конфіденційно за допомогою особистого віртуального IBAN на ваше ім’я. Це безкоштовно.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'Коли ви надсилаєте кошти зі свого банку до Bull Bitcoin, це виглядає як переказ самому собі.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'Код переказу не потрібен.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Важливо: ім’я має збігатися';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Ім’я власника банківського рахунку має точно збігатися з ім’ям вашого віртуального IBAN у Bull Bitcoin, інакше переказ буде автоматично повернуто. Імена не збігаються? Зверніться до підтримки.';

  @override
  String get recipientsVirtualIbanAccountOwnerName => 'Ім’я власника рахунку';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'Підтверджую, що ім’я збігається з моїм банківським рахунком (рахунками)';

  @override
  String get recipientsVirtualIbanActivate => 'Активувати Конфіденційний SEPA';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Активація Конфіденційного SEPA...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Створюємо ваш віртуальний IBAN. Це може зайняти кілька хвилин.';

  @override
  String get recipientsVirtualIbanActivatedTitle =>
      'Конфіденційний SEPA активовано';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'Тепер ви можете використовувати особистий віртуальний IBAN, щоб виводити гроші конфіденційно.';

  @override
  String get recipientsVirtualIbanCopied => 'Скопіювати до буферу';

  @override
  String get recipientsVirtualIbanDone => 'Сонце';

  @override
  String get recipientsVirtualIbanRecipientName => 'Ім\'я одержувача';

  @override
  String get recipientsVirtualIbanIbanLabel =>
      'Номер віртуального рахунку IBAN';

  @override
  String get recipientsVirtualIbanCountry => 'Країна банківського рахунку';

  @override
  String get recipientsVirtualIbanBic => 'Код BIC';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'Тепер ви можете використовувати особистий віртуальний IBAN, щоб вносити гроші конфіденційно.';

  @override
  String get recipientsVirtualIbanShowDetails =>
      'Показати реквізити мого віртуального IBAN';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Поповнюйте рахунок конфіденційно за допомогою особистого віртуального IBAN на ваше ім’я. Поповнення виглядатиме як платіж самому собі, без коду переказу.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Адреса банку';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'Офіційна адреса банку, якщо ваш банк її попросить.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'Імена у вашому банку та у віртуальному IBAN мають збігатися, інакше перекази буде автоматично повернуто.';

  @override
  String get recipientsFieldBankAccountIban =>
      'Номер банківського рахунку (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'Зняття коштів відображаються як переказ самому собі з іменем вашого рахунку';

  @override
  String get withdrawAmountTitle => 'Зняття фіат';

  @override
  String get withdrawAmountContinue => 'Продовжити';

  @override
  String get withdrawConfirmTitle => 'Підтвердження виведення';

  @override
  String get withdrawConfirmRecipientName => 'Ім\'я одержувача';

  @override
  String get withdrawConfirmAmount => 'Сума';

  @override
  String get withdrawConfirmEmail => 'Веб-сайт';

  @override
  String get withdrawConfirmPayee => 'Оплатити';

  @override
  String get withdrawConfirmAccount => 'Облік';

  @override
  String get withdrawConfirmIban => 'ІБАН';

  @override
  String get withdrawConfirmClabe => 'КЛАБ';

  @override
  String get withdrawConfirmPhone => 'Зареєструватися';

  @override
  String get withdrawConfirmCard => 'Карта сайту';

  @override
  String get withdrawConfirmButton => 'Підтвердження виведення';

  @override
  String get withdrawSuccessTitle => 'Зняття ініціації';

  @override
  String get withdrawSuccessOrderDetails => 'Деталі замовлення';

  @override
  String get withdrawConfirmBankAccount => 'Банківський рахунок';

  @override
  String get withdrawOwnershipQuestion => 'Хто такий обліковий запис належить?';

  @override
  String get withdrawOwnershipMyAccount => 'Це мій обліковий запис';

  @override
  String get withdrawOwnershipOtherAccount => 'Це чужий рахунок';

  @override
  String get withdrawUnauthenticatedError =>
      'Ви не автентифіковані. Будь ласка, увійдіть, щоб продовжити.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'Мінімальна сума $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'Максимальна сума $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle => 'Дані безпеки переказу';

  @override
  String get withdrawInteracSaveAsDefault => 'Зберегти ці дані як типові';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'Контрольне запитання має містити від 3 до 40 символів';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'Контрольна відповідь має містити від 3 до 40 символів';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Використовуйте літери, цифри або дефіси без пробілів';

  @override
  String get withdrawUnexpectedError =>
      'Ваше виведення коштів наразі не вдалося завершити. Будь ласка, спробуйте ще раз або зверніться до підтримки.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Будь ласка, активуйте опцію конфіденційного платежу для цього одержувача SEPA.';

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
  String get exchangeSettingsLogOutTitle => 'Увійти';

  @override
  String get logoutConfirmationTitle => 'Підтвердити вихід';

  @override
  String get logoutConfirmationDescription =>
      'Ви впевнені, що хочете вийти зі свого облікового запису Bull Bitcoin? Вам потрібно буде знову увійти, щоб отримати доступ до функцій обміну.';

  @override
  String get logoutConfirmationCancel => 'Скасувати';

  @override
  String get logoutConfirmationLogout => 'Вийти';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationDescription =>
      'Це надішле запит на видалення облікового запису до нашої служби підтримки. Ваш обліковий запис буде видалено протягом 5 робочих днів.';

  @override
  String get deleteAccountConfirmationCancel => 'Cancel';

  @override
  String get deleteAccountConfirmationDelete => 'Delete Account';

  @override
  String get deleteAccountSuccessTitle =>
      'Запит на видалення облікового запису надіслано';

  @override
  String get deleteAccountSuccessDescription =>
      'Ваш запит на видалення облікового запису надіслано. Його буде опрацьовано протягом 5 робочих днів.';

  @override
  String get deleteAccountSuccessClose => 'Close';
}
