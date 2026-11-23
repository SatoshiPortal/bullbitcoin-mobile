import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations_ar.dart';
import 'exchange_localizations_as.dart';
import 'exchange_localizations_bg.dart';
import 'exchange_localizations_bn.dart';
import 'exchange_localizations_cs.dart';
import 'exchange_localizations_de.dart';
import 'exchange_localizations_el.dart';
import 'exchange_localizations_en.dart';
import 'exchange_localizations_es.dart';
import 'exchange_localizations_fa.dart';
import 'exchange_localizations_fi.dart';
import 'exchange_localizations_fr.dart';
import 'exchange_localizations_hi.dart';
import 'exchange_localizations_hy.dart';
import 'exchange_localizations_it.dart';
import 'exchange_localizations_ka.dart';
import 'exchange_localizations_ko.dart';
import 'exchange_localizations_pt.dart';
import 'exchange_localizations_ru.dart';
import 'exchange_localizations_sw.dart';
import 'exchange_localizations_th.dart';
import 'exchange_localizations_tr.dart';
import 'exchange_localizations_uk.dart';
import 'exchange_localizations_vi.dart';
import 'exchange_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ExchangeLocalizations
/// returned by `ExchangeLocalizations.of(context)`.
///
/// Applications need to include `ExchangeLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/exchange_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
///   supportedLocales: ExchangeLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ExchangeLocalizations.supportedLocales
/// property.
abstract class ExchangeLocalizations {
  ExchangeLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ExchangeLocalizations of(BuildContext context) {
    return Localizations.of<ExchangeLocalizations>(
      context,
      ExchangeLocalizations,
    )!;
  }

  static const LocalizationsDelegate<ExchangeLocalizations> delegate =
      _ExchangeLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('as'),
    Locale('bg'),
    Locale('bn'),
    Locale('cs'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
    Locale('hy'),
    Locale('it'),
    Locale('ka'),
    Locale('ko'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('sw'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// Accessible tooltip for the support chat file attachment button.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get exchangeSupportChatAttachFileTooltip;

  /// Snackbar shown when attaching log files to a support chat message fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach logs. Please try again.'**
  String get exchangeSupportChatAttachLogsFailed;

  /// Accessible tooltip for the support chat log attachment button.
  ///
  /// In en, this message translates to:
  /// **'Attach logs'**
  String get exchangeSupportChatAttachLogsTooltip;

  /// Fallback display name for an image attachment in the support chat when no file name is available.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get exchangeSupportChatAttachmentImage;

  /// Fallback display name for a non-image attachment in the support chat when no file name is available.
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get exchangeSupportChatAttachmentUnknownFile;

  /// Message shown when there are no chat messages
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start a conversation!'**
  String get exchangeSupportChatEmptyState;

  /// Snackbar shown when downloading a support chat attachment fails because no file data was returned.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch file data'**
  String get exchangeSupportChatFetchFileDataFailed;

  /// Placeholder text for the message input field
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get exchangeSupportChatInputHint;

  /// Shown when downloading or opening a support chat attachment fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the attachment. Please try again.'**
  String get exchangeSupportChatLoadAttachmentError;

  /// Shown when loading the support chat message history fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages. Please try again.'**
  String get exchangeSupportChatLoadMessagesError;

  /// Error message when trying to send an empty message
  ///
  /// In en, this message translates to:
  /// **'Message cannot be empty'**
  String get exchangeSupportChatMessageEmptyError;

  /// Placeholder text when attachments are present but no message text
  ///
  /// In en, this message translates to:
  /// **'A message is required'**
  String get exchangeSupportChatMessageRequired;

  /// Snackbar shown when picking files for a support chat attachment fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick files. Please try again.'**
  String get exchangeSupportChatPickFilesFailed;

  /// Shown when sending a support chat message fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message. Please try again.'**
  String get exchangeSupportChatSendMessageError;

  /// Accessible tooltip for the support chat send button.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get exchangeSupportChatSendTooltip;

  /// Title for the support chat screen
  ///
  /// In en, this message translates to:
  /// **'Support Chat'**
  String get exchangeSupportChatTitle;

  /// Label for yesterday in date formatting
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get exchangeSupportChatYesterday;

  /// Message on chat preview overlay prompting login to access support chat
  ///
  /// In en, this message translates to:
  /// **'To get human support, you must first log in to your Bull Bitcoin account. It\'s 100% free and no KYC is required, only an email address.'**
  String get exchangeSupportLoginChatRequired;

  /// Error title when something goes wrong
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oopsSomethingWentWrong;

  /// Editable support chat draft after attaching diagnostic logs.
  ///
  /// In en, this message translates to:
  /// **'Here are my logs'**
  String get exchangeSupportChatLogDraft;
}

class _ExchangeLocalizationsDelegate
    extends LocalizationsDelegate<ExchangeLocalizations> {
  const _ExchangeLocalizationsDelegate();

  @override
  Future<ExchangeLocalizations> load(Locale locale) {
    return SynchronousFuture<ExchangeLocalizations>(
      lookupExchangeLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'as',
    'bg',
    'bn',
    'cs',
    'de',
    'el',
    'en',
    'es',
    'fa',
    'fi',
    'fr',
    'hi',
    'hy',
    'it',
    'ka',
    'ko',
    'pt',
    'ru',
    'sw',
    'th',
    'tr',
    'uk',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_ExchangeLocalizationsDelegate old) => false;
}

ExchangeLocalizations lookupExchangeLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return ExchangeLocalizationsHiLatn();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return ExchangeLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return ExchangeLocalizationsAr();
    case 'as':
      return ExchangeLocalizationsAs();
    case 'bg':
      return ExchangeLocalizationsBg();
    case 'bn':
      return ExchangeLocalizationsBn();
    case 'cs':
      return ExchangeLocalizationsCs();
    case 'de':
      return ExchangeLocalizationsDe();
    case 'el':
      return ExchangeLocalizationsEl();
    case 'en':
      return ExchangeLocalizationsEn();
    case 'es':
      return ExchangeLocalizationsEs();
    case 'fa':
      return ExchangeLocalizationsFa();
    case 'fi':
      return ExchangeLocalizationsFi();
    case 'fr':
      return ExchangeLocalizationsFr();
    case 'hi':
      return ExchangeLocalizationsHi();
    case 'hy':
      return ExchangeLocalizationsHy();
    case 'it':
      return ExchangeLocalizationsIt();
    case 'ka':
      return ExchangeLocalizationsKa();
    case 'ko':
      return ExchangeLocalizationsKo();
    case 'pt':
      return ExchangeLocalizationsPt();
    case 'ru':
      return ExchangeLocalizationsRu();
    case 'sw':
      return ExchangeLocalizationsSw();
    case 'th':
      return ExchangeLocalizationsTh();
    case 'tr':
      return ExchangeLocalizationsTr();
    case 'uk':
      return ExchangeLocalizationsUk();
    case 'vi':
      return ExchangeLocalizationsVi();
    case 'zh':
      return ExchangeLocalizationsZh();
  }

  throw FlutterError(
    'ExchangeLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
