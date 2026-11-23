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
}
