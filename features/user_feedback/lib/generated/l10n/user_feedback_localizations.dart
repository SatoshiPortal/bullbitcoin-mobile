import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations_ar.dart';
import 'user_feedback_localizations_as.dart';
import 'user_feedback_localizations_bg.dart';
import 'user_feedback_localizations_bn.dart';
import 'user_feedback_localizations_cs.dart';
import 'user_feedback_localizations_de.dart';
import 'user_feedback_localizations_el.dart';
import 'user_feedback_localizations_en.dart';
import 'user_feedback_localizations_es.dart';
import 'user_feedback_localizations_fa.dart';
import 'user_feedback_localizations_fi.dart';
import 'user_feedback_localizations_fr.dart';
import 'user_feedback_localizations_hi.dart';
import 'user_feedback_localizations_hy.dart';
import 'user_feedback_localizations_it.dart';
import 'user_feedback_localizations_ka.dart';
import 'user_feedback_localizations_ko.dart';
import 'user_feedback_localizations_pt.dart';
import 'user_feedback_localizations_ru.dart';
import 'user_feedback_localizations_sw.dart';
import 'user_feedback_localizations_th.dart';
import 'user_feedback_localizations_tr.dart';
import 'user_feedback_localizations_uk.dart';
import 'user_feedback_localizations_vi.dart';
import 'user_feedback_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of UserFeedbackLocalizations
/// returned by `UserFeedbackLocalizations.of(context)`.
///
/// Applications need to include `UserFeedbackLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/user_feedback_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: UserFeedbackLocalizations.localizationsDelegates,
///   supportedLocales: UserFeedbackLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the UserFeedbackLocalizations.supportedLocales
/// property.
abstract class UserFeedbackLocalizations {
  UserFeedbackLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static UserFeedbackLocalizations of(BuildContext context) {
    return Localizations.of<UserFeedbackLocalizations>(
      context,
      UserFeedbackLocalizations,
    )!;
  }

  static const LocalizationsDelegate<UserFeedbackLocalizations> delegate =
      _UserFeedbackLocalizationsDelegate();

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

  /// Settings row, sheet title and button that open the feedback form
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackTitle;

  /// Tooltip of the button that closes the feedback sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get feedbackClose;

  /// Shown when the feedback form cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the feedback form. Check your connection and try again.'**
  String get feedbackLoadError;

  /// Button that reloads the feedback form
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get feedbackRetry;

  /// Title of the prompt shown after the user shakes the phone
  ///
  /// In en, this message translates to:
  /// **'Something not right?'**
  String get feedbackShakeTitle;

  /// Body of the prompt shown after the user shakes the phone
  ///
  /// In en, this message translates to:
  /// **'Send the team a bug report or an idea.'**
  String get feedbackShakeBody;

  /// Button that dismisses the shake prompt
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get feedbackShakeDismiss;

  /// Comma-separated Settings search keywords for the feedback row
  ///
  /// In en, this message translates to:
  /// **'feedback, bug, report, idea, suggestion, problem, contact'**
  String get feedbackSearchKeywords;
}

class _UserFeedbackLocalizationsDelegate
    extends LocalizationsDelegate<UserFeedbackLocalizations> {
  const _UserFeedbackLocalizationsDelegate();

  @override
  Future<UserFeedbackLocalizations> load(Locale locale) {
    return SynchronousFuture<UserFeedbackLocalizations>(
      lookupUserFeedbackLocalizations(locale),
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
  bool shouldReload(_UserFeedbackLocalizationsDelegate old) => false;
}

UserFeedbackLocalizations lookupUserFeedbackLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return UserFeedbackLocalizationsHiLatn();
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
            return UserFeedbackLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return UserFeedbackLocalizationsAr();
    case 'as':
      return UserFeedbackLocalizationsAs();
    case 'bg':
      return UserFeedbackLocalizationsBg();
    case 'bn':
      return UserFeedbackLocalizationsBn();
    case 'cs':
      return UserFeedbackLocalizationsCs();
    case 'de':
      return UserFeedbackLocalizationsDe();
    case 'el':
      return UserFeedbackLocalizationsEl();
    case 'en':
      return UserFeedbackLocalizationsEn();
    case 'es':
      return UserFeedbackLocalizationsEs();
    case 'fa':
      return UserFeedbackLocalizationsFa();
    case 'fi':
      return UserFeedbackLocalizationsFi();
    case 'fr':
      return UserFeedbackLocalizationsFr();
    case 'hi':
      return UserFeedbackLocalizationsHi();
    case 'hy':
      return UserFeedbackLocalizationsHy();
    case 'it':
      return UserFeedbackLocalizationsIt();
    case 'ka':
      return UserFeedbackLocalizationsKa();
    case 'ko':
      return UserFeedbackLocalizationsKo();
    case 'pt':
      return UserFeedbackLocalizationsPt();
    case 'ru':
      return UserFeedbackLocalizationsRu();
    case 'sw':
      return UserFeedbackLocalizationsSw();
    case 'th':
      return UserFeedbackLocalizationsTh();
    case 'tr':
      return UserFeedbackLocalizationsTr();
    case 'uk':
      return UserFeedbackLocalizationsUk();
    case 'vi':
      return UserFeedbackLocalizationsVi();
    case 'zh':
      return UserFeedbackLocalizationsZh();
  }

  throw FlutterError(
    'UserFeedbackLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
