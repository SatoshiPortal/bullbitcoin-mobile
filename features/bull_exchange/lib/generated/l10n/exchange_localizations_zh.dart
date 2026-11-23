// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class ExchangeLocalizationsZh extends ExchangeLocalizations {
  ExchangeLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => '电子邮件';

  @override
  String get exchangeAccountInfoFirstNameLabel => '姓名';

  @override
  String get exchangeAccountInfoLastNameLabel => '姓 名';

  @override
  String get exchangeAccountInfoLoadErrorMessage => '无法装载账户信息';

  @override
  String get exchangeAccountInfoTitle => '账户信息';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage => '用户编号为纸板';

  @override
  String get exchangeAccountInfoUserNumberLabel => '用户数';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified => '核实身份';

  @override
  String get exchangeAccountInfoVerificationLevelLabel => '核查水平';

  @override
  String get exchangeAccountInfoVerificationLightVerification => '轻型核查';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification => '有限的核查';

  @override
  String get exchangeAccountInfoVerificationNotVerified => '未核实';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel => '违约货币';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      '收到电子邮件命令通知和账户最新情况';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel => '电子邮件 通知';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => '简称';

  @override
  String get exchangeAppSettingsSaveButton => 'Save';

  @override
  String get exchangeAppSettingsSaveSuccessMessage => '成功挽救的环境';

  @override
  String get exchangeAppSettingsValidationWarning => '请在储蓄之前确定语言和货币选择.';

  @override
  String get exchangeAuthErrorMessage => '发生了错误,请再次尝试伐木.';

  @override
  String get exchangeBitcoinWalletsTitle => 'Default Wallets';

  @override
  String get exchangeErrorNetwork => '请检查您的网络连接后重试。';

  @override
  String get exchangeErrorSavingPreferences => '无法保存您的偏好设置。请重试。';

  @override
  String get exchangeFileUploadButton => '装载';

  @override
  String get exchangeFileUploadDocumentTitle => '卸载文件';

  @override
  String get exchangeFileUploadInstructions => '如果你需要寄发任何其他文件,则将这些文件上载.';

  @override
  String get exchangeFileUploadStatusAccepted => '接受';

  @override
  String get exchangeFileUploadStatusInReview => '审查';

  @override
  String get exchangeFileUploadStatusRejectedBadge => '已拒绝';

  @override
  String get exchangeFileUploadSuccess => '文件上传成功';

  @override
  String get exchangeFileUploadTapToReupload => '点击重新上传';

  @override
  String get exchangeFileUploadTitle => '1. 安全档案库';

  @override
  String get exchangeReferralsApplyToJoinMessage => '申请加入该方案';

  @override
  String get exchangeReferralsContactSupportMessage => '联系支助,了解我们的转诊方案';

  @override
  String get exchangeReferralsJoinMissionTitle => '加入特派团';

  @override
  String get exchangeReferralsMissionLink => '布尔比奇.com/mission';

  @override
  String get exchangeReferralsTitle => '参考法';

  @override
  String get exchangeSecurityAccessSettingsButton => '准入环境';

  @override
  String get exchangeSecurityManage2FAPasswordLabel => '第2条';

  @override
  String get exchangeSettingsAccountInformationTitle => '账户信息';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted => '已提交过文件。';

  @override
  String get exchangeSettingsErrorDocumentEmpty => '该文件为空。请选择其他文件。';

  @override
  String get exchangeSettingsErrorDocumentTooLarge => '该文件过大。请选择更小的文件。';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed => '不接受该文件类型。请选择其他文件。';

  @override
  String get exchangeSettingsErrorDocumentUnreadable => '无法读取该文件。请选择其他文件。';

  @override
  String get exchangeSettingsErrorLoadingAccount => '无法加载您的账户信息。请重试。';

  @override
  String get exchangeSettingsErrorLoadingStatistics => '无法加载您的交易统计数据。请重试。';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus => '无法加载您的上传状态。请重试。';

  @override
  String get exchangeSettingsErrorUploadingDocument => '无法上传该文件。请重试。';

  @override
  String get exchangeSettingsLogInTitle => '后勤';

  @override
  String get exchangeSettingsRecipientsTitle => '收件者';

  @override
  String get exchangeSettingsReferralsTitle => '移案';

  @override
  String get exchangeSettingsSecuritySettingsTitle => '安全设置';

  @override
  String get exchangeSettingsTransactionsTitle => '交易';

  @override
  String exchangeStatisticsAsOf(String date) {
    return '截至$date年';
  }

  @override
  String get exchangeStatisticsAveragePrice => '平均价格';

  @override
  String get exchangeStatisticsBillerStats => '账单统计';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc => '购买时每个比特币的平均价格';

  @override
  String get exchangeStatisticsBuySellRatio => '定购单';

  @override
  String get exchangeStatisticsBuySellRatioDesc => '买入与卖出占总交易量的百分比';

  @override
  String get exchangeStatisticsBuyStats => '采购统计';

  @override
  String get exchangeStatisticsBuyTradeCountDesc => '比特币购买交易的笔数';

  @override
  String get exchangeStatisticsBuyVolumeDesc => '购买比特币花费的总金额';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return '货币:$currency';
  }

  @override
  String get exchangeStatisticsNoData => '没有统计数据';

  @override
  String get exchangeStatisticsOrderStats => '命令统计';

  @override
  String get exchangeStatisticsSellAvgPriceDesc => '出售时每个比特币获得的平均价格';

  @override
  String get exchangeStatisticsSellStats => 'Sell 统计';

  @override
  String get exchangeStatisticsSellTradeCountDesc => '比特币出售交易的笔数';

  @override
  String get exchangeStatisticsSellVolumeDesc => '出售比特币获得的总金额';

  @override
  String get exchangeStatisticsTitle => '统计';

  @override
  String get exchangeStatisticsTotalAmount => '总额';

  @override
  String get exchangeStatisticsTotalVolume => '国际贸易总量';

  @override
  String get exchangeStatisticsTotalVolumeDesc => '以法币计的买入与卖出总交易量';

  @override
  String get exchangeStatisticsTradeCount => '贸易指数';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 笔交易 ($currency)',
      one: '1 笔交易 ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 笔交易',
      one: '1 笔交易',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => '数量';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed => '添加日志失败，请重试。';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => '图片';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => '未知文件';

  @override
  String get exchangeSupportChatEmptyState => '尚未发出任何信息。 开始对话!';

  @override
  String get exchangeSupportChatFetchFileDataFailed => '获取文件数据失败';

  @override
  String get exchangeSupportChatInputHint => '信息的类型......';

  @override
  String get exchangeSupportChatLoadAttachmentError => '无法打开附件。请重试。';

  @override
  String get exchangeSupportChatLoadMessagesError => '无法加载消息。请重试。';

  @override
  String get exchangeSupportChatMessageEmptyError => '信息不能空洞';

  @override
  String get exchangeSupportChatMessageRequired => '需要信息';

  @override
  String get exchangeSupportChatPickFilesFailed => '选择文件失败，请重试。';

  @override
  String get exchangeSupportChatSendMessageError => '无法发送您的消息。请重试。';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => '支持地图';

  @override
  String get exchangeSupportChatYesterday => '昨天';

  @override
  String get exchangeSupportLoginChatRequired =>
      '如需人工支持，您必须先登录您的 Bull Bitcoin 账户。完全免费，无需 KYC，只需一个电子邮件地址。';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get notLoggedInTitle => '页: 1';

  @override
  String get oopsSomethingWentWrong => 'Oops! 某些错误';

  @override
  String get retry => '学历';

  @override
  String get settingsAppSettingsTitle => '申请情况';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';

  @override
  String get settingsAccountSettingsTitle => 'Account Settings';

  @override
  String get settingsErrorSavingSetting => '无法保存该设置。请重试。';

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
  String get fundExchangeTitle => '筹资';

  @override
  String get fundExchangeAccountTitle => '基金';

  @override
  String get fundExchangeAccountSubtitle => '选择贵国和支付方法';

  @override
  String get fundExchangeRestrictedTitle => '无法充值';

  @override
  String get fundExchangeRestrictedMessage => '您的账户无法充值。请联系客服了解更多信息。';

  @override
  String get fundExchangeWarningTitle => 'for监测';

  @override
  String get fundExchangeWarningDescription => '如果有人要求你买“帮助你”的话,他们可能会试图cam你!';

  @override
  String get fundExchangeWarningTacticsTitle => 'B. 共同节奏战术';

  @override
  String get fundExchangeWarningTactic1 => '它们是有希望的投资回报';

  @override
  String get fundExchangeWarningTactic2 => '他们向你们提供贷款';

  @override
  String get fundExchangeWarningTactic3 => '他们说他们从事债务或税收工作';

  @override
  String get fundExchangeWarningTactic4 => '他们要求将比特币发送到他们的地址';

  @override
  String get fundExchangeWarningTactic5 => '他们要求将另一个平台送至鹿特丹';

  @override
  String get fundExchangeWarningTactic6 => '他们希望分享你的屏幕';

  @override
  String get fundExchangeWarningTactic7 => '他们告诉你不要担心这一警告';

  @override
  String get fundExchangeWarningTactic8 => '他们正在敦促你迅速采取行动';

  @override
  String get fundExchangeWarningConfirmation => '我确认,我没有被问到别的人.';

  @override
  String get fundExchangeContinueButton => '继续';

  @override
  String get fundExchangeScamConsentError => '无法注册您的同意。请再试一次。';

  @override
  String get fundExchangeDoneButton => 'Done';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 加拿大';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 欧洲';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 墨西哥';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Costa 哥斯达黎加';

  @override
  String get fundExchangeJurisdictionArgentina => '阿根廷';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 哥伦比亚';

  @override
  String get fundExchangeMethodEmailETransfer => 'Email E-transfer';

  @override
  String get fundExchangeMethodEmailETransferSubtitle => '最容易和最快的方法(不变)';

  @override
  String get fundExchangeMethodBankTransferWire => '银行转账 (Wire or EFT)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      '较大数额的最佳和最可靠的选择(同日或次日)';

  @override
  String get fundExchangeMethodOnlineBillPayment => '《在线法案》支付';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      '最低选择,但可以通过在线银行进行(3-4个工作日)';

  @override
  String get fundExchangeMethodCanadaPost => '加拿大个人现金或借项';

  @override
  String get fundExchangeMethodCanadaPostSubtitle => '更愿意亲自支付报酬的人';

  @override
  String get fundExchangeMethodInstantSepa => '即时和标准SEPA转账';

  @override
  String get fundExchangeMethodInstantSepaSubtitle => '最长――只有不到30 000欧元的交易';

  @override
  String get fundExchangeMethodRegularSepa => 'SEPA';

  @override
  String get fundExchangeMethodRegularSepaSubtitle => '只使用30 000欧元以上的大宗交易';

  @override
  String get fundExchangeBankTransferWireTitle => '银行转账(wire)';

  @override
  String get fundExchangeBankTransferWireDescription =>
      '采用Bull Bitcoin银行详细情况,将电线从你的银行账户转移。 贵银行可能只需要这些细节的某些部分。';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      '您寄出的任何资金都将在1-2个工作日内添加到您的布莱特.';

  @override
  String get fundExchangeLabelBeneficiaryName => '受益人名称';

  @override
  String get fundExchangeHelpBeneficiaryName => '利用我们的正式公司名称。 不要使用“Bul>.';

  @override
  String get fundExchangeLabelTransferCode => '转账代码(作为付款说明处理)';

  @override
  String get fundExchangeHelpTransferCode => '添加这一点作为转让的理由';

  @override
  String get fundExchangeInfoTransferCode => '在付款时,必须将转让法作为“对象”或“理由”.';

  @override
  String get fundExchangeLabelBankAccountDetails => '银行账户细节';

  @override
  String get fundExchangeLabelSwiftCode => '缩略语';

  @override
  String get fundExchangeLabelInstitutionNumber => '机构数目';

  @override
  String get fundExchangeLabelTransitNumber => '过境次数';

  @override
  String get fundExchangeLabelRoutingNumber => '序号';

  @override
  String get fundExchangeLabelBeneficiaryAddress => '受益人地址';

  @override
  String get fundExchangeLabelBankName => '银行名称';

  @override
  String get fundExchangeLabelBankAddress => '银行地址';

  @override
  String get fundExchangeETransferTitle => 'E-Transfer details';

  @override
  String get fundExchangeETransferDescription =>
      '您利用以下信息通过电子邮件E-Transfer从贵国银行汇出的任何款项,将在几分钟内贷记到您的Batt账户余额.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      '使用这一名称作为E- transfer受益人的名称';

  @override
  String get fundExchangeETransferLabelEmail => 'E- transfer to this email';

  @override
  String get fundExchangeETransferLabelSecretQuestion => '保密问题';

  @override
  String get fundExchangeETransferLabelSecretAnswer => '秘密回答';

  @override
  String get fundExchangeOnlineBillPaymentTitle => '《在线法案》支付';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      '贵银行利用以下信息通过网上账单付款地址发送的任何款项,将在3-4个工作日内贷记到您的Burt账户余额.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      '• 寻找贵国银行的账单人名单以证明这一名称';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName => '将该公司列为收款人——其付款程序人';

  @override
  String get fundExchangeCanadaPostTitle => '加拿大个人现金或借项';

  @override
  String get fundExchangeCanadaPostStep1 => '1. 导言 前往加拿大';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. 结 论 Ask the moneyier to scan the “Loadhub” QR Code';

  @override
  String get fundExchangeCanadaPostStep3 => '3. 。 转售出你想要装载的金额';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. 第四条第4款 该名出纳人将要求看到一份政府签发的身份证,并核实您的身份证上的名称与您的“伯茨”账户相符';

  @override
  String get fundExchangeCanadaPostStep5 => '5. 支付现金或借用卡';

  @override
  String get fundExchangeCanadaPostStep6 => '6. 任务 出纳人将向你提交收据,并将其作为付款证明';

  @override
  String get fundExchangeCanadaPostStep7 => '7. 基本生活 这笔资金将在30分钟内添加到您的平流账户余额中';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Loadhub QR代码';

  @override
  String get fundExchangeSepaTitle => 'SEPA 转让';

  @override
  String get fundExchangeSepaDescription => '请根据以下详情，从您的银行账户发起一笔 SEPA 转账。';

  @override
  String get fundExchangeSepaDescriptionExactly => '务必确保信息完全一致。';

  @override
  String get fundExchangeInstantSepaInfo =>
      '仅适用于 20,000 欧元以下的交易。对于更大金额的交易，请使用常规 SEPA 选项。';

  @override
  String get fundExchangeRegularSepaInfo =>
      '仅用于20 000欧元以上的交易。 在较小的交易中,采用中观SEPA方案.';

  @override
  String get fundExchangeLabelIban => 'IBAN账户';

  @override
  String get fundExchangeLabelBicCode => 'BIC 守则';

  @override
  String get fundExchangeLabelBankAccountCountry => '银行账户';

  @override
  String get fundExchangeInfoBankCountryUk => '我国是联合王国.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      '受益人的名称应为LEONOD。 如果你做任何事情,你的支付将被拒绝.';

  @override
  String get fundExchangeInfoPaymentDescription => '在付款说明中,增加你的转让代码.';

  @override
  String get fundExchangeHelpBeneficiaryAddress => '如果贵国银行有此要求,我国官方地址';

  @override
  String get fundExchangeLabelRecipientName => '客户名称';

  @override
  String get fundExchangeLabelBankCountry => '银行业';

  @override
  String get fundExchangeLabelRecipientAddress => '客户地址';

  @override
  String get fundExchangeSpeiTitle => 'SPEI 转让';

  @override
  String get fundExchangeSpeiDescription => '利用《公约》的资金转移';

  @override
  String get fundExchangeSpeiInfo => '采用SPEI转让进行存款.';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Memo';

  @override
  String get fundExchangeSinpeTitle => 'SINPE 转让';

  @override
  String get fundExchangeSinpeDescription => '使用SINPE的转移殖民地';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Bank Transfer (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => '银行转账(美元)';

  @override
  String get fundExchangeArsBankTransferTitle => '银行转账';

  @override
  String get fundExchangeArsBankTransferDescription =>
      '根据以下阿根廷银行详细情况,从贵国银行账户转账.';

  @override
  String get fundExchangeLabelRecipientNameArs => '客户名称';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      '付款细节目前无法装上。 请回头并再次尝试,采用另一种支付方法,或稍后回去.';

  @override
  String get fundExchangeErrorTitleOrdPo404 => '付款方式不可用';

  @override
  String get fundExchangeErrorOrdPo404 => '没有可用的付款方式';

  @override
  String get fundExchangeErrorTitleRcpPo404 => '付款方式不可用';

  @override
  String get fundExchangeErrorRcpPo404 =>
      '您没有访问此充值选项所需的权限。您的 KYC 可能不足，或此选项不适用于您的账户';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE 不可用';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      '要访问此充值选项，您的电话号码必须在哥斯达黎加的 SINPE 网络中注册。';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => '缺少 KYC 要求';

  @override
  String get fundExchangeErrorOrdKyc400 => '您不满足执行此操作所需的 KYC 要求';

  @override
  String get fundExchangeErrorTitleOrdCop400 => '无效的 COP 充值数据';

  @override
  String get fundExchangeErrorOrdCop400 => 'COP 充值的请求数据无效';

  @override
  String get fundExchangeErrorOpeningPaymentLink => '无法打开付款链接。请重试。';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 => '虚拟付款未激活';

  @override
  String get fundExchangeErrorOrdCsrcp400 => '请为此 SEPA 收款人激活虚拟付款选项。';

  @override
  String get fundExchangeErrorTitleRcp400 => '无效请求';

  @override
  String get fundExchangeErrorRcp400 => '无效请求';

  @override
  String get fundExchangeErrorFetchingBankCodes => '获取银行代码时出错。请稍后再试。';

  @override
  String get fundExchangeSinpeDescriptionBold => '它将被否决.';

  @override
  String get fundExchangeSinpeAddedToBalance => '一旦收到付款,将列入你的账户结余.';

  @override
  String get fundExchangeSinpeLabelPhone => '电话号码';

  @override
  String get fundExchangeSinpeLabelRecipientName => '客户名称';

  @override
  String get fundExchangeCrIbanCrcDescription => '采用以下详细情况,从贵国银行账户转账 ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => '确切地说';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd => '。 资金将计入你的账户结余.';

  @override
  String get fundExchangeCrIbanCrcLabelIban => 'IBAN账户编号(仅科罗内)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription => '付款说明';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp => '你的转让法.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      '在付款时,必须将转让法作为“对象”或“理由”或“说明”。 如果你忘记列入这一法典,你的支付可能会被拒绝.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => '客户名称';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      '利用我们的正式公司名称。 不要使用“Bul>.';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCrIbanUsdDescription => '采用以下详细情况,从贵国银行账户转账 ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => '确切地说';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd => '。 资金将计入你的账户结余.';

  @override
  String get fundExchangeCrIbanUsdLabelIban => 'IBAN账户编号(仅美元)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription => '付款说明';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp => '你的转让法.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      '在付款时,必须将转让法作为“对象”或“理由”或“说明”。 如果你忘记列入这一法典,你的支付可能会被拒绝.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => '客户名称';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      '利用我们的正式公司名称。 不要使用“Bul>.';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'SINPE Móvil';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle => '使用SINPE的转移殖民地';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle => '哥斯达黎加哥伦的转移资金';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN 哥斯达黎加(美元)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle => '美元转账资金';

  @override
  String get doneButton => 'Done';

  @override
  String get fundExchangeSpeiTransfer => 'SPEI 转让';

  @override
  String get fundExchangeSpeiSubtitle => '利用《公约》的资金转移';

  @override
  String get fundExchangeBankTransfer => '银行转账';

  @override
  String get fundExchangeBankTransferSubtitle => '修改从贵国银行账户转账的银行转账';

  @override
  String get fundExchangeCopDailyLimitWarning => '如果您超过每日交易限额，交易将会失败，您需要联系客服。';

  @override
  String get fundExchangeCopSenderName => '汇款人姓名';

  @override
  String get fundExchangeCopIssuingBank => '发卡银行';

  @override
  String get fundExchangeCopSelectBankError => '请选择发卡银行';

  @override
  String get fundExchangeCopAmount => '金额';

  @override
  String get fundExchangeCopEnterAmountError => '请输入金额';

  @override
  String get fundExchangeCopValidAmountError => '请输入有效金额';

  @override
  String get fundExchangeCopGeneratePaymentLink => '生成付款链接';

  @override
  String get fundExchangeCopRedirectMessage => '您将被跳转到外部页面以完成付款。';

  @override
  String get fundExchangeCopOpenPaymentLink => '打开付款链接';

  @override
  String get fundExchangeErrorNetwork => '请检查您的网络连接后重试。';

  @override
  String get fundExchangeMethodConfidentialSepa => '保密 SEPA';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle => '用于私密存款的个人虚拟 IBAN';

  @override
  String get networkFeatureUnavailable =>
      'This feature is unavailable on the selected network.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber => '添加这一编号为账户编号';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      '这一独一无二的账户编号只是为你们创造的';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => '不要';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' 付款说明中的“现金”或“现金”一词。 这将阻碍你们的支付.';

  @override
  String get exchangeCurrencyDropdownTitle => '选择性货币';

  @override
  String get exchangeCurrencyDropdownValidation => '请选择货币';

  @override
  String get exchangeAmountInputTitle => '实际数额';

  @override
  String get exchangeAmountInputValidationEmpty => '请列出数额';

  @override
  String get exchangeAmountInputValidationInvalid => '无效数额';

  @override
  String get exchangeAmountInputValidationZero => '数额必须大于零';

  @override
  String get exchangeAmountInputValidationInsufficient => '结余不足';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => '地址';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel => '照明(LN地址)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => '流动资金';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => '出入地址';

  @override
  String get exchangeBitcoinWalletsSaveSuccess => '钱包地址保存成功';

  @override
  String get exchangeBitcoinWalletsDescription => '为比特币自动提现设置默认钱包地址';

  @override
  String get exchangeDcaAddressLabelBitcoin => '页: 1';

  @override
  String get exchangeDcaAddressLabelLightning => '照明地址';

  @override
  String get exchangeDcaAddressLabelLiquid => '流动资金';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => '删除';

  @override
  String get save => 'Save';

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
  String get settingsTermsOfServiceTitle => '任期';

  @override
  String get continueButton => '继续';

  @override
  String get autoBuyTitle => '自动买入';

  @override
  String get autoBuyDescription => '每次向账户存入资金时自动买入 Bitcoin';

  @override
  String get autoBuyActivate => '启用自动买入';

  @override
  String get autoBuyDeactivate => '停用自动买入';

  @override
  String get autoBuyCancelTitle => '取消自动买入？';

  @override
  String get autoBuyCancelMessage => '下次向账户充值时，将不会自动买入 Bitcoin。';

  @override
  String get autoBuyDeactivateConfirm => '是的，停用';

  @override
  String get autoBuyHowItWorks => '运作方式';

  @override
  String get autoBuyConnectWallet => '连接您的 Bitcoin、Lightning 或 Liquid 钱包';

  @override
  String get autoBuyPurchaseCreated =>
      '每次向您的 Bull Bitcoin 账户充值时，系统都会自动创建一笔 Bitcoin 买入。';

  @override
  String get autoBuyBitcoinSent => 'Bitcoin 会直接发送到您自己的钱包。';

  @override
  String get autoBuyRiskDisclaimer => '订单执行无法保证。存入与买入之间的延迟或价格变动可能会改变实际成交汇率。';

  @override
  String get autoBuyGetStarted => '开始使用自动买入';

  @override
  String get autoBuyConfirmTitle => '确认自动买入';

  @override
  String get autoBuyInfoMessage => '存入您账户的任何金额都将按当前汇率兑换为 Bitcoin，并发送到您的钱包。';

  @override
  String get autoBuyAccountUnavailableError => '您的 Bull Bitcoin 账户不可用。请稍后重试。';

  @override
  String get autoBuyWalletRequiredError =>
      '请至少添加一个默认的 Bitcoin、Lightning 或 Liquid 地址。';

  @override
  String get autoBuyUpdateError => '无法更新自动买入。请稍后重试。';

  @override
  String get exchangeAuthLoginFailedTitle => '旅行';

  @override
  String get exchangeAuthLoginFailedMessage => '发生了错误,请再次尝试伐木.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'OK';

  @override
  String get exchangeTradingUnavailable => 'Trading is unavailable.';

  @override
  String get settingsScreenTitle => '背景';

  @override
  String get transactionHistoryTitle => '交易记录';

  @override
  String get exchangeHomeDepositButton => '交存';

  @override
  String get exchangeHomeWithdrawButton => '草原';

  @override
  String get exchangeDcaUnableToGetConfig => '无法获得发展中国家的组合';

  @override
  String get exchangeDcaDeactivateTitle => '2. 启动';

  @override
  String get exchangeDcaActivateTitle => '主动同意';

  @override
  String get exchangeDcaHideSettings => '良好做法';

  @override
  String get exchangeDcaViewSettings => '观点环境';

  @override
  String get exchangeDcaCancelDialogTitle => 'Cancel 购物?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      '您的经常性采购计划将停止,计划购买将结束。 为了重新启动,你需要制定新的计划.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Cancel';

  @override
  String get exchangeDcaCancelDialogConfirmButton => '是的,中止';

  @override
  String get exchangeDcaFrequencyHour => '小时';

  @override
  String get exchangeDcaFrequencyDay => '日 本';

  @override
  String get exchangeDcaFrequencyWeek => '每周';

  @override
  String get exchangeDcaFrequencyMonth => '月 本';

  @override
  String get exchangeDcaNetworkBitcoin => '联合国';

  @override
  String get exchangeDcaNetworkLightning => '照明网络';

  @override
  String get exchangeDcaNetworkLiquid => '流动网络';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return '只要你的账户有资金,你就每$frequency次通过$network购买$amount.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel:$address';
  }

  @override
  String get exchangeKycLevelLight => '灯光';

  @override
  String get exchangeKycLevelLimited => '有限公司';

  @override
  String get exchangeKycCardTitle => '完成 KYC';

  @override
  String get exchangeKycCardSubtitle => '取消交易限制';

  @override
  String get homeActionBuy => '购买';

  @override
  String get homeActionSell => '出售';

  @override
  String get homeActionPay => '支付';

  @override
  String get homeActionTransfer => 'Swap';

  @override
  String get priceChartShowTooltip => 'Show price chart';

  @override
  String get recipientsSearchHint => '按名称或标签搜索收件人';

  @override
  String get recipientsScreenTitle => '选择收件人';

  @override
  String get recipientsScreenSubtitle => '您要支付给谁？';

  @override
  String get recipientsTabNew => '新增收件人';

  @override
  String get recipientsTabList => '我的法币收件人';

  @override
  String get recipientsPayoutMethod => '付款方式';

  @override
  String get recipientsFilterByJurisdiction => '按辖区筛选：';

  @override
  String get recipientsListEmpty => '未找到收件人。';

  @override
  String get recipientsContinue => '继续';

  @override
  String get recipientsJurisdictionAll => '所有辖区';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 加拿大';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 欧洲（SEPA）';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 墨西哥';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 哥斯达黎加';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 阿根廷';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 哥伦比亚';

  @override
  String get recipientsTypeInteracEmail => '电子邮件转账';

  @override
  String get recipientsTypeBillPayment => '账单付款';

  @override
  String get recipientsTypeBankTransfer => '银行转账';

  @override
  String get recipientsTypeSepa => 'SEPA 转账';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI 短信';

  @override
  String get recipientsTypeSpeiCard => 'SPEI 银行卡';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN（美元）';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN（科朗）';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU（阿根廷）';

  @override
  String get recipientsTypeBankAccountCo => '银行账户（COP）';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => '邮箱';

  @override
  String get recipientsInfoPayee => '收款人';

  @override
  String get recipientsInfoAccount => '账户';

  @override
  String get recipientsInfoPhone => '电话';

  @override
  String get recipientsInfoCard => '银行卡';

  @override
  String get recipientsInfoLabel => '标签';

  @override
  String get recipientsValidationFieldRequired => '此字段不能为空';

  @override
  String get recipientsLabelOptional => '标签（可选）';

  @override
  String get recipientsLabelHint => '为此收件人输入一个标签';

  @override
  String get recipientsFieldName => '姓名';

  @override
  String get recipientsFieldNameHint => '输入收件人姓名';

  @override
  String get recipientsFieldRecipientNameLabel => '收件人姓名';

  @override
  String get recipientsFieldPhoneNumber => '电话号码';

  @override
  String get recipientsFieldPhoneNumberHint => '输入电话号码';

  @override
  String get recipientsFieldSinpePhoneNumberHint => '不含国家代码的8位数字';

  @override
  String get recipientsFieldDocumentType => '收件人证件类型';

  @override
  String get recipientsFieldDocumentNumberHint => '输入收件人证件号码';

  @override
  String get recipientsFieldOwnerName => '户主姓名';

  @override
  String get recipientsFieldOwnerNameHint => '输入户主姓名';

  @override
  String get recipientsAccountOwnerQuestion => '此账户属于谁？';

  @override
  String get recipientsAccountOwnerMine => '这是我的账户';

  @override
  String get recipientsAccountOwnerSomeoneElse => '这是他人的账户';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => '输入 IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => '输入 CLABE 号码';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => '输入 CVU/CBU 号码';

  @override
  String get recipientsFieldBankInstitution => '银行机构';

  @override
  String get recipientsFieldBankInstitutionPlaceholder => '选择银行机构';

  @override
  String get recipientsValidationBankInstitution => '请选择银行机构';

  @override
  String get recipientsFieldAccountType => '账户类型';

  @override
  String get recipientsAccountTypeSavings => '储蓄账户';

  @override
  String get recipientsAccountTypeChecking => '支票账户';

  @override
  String get recipientsFieldBankAccountNumber => '银行账号';

  @override
  String get recipientsFieldBankAccountNumberHint => '输入银行账号';

  @override
  String get recipientsCopDocCc => '公民身份证（哥伦比亚）';

  @override
  String get recipientsCopDocCe => '外国人身份证（哥伦比亚）';

  @override
  String get recipientsCopDocNit => '税务识别号（哥伦比亚）';

  @override
  String get recipientsCopDocPassport => '护照';

  @override
  String get recipientsCopDocTi => '未成年人身份证（哥伦比亚）';

  @override
  String get recipientsCopDocRegistroCivil => '户籍登记证明（哥伦比亚）';

  @override
  String get recipientsCopDocCcRecipientNumber => '收件人cédula号码';

  @override
  String get recipientsCopDocCeRecipientNumber => '收件人cédula de extranjería号码';

  @override
  String get recipientsCopDocNitRecipientNumber => '收件人税务ID号码';

  @override
  String get recipientsCopDocPassportRecipientNumber => '收件人护照号码';

  @override
  String get recipientsCopDocTiRecipientNumber => '收件人身份证号码';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber => '收件人民事登记号码';

  @override
  String get recipientsFieldDebitCard => '借记卡号';

  @override
  String get recipientsFieldDebitCardHint => '输入借记卡号';

  @override
  String get recipientsFieldOwnerNameSinpeHint => '户主姓名将显示在此处';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      '移除国家代码 (+506)。仅输入8位数字';

  @override
  String get recipientsValidationSinpePhoneInvalidChars => '只使用数字（不包含字母或符号）';

  @override
  String get recipientsValidationSinpePhoneTooShort => '请输入完整的8位电话号码';

  @override
  String get recipientsValidationSinpeOwner => '请验证电话号码';

  @override
  String get recipientsFieldEmailAddress => '电子邮箱地址';

  @override
  String get recipientsFieldEmailAddressHint => '输入电子邮箱地址';

  @override
  String get recipientsFieldSecurityQuestion => '安全问题';

  @override
  String get recipientsFieldSecurityQuestionHint => '输入安全问题（10-40 个字符）';

  @override
  String get recipientsFieldSecurityAnswer => '安全答案';

  @override
  String get recipientsFieldSecurityAnswerHint => '输入安全答案';

  @override
  String get recipientsValidationSecurityQuestionMin => '安全问题至少需要 10 个字符';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 个字符';
  }

  @override
  String get recipientsFieldInstitutionCode => '机构代码';

  @override
  String get recipientsFieldInstitutionCodeHint => '输入机构代码';

  @override
  String get recipientsFieldInstitutionNumber => '机构编号';

  @override
  String get recipientsFieldInstitutionNumberHint => '输入机构编号';

  @override
  String get recipientsFieldTransitNumber => '转账代码';

  @override
  String get recipientsFieldTransitNumberHint => '输入转账代码';

  @override
  String get recipientsFieldAccountNumber => '账号';

  @override
  String get recipientsFieldAccountNumberHint => '输入账号';

  @override
  String get recipientsFieldDefaultComment => '默认备注（可选）';

  @override
  String get recipientsFieldDefaultCommentHint => '输入默认备注';

  @override
  String get recipientsFieldCorporateAccount => '公司账户';

  @override
  String get recipientsFieldFirstName => '名字';

  @override
  String get recipientsFieldFirstNameHint => '输入名字';

  @override
  String get recipientsFieldLastName => '姓氏';

  @override
  String get recipientsFieldLastNameHint => '输入姓氏';

  @override
  String get recipientsFieldCorporateName => '公司名称';

  @override
  String get recipientsFieldCorporateNameHint => '输入公司名称';

  @override
  String get recipientsFieldBillerName => '账单机构名称';

  @override
  String get recipientsFieldBillerNameHint => '搜索并选择账单机构';

  @override
  String get recipientsValidationBillerSearchMin => '请输入 3 个或以上字符进行搜索';

  @override
  String get recipientsValidationBillerSelect => '请从列表中选择一个账单机构';

  @override
  String get recipientsFieldPayeeAccountNumber => '收款人账号';

  @override
  String get recipientsErrorLoadFailed => '无法加载您的收款人。请重试。';

  @override
  String get recipientsErrorSaveFailed => '无法保存此收款人。请检查信息后重试。';

  @override
  String get recipientsErrorSinpeLookupFailed => '我们无法验证此电话号码。请检查后重试。';

  @override
  String get recipientsErrorBillerSearchFailed => '无法搜索账单机构。请重试。';

  @override
  String get recipientsErrorNetwork => '请检查您的网络连接后重试。';

  @override
  String get recipientsListPullToRetry => '下拉以重试。';

  @override
  String get recipientsErrorSavedButNotSelected =>
      '该收款人已保存，但我们无法继续。请在列表中找到它以继续。';

  @override
  String get recipientsTypeConfidentialSepa => '保密 SEPA';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      '您没有访问此充值选项所需的权限。您的 KYC 可能不足，或此选项不适用于您的账户';

  @override
  String get recipientsErrorEuResidencyRequired => '您需要是欧盟居民才能激活保密 SEPA。';

  @override
  String get recipientsConfidentialSepaActivatingTitle => '正在激活收件人';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      '正在为保密 SEPA 激活您的收件人。这可能需要几分钟。';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle => '收件人尚未激活保密 SEPA';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      '此收件人尚未激活保密 SEPA。我们正在激活中。这可能需要几分钟。您可以改用即时和常规 SEPA。';

  @override
  String get recipientsConfidentialSepaActivatedTitle => '收件人已激活';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      '您的收件人现已激活保密 SEPA。';

  @override
  String get recipientsConfidentialSepaUseRegularSepa => '改用即时和常规 SEPA';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle => '启用保密 SEPA？';

  @override
  String get recipientsVirtualIbanNewBadge => '新';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      '使用以您本人名义开设的个人虚拟 IBAN 私密地为账户充值。完全免费。';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      '从您的银行向 Bull Bitcoin 汇款时，会显示为转账给您本人。';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode => '无需转账代码。';

  @override
  String get recipientsVirtualIbanNameWarningTitle => '重要：姓名必须一致';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      '银行账户姓名必须与您的 Bull Bitcoin 虚拟 IBAN 姓名完全一致，否则转账将被自动退回。姓名不一致？请联系客服。';

  @override
  String get recipientsVirtualIbanAccountOwnerName => '账户持有人姓名';

  @override
  String get recipientsVirtualIbanNameConfirmation => '我确认该姓名与我的银行账户一致';

  @override
  String get recipientsVirtualIbanActivate => '启用保密 SEPA';

  @override
  String get recipientsVirtualIbanActivatingTitle => '正在启用保密 SEPA...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      '正在创建您的虚拟 IBAN，可能需要几分钟。';

  @override
  String get recipientsVirtualIbanActivatedTitle => '保密 SEPA 已启用';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      '您现在可以使用个人虚拟 IBAN 私密地提取资金。';

  @override
  String get recipientsVirtualIbanCopied => '涂料';

  @override
  String get recipientsVirtualIbanDone => 'Done';

  @override
  String get recipientsVirtualIbanRecipientName => '客户名称';

  @override
  String get recipientsVirtualIbanIbanLabel => '虚拟 IBAN 账号';

  @override
  String get recipientsVirtualIbanCountry => '银行账户';

  @override
  String get recipientsVirtualIbanBic => 'BIC 守则';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      '您现在可以使用个人虚拟 IBAN 私密地存入资金。';

  @override
  String get recipientsVirtualIbanShowDetails => '显示我的虚拟 IBAN 详情';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      '使用以您本人名义开设的个人虚拟 IBAN 私密地为账户充值。存款将显示为付款给您本人，无需转账代码。';

  @override
  String get recipientsVirtualIbanBankAddress => '银行地址';

  @override
  String get recipientsVirtualIbanBankAddressHelp => '银行的官方地址，以备您的银行要求时使用。';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      '您的银行账户与虚拟 IBAN 账户的姓名必须一致，否则转账将被自动退回。';

  @override
  String get recipientsFieldBankAccountIban => '银行账户号码 (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      '提现将显示为使用您账户名称的本人账户间转账';

  @override
  String get withdrawAmountTitle => '2. 草签';

  @override
  String get withdrawAmountContinue => '继续';

  @override
  String get withdrawConfirmTitle => '2. 肯定撤回';

  @override
  String get withdrawConfirmRecipientName => '客户名称';

  @override
  String get withdrawConfirmAmount => '数额';

  @override
  String get withdrawConfirmEmail => '电子邮件';

  @override
  String get withdrawConfirmPayee => '收款人';

  @override
  String get withdrawConfirmAccount => '账户';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => '电话';

  @override
  String get withdrawConfirmCard => '文件';

  @override
  String get withdrawConfirmButton => '2. 肯定撤回';

  @override
  String get withdrawSuccessTitle => '撤回';

  @override
  String get withdrawSuccessOrderDetails => '命令细节';

  @override
  String get withdrawConfirmBankAccount => '银行帐户';

  @override
  String get withdrawOwnershipQuestion => '这一账户属于谁?';

  @override
  String get withdrawOwnershipMyAccount => '这是我的说法';

  @override
  String get withdrawOwnershipOtherAccount => '这是他人的陈述';

  @override
  String get withdrawUnauthenticatedError => '你没有认证。 请继续发言.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return '最低数额为$amount$currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return '最高限额为$amount$currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle => '转账安全信息';

  @override
  String get withdrawInteracSaveAsDefault => '将这些信息保存为默认值';

  @override
  String get withdrawInteracSecurityQuestionLengthError => '安全问题必须为 3–40 个字符';

  @override
  String get withdrawInteracSecurityAnswerLengthError => '安全答案必须为 3–40 个字符';

  @override
  String get withdrawInteracSecurityAnswerFormatError => '请使用字母、数字或连字符，不能包含空格';

  @override
  String get withdrawUnexpectedError => '您的提现当前无法完成。请重试或联系客服。';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      '请为此 SEPA 收件人激活保密付款选项。';

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
  String get exchangeSettingsLogOutTitle => '记录';

  @override
  String get logoutConfirmationTitle => '确认退出';

  @override
  String get logoutConfirmationDescription =>
      '您确定要退出您的Bull Bitcoin账户吗？您需要重新登录才能访问交易功能。';

  @override
  String get logoutConfirmationCancel => '取消';

  @override
  String get logoutConfirmationLogout => '退出';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationDescription =>
      '这将向我们的支持团队发送账户删除请求。您的账户将在 5 个工作日内被删除。';

  @override
  String get deleteAccountConfirmationCancel => 'Cancel';

  @override
  String get deleteAccountConfirmationDelete => 'Delete Account';

  @override
  String get deleteAccountSuccessTitle => '账户删除请求已提交';

  @override
  String get deleteAccountSuccessDescription => '您的账户删除请求已提交，将在 5 个工作日内处理完成。';

  @override
  String get deleteAccountSuccessClose => 'Close';

  @override
  String get buyEnterAmount => '营业额';

  @override
  String get buyPaymentMethod => '支付方法';

  @override
  String get buyMax => 'Max';

  @override
  String get buySelectWallet => '选择钱包';

  @override
  String get buyEnterBitcoinAddress => '轨道硬币地址';

  @override
  String get buyBitcoinAddressHint => 'BC1QYL7J673H..6Y6ALV70M0';

  @override
  String get buyConfirmPurchase => '共同采购';

  @override
  String buyYouBought(String amount, String fiatAmount) {
    return '您用 $fiatAmount 购买了 $amount';
  }

  @override
  String get buyPayoutWillBeSentIn => '您的付款将在 ';

  @override
  String get buyViewDetails => '观点细节';

  @override
  String get buyAccelerateTransaction => '加速交易';

  @override
  String get buyGetConfirmedFaster => '更快';

  @override
  String get buyConfirmExpressWithdrawal => '2. 确认明示退出';

  @override
  String get buyNetworkFeeExplanation => '采矿公司收取和收取的电离层网费将从矿工收取和收取的数额中扣除';

  @override
  String get buyNetworkFees => '网络费';

  @override
  String get buyEstimatedFeeValue => '估计收费价值';

  @override
  String get buyNetworkFeeRate => '网络费';

  @override
  String get buyConfirmationTime => '认可时间';

  @override
  String get buyConfirmationTimeValue => '大约10分钟';

  @override
  String get buyWaitForFreeWithdrawal => '退出';

  @override
  String get buyConfirmExpress => '1. 确认';

  @override
  String get buyBitcoinSent => '页: 1!';

  @override
  String get buyThatWasFast => '这是迅速的,是没有的?';

  @override
  String get globalDefaultBitcoinWalletLabel => '安保';

  @override
  String get globalDefaultLiquidWalletLabel => '经常付款';

  @override
  String get dcaSuccessTitle => '重复买!';

  @override
  String dcaSuccessMessageHourly(String amount) {
    return '您将每小时购买$amount';
  }

  @override
  String dcaSuccessMessageDaily(String amount) {
    return '您将每天购买$amount';
  }

  @override
  String dcaSuccessMessageWeekly(String amount) {
    return '您将每周购买$amount';
  }

  @override
  String dcaSuccessMessageMonthly(String amount) {
    return '您将每月购买$amount';
  }

  @override
  String get dcaBackToHomeButton => '返家';

  @override
  String get dcaChooseWalletTitle => '选择比特币钱包';

  @override
  String get dcaWalletSelectionDescription => '将根据这一时间表自动进行采购.';

  @override
  String get dcaNetworkValidationError => '请选择网络';

  @override
  String get dcaEnterLightningAddressLabel => '入光地址';

  @override
  String get dcaUseDefaultLightningAddress => '利用我的缺省电灯.';

  @override
  String get dcaWalletSelectionContinueButton => '继续';

  @override
  String get dcaSelectFrequencyLabel => '选择性频率';

  @override
  String get dcaSelectWalletTypeLabel => '选修';

  @override
  String get dcaWalletTypeBitcoin => '图瓦卢';

  @override
  String get dcaWalletTypeLightning => '照明网络';

  @override
  String get dcaWalletTypeLiquid => '液体(LBTC)';

  @override
  String get dcaWalletBitcoinSubtitle => '最低0.001 BTC';

  @override
  String get dcaWalletLightningSubtitle => '要求兼容的钱包，最大限额 0.25 BTC';

  @override
  String get dcaWalletLiquidSubtitle => '要求兼容的钱包';

  @override
  String get dcaSetupTitle => '2. 约定的变更';

  @override
  String get dcaSetupInsufficientBalance => '平衡不足';

  @override
  String get dcaSetupInsufficientBalanceMessage => '你们没有足够的平衡来建立这一秩序.';

  @override
  String get dcaSetupFundAccount => '基金';

  @override
  String get dcaSetupScheduleMessage => '将根据这一时间表自动进行采购.';

  @override
  String get dcaSetupFrequencyError => '请选择频率';

  @override
  String get dcaSetupContinue => '继续';

  @override
  String get dcaConfirmTitle => '同意 1. 采购';

  @override
  String get dcaConfirmAutoMessage => '定购单将自动置于这些环境中。 无论何时,你都可以消除这些障碍.';

  @override
  String get dcaConfirmFrequency => '频率';

  @override
  String get dcaConfirmFrequencyHourly => '每小时';

  @override
  String get dcaConfirmFrequencyDaily => '每天';

  @override
  String get dcaConfirmFrequencyWeekly => '每个星期';

  @override
  String get dcaConfirmFrequencyMonthly => '每个月';

  @override
  String get dcaConfirmAmount => '数额';

  @override
  String get dcaConfirmPaymentMethod => '支付方法';

  @override
  String dcaConfirmPaymentBalance(String currency) {
    return '$currency 结余';
  }

  @override
  String get dcaConfirmOrderType => '命令类型';

  @override
  String get dcaConfirmOrderTypeValue => '重复购买';

  @override
  String get dcaConfirmNetwork => '网络';

  @override
  String get dcaConfirmNetworkBitcoin => '页: 1';

  @override
  String get dcaConfirmNetworkLightning => '照明';

  @override
  String get dcaConfirmNetworkLiquid => '流动资金';

  @override
  String get dcaConfirmLightningAddress => '照明地址';

  @override
  String get dcaConfirmContinue => '继续';

  @override
  String get buyInputTitle => '采购';

  @override
  String get buyInputMinAmountError => '你们至少应当购买';

  @override
  String get buyInputMaxAmountError => '买不起';

  @override
  String get buyInputKycPending => 'KYC ID 有待核查';

  @override
  String get buyInputKycMessage => '您必须首先完成身份证明核查';

  @override
  String get buyInputCompleteKyc => '页: 1';

  @override
  String get buyInputInsufficientBalance => '结余不足';

  @override
  String get buyInputInsufficientBalanceMessage => '你们没有足够的平衡来建立这一秩序.';

  @override
  String get buyInputFundAccount => '基金';

  @override
  String get buyInputContinue => '继续';

  @override
  String get buyConfirmTitle => '采购';

  @override
  String get buyConfirmYouPay => '页: 1';

  @override
  String get buyConfirmYouReceive => '您';

  @override
  String get buyConfirmBitcoinPrice => '价格';

  @override
  String get buyConfirmPayoutWallet => '支付钱包';

  @override
  String get buyConfirmPayoutMethod => '支付方式';

  @override
  String get buyPayoutMethodLiquid => 'Liquid 上的 L-BTC';

  @override
  String get buyPayoutMethodBitcoin => 'Bitcoin 链上的 BTC';

  @override
  String get buyConfirmExternalWallet => '外部比特币钱包';

  @override
  String get buyConfirmAwaitingConfirmation => '等待确认 ';

  @override
  String get buyUnauthenticatedError => '你没有认证。 请继续发言.';

  @override
  String get buyBelowMinAmountError => '你们正在努力购买低于最低数额.';

  @override
  String get buyAboveMaxAmountError => '你试图购买最高数额.';

  @override
  String get buyUnexpectedError => '当前无法创建您的订单。请重试或联系客服。';

  @override
  String get dcaAccountUnavailableError => '无法加载您的账户。请检查网络连接，确认您已登录，然后重试。';

  @override
  String get dcaLightningAddressRequiredError => '输入 Lightning 地址以接收您购买的比特币。';

  @override
  String get dcaReceiveAddressError => '无法在您的钱包中准备接收地址。请重试。';

  @override
  String get dcaOrderCreationError => '无法创建定期买入。请稍后重试。';

  @override
  String get payjoinInProgress => 'Payjoin in progress';

  @override
  String get payjoinSucceeded => 'Payjoin succeeded';

  @override
  String get payjoinBuyRegularSend =>
      'Bitcoin sent to your wallet via regular send';

  @override
  String get payjoinUseToggle => 'Use payjoin';

  @override
  String get limitOrdersLightningAddressHint => 'you@domain.com';

  @override
  String get exchangeQuoteUnavailableError =>
      'We couldn\'t get a fresh price. Try again, or go back and start a new order.';

  @override
  String get buyQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get sellTitle => 'Sell:';

  @override
  String get sellSelectWallet => '选择钱包';

  @override
  String get sellWhichWalletQuestion => '你们想要从哪条墙上出售?';

  @override
  String get sellExternalWallet => '外墙';

  @override
  String get sellFromAnotherWallet => 'Sell from another Plaza';

  @override
  String get sellAboveMaxAmountError => '您的卖出金额超出了此钱包最大可售限额';

  @override
  String get sellBelowMinAmountError => '您的出售金额低于此钱包的最小可售金额';

  @override
  String get sellInsufficientBalanceError => '当前钱包的余额不足以支付这笔卖出';

  @override
  String get sellUnauthenticatedError => '你没有认证。 请继续发言.';

  @override
  String get sellOrderNotFoundError => '没有发现销售订单。 请再次审判.';

  @override
  String get sellOrderAlreadyConfirmedError => '这一销售订单已经得到确认.';

  @override
  String get sellSelectNetwork => '选定网络';

  @override
  String get sellHowToPayInvoice => '你想支付这一发票如何?';

  @override
  String get sellBitcoinOnChain => '页: 1';

  @override
  String get sellLightningNetwork => '照明网络';

  @override
  String get sellLiquidNetwork => '流动网络';

  @override
  String get sellConfirmPayment => '2. 肯定付款';

  @override
  String get sellPriceWillRefreshIn => '价格上涨 ';

  @override
  String get sellOrderNumber => '命令号数';

  @override
  String get sellPayoutRecipient => '收款人';

  @override
  String get sellCadBalance => '大会 结余';

  @override
  String get sellCrcBalance => 'CRC 结余';

  @override
  String get sellEurBalance => '欧元 结余';

  @override
  String get sellUsdBalance => '美元 结余';

  @override
  String get sellMxnBalance => 'MXN 结余';

  @override
  String get sellArsBalance => 'ARS 平衡';

  @override
  String get sellCopBalance => '缔约方会议 结余';

  @override
  String get sellPayinAmount => '薪酬数额';

  @override
  String get sellPayoutAmount => '薪酬数额';

  @override
  String get sellExchangeRate => '汇率';

  @override
  String get sellPayFromWallet => '付款钱包';

  @override
  String get sellInstantPayments => '经常付款';

  @override
  String get sellSecureBitcoinWallet => '安全的比特币钱包';

  @override
  String get sellFeePriority => '妇女优先';

  @override
  String get sellFastest => '快速';

  @override
  String get sellAdvancedSettings => '先进环境';

  @override
  String get sellAdvancedOptions => 'A. 先进选择';

  @override
  String get sellReplaceByFeeActivated => '替换';

  @override
  String get sellSelectCoinsManually => '手工选编';

  @override
  String get sellDone => 'Done';

  @override
  String get sellPleasePayInvoice => '请支付这一发票';

  @override
  String get sellBitcoinAmount => '数额';

  @override
  String get sellCopyInvoice => '复印件';

  @override
  String get sellShowQrCode => '显示QR代码';

  @override
  String get sellQrCode => 'QR 法典';

  @override
  String get sellNoInvoiceData => '无发票数据';

  @override
  String get sellInProgress => 'A. 正在取得进展......';

  @override
  String get sellGoHome => 'Go home';

  @override
  String get sellOrderCompleted => '页: 1!';

  @override
  String get sellBalanceWillBeCredited => '你的账户余额将在交易收到1份链条确认书后入账.';

  @override
  String sellYouSold(String amount, String fiatAmount) {
    return 'You sold $amount for $fiatAmount';
  }

  @override
  String get payTitle => '薪金';

  @override
  String get payDescriptionLabel => '付款说明（可选）';

  @override
  String get payDescriptionHint => '为此付款添加备注';

  @override
  String get payPaymentDescription => '付款说明';

  @override
  String get payRecipientType => '接收器';

  @override
  String get payRecipientName => '客户名称';

  @override
  String get payRecipientDetails => '收款人详细情况';

  @override
  String get payNoDetailsAvailable => '不详';

  @override
  String get paySelectWallet => '选择钱包';

  @override
  String get payExternalWallet => '外墙';

  @override
  String payAboveMaxAmountError(String amount) {
    return '使用此钱包可支付的最高金额为 $amount。';
  }

  @override
  String payBelowMinAmountError(String amount) {
    return '使用此钱包可支付的最低金额为 $amount。';
  }

  @override
  String get payInsufficientBalanceError => '当前钱包的余额不足以支付这笔订单';

  @override
  String get payUnauthenticatedError => '你没有认证。 请继续发言.';

  @override
  String get paySelectNetwork => '选定网络';

  @override
  String get payHowToPayInvoice => '你想支付这一发票如何?';

  @override
  String get payLightningNetwork => '照明网络';

  @override
  String get payLiquidNetwork => '流动网络';

  @override
  String get payConfirmPayment => '普通工资';

  @override
  String get payOrderNumber => '命令号数';

  @override
  String get payPayinAmount => '收款金额';

  @override
  String get payPayoutAmount => '付款金额';

  @override
  String get payExchangeRate => '汇率';

  @override
  String get payPayFromWallet => '付款钱包';

  @override
  String get payInstantPayments => '经常付款';

  @override
  String get paySecureBitcoinWallet => '安全的比特币钱包';

  @override
  String get payFeePriority => '妇女优先';

  @override
  String get payFastest => '快速';

  @override
  String get payNetworkFees => '网络费';

  @override
  String get payAdvancedSettings => '先进环境';

  @override
  String get payAdvancedOptions => 'A. 先进选择';

  @override
  String get paySelectCoinsManually => '手工选编';

  @override
  String get payDone => 'Done';

  @override
  String get payContinue => '继续';

  @override
  String get payPleasePayInvoice => '请支付这一发票';

  @override
  String get payBitcoinAmount => '数额';

  @override
  String get payBitcoinPrice => '价格';

  @override
  String get payCopyInvoice => '印 度';

  @override
  String get payShowQrCode => '显示QR代码';

  @override
  String get payQrCode => 'QR 法典';

  @override
  String get payNoInvoiceData => '无发票数据';

  @override
  String get payInvalidState => 'Invalid State';

  @override
  String get payViewDetails => '观点细节';

  @override
  String get paySinpeReceipt => 'SINPE 收据';

  @override
  String get payCompleted => '支付!';

  @override
  String payCompletedDescriptionDetails(String fiatAmount, String recipient) {
    return 'The payment of $fiatAmount to $recipient has been completed.';
  }

  @override
  String get paySinpeEnviado => 'SINPE ENVIADO!';

  @override
  String get payOrderDetails => '命令细节';

  @override
  String get paySinpeMonto => '数额';

  @override
  String get paySinpeNumeroOrden => '命令号数';

  @override
  String get paySinpeNumeroComprobante => '参考数字';

  @override
  String get paySinpeBeneficiario => '受益人';

  @override
  String get paySinpeOrigen => '1. 起源';

  @override
  String get payNotAvailable => 'N/A';

  @override
  String get payBitcoinOnchain => '页: 1';

  @override
  String get payPaymentInProgress => '支付:!';

  @override
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'The payment of $fiatAmount to $recipient will be sent after your transaction receives 1 confirmation onchain.';
  }

  @override
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Your transaction is confirmed. The payment of $fiatAmount to $recipient is being processed.';
  }

  @override
  String get payPriceRefreshIn => '价格上涨 ';

  @override
  String get payWhichWallet => '你们想要从哪条墙上花钱?';

  @override
  String get payExternalWalletDescription => '从其他比特币钱包支付';

  @override
  String get payRbfActivated => '替换';

  @override
  String get copyDialogButton => '页: 1';

  @override
  String get closeDialogButton => '近距离';

  @override
  String get sellCompleteKYC => '页: 1';

  @override
  String get sellSendPaymentNetworkFees => '网络费';

  @override
  String get sellSendPaymentContinue => '继续';

  @override
  String get exchangeSendingPayment => 'Sending payment…';

  @override
  String get exchangePaymentSentRefreshingOrder =>
      'Payment sent, refreshing your order…';

  @override
  String get sellBitcoinPriceLabel => '价格';

  @override
  String get sellViewDetailsButton => '观点细节';

  @override
  String get sellKycPendingTitle => 'KYC ID 有待核查';

  @override
  String get sellKycPendingDescription => '你们必须首先完成对身份识别的核查';

  @override
  String get sellLoadingGeneric => 'Loading...';

  @override
  String get viewerTapToCopy => '点击复制';

  @override
  String get invoiceViewerTitle => '发票';

  @override
  String get payjoinViaPayjoin => 'via Payjoin';

  @override
  String get payjoinViaRegularSend => 'via regular send';

  @override
  String get sellDepositAddress => 'Deposit address';

  @override
  String get payDepositAddress => 'Deposit address';

  @override
  String get sellDepositAddressChangedError =>
      'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.';

  @override
  String get payDepositAddressChangedError =>
      'The deposit address of this order changed unexpectedly. For your security, do not pay this order: go back and create a new one.';

  @override
  String get sellUnexpectedError => '您的卖出订单当前无法完成。请重试或联系客服。';

  @override
  String get sellErrorFeeBelowRelayFloor => '网络手续费过低。请选择更高的手续费。';

  @override
  String get sellErrorFeesUnavailable => '无法加载网络手续费。请检查网络连接后重试。';

  @override
  String get payUnexpectedError =>
      'Your payment could not be completed right now. Please try again or contact support.';

  @override
  String get payErrorFeeBelowRelayFloor =>
      'Network fee too low. Choose a higher fee.';

  @override
  String get payErrorFeesUnavailable =>
      'Network fees could not be loaded. Check your connection and try again.';

  @override
  String get withdrawRecipientsPrompt =>
      'Where and how should we send the money?';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get sellQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get exchangePaymentSentPastDeadline =>
      'Payment sent. The exchange reports that the payment deadline for this order expired. Keep the transaction ID below and contact support if the order is not updated.';

  @override
  String get exchangePaymentSentLeave => 'Leave';

  @override
  String get payQuoteExpiredError =>
      'This price has expired. A new one is being loaded; check it before confirming.';

  @override
  String get sellPayoutBalance => '添加到我的账户余额';

  @override
  String get sellPayoutSepaDescription => '提款显示为由 Leonod 发送';

  @override
  String get sellPayoutTitle => '选择收件人';

  @override
  String get sellPayoutNewBadge => '新增';

  @override
  String get walletSpendAwaitingObservation =>
      'Spending is unavailable until this wallet is synced and has seen its previous payments on the network. Refresh the wallet or use Scan for missing transactions, then try again.';

  @override
  String get sendPayjoinSpendPaused =>
      'This Payjoin payment is paused because the wallet cannot safely continue. Its inputs remain reserved. Refresh the wallet or use Scan for missing transactions, then retry this proposal while it is still valid. If it has expired, check the payment in Transactions before taking further action.';

  @override
  String get exchangePayinNetworkMismatch =>
      'The selected wallet does not match this order’s network or the app’s current environment. Select a compatible wallet and try again.';

  @override
  String get walletSpendBusy => 'The wallet is busy. Try again in a moment.';

  @override
  String get broadcastSignedTxErrorOutcomeUnknown =>
      '无法确认您的交易是否已广播。请在区块浏览器中查看后再重试。';

  @override
  String get sendSelectedUtxosInsufficient => '部分税项不包括所需数额';

  @override
  String get selectAmountTitle => '选择性数额';

  @override
  String amountRequestedLabel(String amount) {
    return '要求的数额:$amount';
  }

  @override
  String get addressLabel => '地址: ';

  @override
  String get typeLabel => '类型: ';

  @override
  String get coinsKeychainReceive => '接收';

  @override
  String get coinsKeychainChange => '找零';
}
