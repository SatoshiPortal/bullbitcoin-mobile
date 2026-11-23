// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class ExchangeLocalizationsHi extends ExchangeLocalizations {
  ExchangeLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'लॉग संलग्न करने में विफल। कृपया फिर से प्रयास करें।';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'छवि';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'अज्ञात फ़ाइल';

  @override
  String get exchangeSupportChatEmptyState =>
      'अभी तक कोई संदेश नहीं। बातचीत शुरू करें!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'फ़ाइल डेटा प्राप्त करने में विफल';

  @override
  String get exchangeSupportChatInputHint => 'एक संदेश टाइप करें..।';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'अटैचमेंट नहीं खुल सका। कृपया पुनः प्रयास करें।';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'संदेश लोड नहीं हो सके। कृपया पुनः प्रयास करें।';

  @override
  String get exchangeSupportChatMessageEmptyError => 'संदेश खाली नहीं हो सकता';

  @override
  String get exchangeSupportChatMessageRequired => 'एक संदेश की आवश्यकता है';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'फ़ाइलें चुनने में विफल। कृपया फिर से प्रयास करें।';

  @override
  String get exchangeSupportChatSendMessageError =>
      'आपका संदेश नहीं भेजा जा सका। कृपया पुनः प्रयास करें।';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'समर्थन चैट';

  @override
  String get exchangeSupportChatYesterday => 'कल';

  @override
  String get exchangeSupportLoginChatRequired =>
      'मानवीय सहायता प्राप्त करने के लिए, आपको पहले अपने Bull Bitcoin खाते में लॉग इन करना होगा। यह पूरी तरह से निःशुल्क है और किसी KYC की आवश्यकता नहीं है, केवल एक ईमेल पता।';

  @override
  String get oopsSomethingWentWrong => 'ओप! कुछ गलत हो गया';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class ExchangeLocalizationsHiLatn extends ExchangeLocalizationsHi {
  ExchangeLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Logs attach nahi ho sake. Kripya dobara try karein.';

  @override
  String get exchangeSupportChatAttachmentImage => 'Image';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Anjaan file';

  @override
  String get exchangeSupportChatEmptyState =>
      'Abhi koi message nahi. Baat shuru karo!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'File data fetch nahi ho saka';

  @override
  String get exchangeSupportChatInputHint => 'Message type karo...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Attachment nahi khul saka. Kripya punah prayas karein.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Sandesh load nahi ho sake. Kripya punah prayas karein.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Message khali nahi reh sakta';

  @override
  String get exchangeSupportChatMessageRequired => 'Ek message zaruri hai';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Files select nahi ho saki. Kripya dobara try karein.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Aapka sandesh nahi bheja ja saka. Kripya punah prayas karein.';

  @override
  String get exchangeSupportChatTitle => 'Support Chat';

  @override
  String get exchangeSupportChatYesterday => 'Kal';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Human support lene ke liye aapko pehle apne Bull Bitcoin account mein log in karna hoga. Ye bilkul free hai aur koi KYC nahi chahiye, sirf email address chahiye.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Kuch galat ho gaya';
}
