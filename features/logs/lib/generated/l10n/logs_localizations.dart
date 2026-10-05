import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'logs_localizations_ar.dart';
import 'logs_localizations_as.dart';
import 'logs_localizations_bg.dart';
import 'logs_localizations_bn.dart';
import 'logs_localizations_cs.dart';
import 'logs_localizations_de.dart';
import 'logs_localizations_el.dart';
import 'logs_localizations_en.dart';
import 'logs_localizations_es.dart';
import 'logs_localizations_fa.dart';
import 'logs_localizations_fi.dart';
import 'logs_localizations_fr.dart';
import 'logs_localizations_hi.dart';
import 'logs_localizations_hy.dart';
import 'logs_localizations_it.dart';
import 'logs_localizations_ka.dart';
import 'logs_localizations_ko.dart';
import 'logs_localizations_pt.dart';
import 'logs_localizations_ru.dart';
import 'logs_localizations_sw.dart';
import 'logs_localizations_th.dart';
import 'logs_localizations_tr.dart';
import 'logs_localizations_uk.dart';
import 'logs_localizations_vi.dart';
import 'logs_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LogsLocalizations
/// returned by `LogsLocalizations.of(context)`.
///
/// Applications need to include `LogsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/logs_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LogsLocalizations.localizationsDelegates,
///   supportedLocales: LogsLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the LogsLocalizations.supportedLocales
/// property.
abstract class LogsLocalizations {
  LogsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LogsLocalizations of(BuildContext context) {
    return Localizations.of<LogsLocalizations>(context, LogsLocalizations)!;
  }

  static const LocalizationsDelegate<LogsLocalizations> delegate =
      _LogsLocalizationsDelegate();

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

  /// Title for the logs section in settings
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logSettingsLogsTitle;

  /// Button to confirm deleting all logs
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get logsViewerDeleteButton;

  /// Tooltip for the log filters button
  ///
  /// In en, this message translates to:
  /// **'Filter logs'**
  String get logsViewerFilter;

  /// Button to open the share/export options for logs
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get logsViewerShareButton;

  /// Error message shown when sharing logs fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share logs'**
  String get logsShareFailedMessage;

  /// Confirmation message when logs are exported as a file
  ///
  /// In en, this message translates to:
  /// **'Logs exported successfully'**
  String get logsExportedMessage;

  /// Error message when log export fails
  ///
  /// In en, this message translates to:
  /// **'Failed to export logs'**
  String get logsExportFailedMessage;

  /// Counter showing filtered vs total log entries
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} logs'**
  String logsViewerShowingCount(int shown, int total);

  /// Button that collapses all visible log entries to one line
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get logsViewerCollapseAll;

  /// Button that expands all visible log entries onto multiple lines
  ///
  /// In en, this message translates to:
  /// **'Wrap all'**
  String get logsViewerWrapAll;

  /// Empty state when no logs have been recorded
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get logsViewerEmpty;

  /// Empty state when filters hide every log entry
  ///
  /// In en, this message translates to:
  /// **'No logs match the active filters'**
  String get logsViewerNoMatches;

  /// Tooltip for the button that clears the date filter
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get logsViewerClearFilter;

  /// Hint for the log search field
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get logsViewerSearchHint;

  /// Button label to filter logs by date range
  ///
  /// In en, this message translates to:
  /// **'Filter by Date'**
  String get logsViewerFilterByDate;

  /// Accessibility hint for an expanded log entry
  ///
  /// In en, this message translates to:
  /// **'Tap to collapse. Long press to copy.'**
  String get logsViewerCollapseHint;

  /// Hint explaining how to expand and copy a collapsed log entry
  ///
  /// In en, this message translates to:
  /// **'Tap a log to expand it. Long press to copy.'**
  String get logsViewerExpandHint;

  /// Snackbar confirmation message after copying to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboardMessage;

  /// Title of the delete logs confirmation bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Delete logs'**
  String get logsViewerDeleteTitle;

  /// Confirmation message shown before deleting all logs
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all logs? This action cannot be undone.'**
  String get logsViewerDeleteConfirmation;

  /// Confirmation message when logs are deleted
  ///
  /// In en, this message translates to:
  /// **'Logs deleted'**
  String get logsDeletedMessage;

  /// Button to cancel deleting logs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get logsViewerCancelButton;

  /// Option in the bottom sheet to share logs as text
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get logsShareOptionShare;

  /// Option in the bottom sheet to export logs as a file to Downloads or iCloud Drive
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logsShareOptionExport;

  /// Error title when something goes wrong
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oopsSomethingWentWrong;

  /// Generic retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _LogsLocalizationsDelegate
    extends LocalizationsDelegate<LogsLocalizations> {
  const _LogsLocalizationsDelegate();

  @override
  Future<LogsLocalizations> load(Locale locale) {
    return SynchronousFuture<LogsLocalizations>(
      lookupLogsLocalizations(locale),
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
  bool shouldReload(_LogsLocalizationsDelegate old) => false;
}

LogsLocalizations lookupLogsLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return LogsLocalizationsHiLatn();
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
            return LogsLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LogsLocalizationsAr();
    case 'as':
      return LogsLocalizationsAs();
    case 'bg':
      return LogsLocalizationsBg();
    case 'bn':
      return LogsLocalizationsBn();
    case 'cs':
      return LogsLocalizationsCs();
    case 'de':
      return LogsLocalizationsDe();
    case 'el':
      return LogsLocalizationsEl();
    case 'en':
      return LogsLocalizationsEn();
    case 'es':
      return LogsLocalizationsEs();
    case 'fa':
      return LogsLocalizationsFa();
    case 'fi':
      return LogsLocalizationsFi();
    case 'fr':
      return LogsLocalizationsFr();
    case 'hi':
      return LogsLocalizationsHi();
    case 'hy':
      return LogsLocalizationsHy();
    case 'it':
      return LogsLocalizationsIt();
    case 'ka':
      return LogsLocalizationsKa();
    case 'ko':
      return LogsLocalizationsKo();
    case 'pt':
      return LogsLocalizationsPt();
    case 'ru':
      return LogsLocalizationsRu();
    case 'sw':
      return LogsLocalizationsSw();
    case 'th':
      return LogsLocalizationsTh();
    case 'tr':
      return LogsLocalizationsTr();
    case 'uk':
      return LogsLocalizationsUk();
    case 'vi':
      return LogsLocalizationsVi();
    case 'zh':
      return LogsLocalizationsZh();
  }

  throw FlutterError(
    'LogsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
