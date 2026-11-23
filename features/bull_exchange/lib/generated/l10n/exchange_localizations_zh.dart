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
