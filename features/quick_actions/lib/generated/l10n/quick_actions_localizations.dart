import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'quick_actions_localizations_en.dart';
import 'quick_actions_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of QuickActionsLocalizations
/// returned by `QuickActionsLocalizations.of(context)`.
///
/// Applications need to include `QuickActionsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/quick_actions_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: QuickActionsLocalizations.localizationsDelegates,
///   supportedLocales: QuickActionsLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the QuickActionsLocalizations.supportedLocales
/// property.
abstract class QuickActionsLocalizations {
  QuickActionsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static QuickActionsLocalizations of(BuildContext context) {
    return Localizations.of<QuickActionsLocalizations>(
      context,
      QuickActionsLocalizations,
    )!;
  }

  static const LocalizationsDelegate<QuickActionsLocalizations> delegate =
      _QuickActionsLocalizationsDelegate();

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
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get title;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get reset;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes. Please try again.'**
  String get saveFailed;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceHistory;

  /// No description provided for @quickActionTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get quickActionTrade;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'On Home'**
  String get onHome;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'In More'**
  String get inMore;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'Price history'**
  String get priceHistoryFull;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// Wallet quick action customization.
  ///
  /// In en, this message translates to:
  /// **'No actions selected. Settings stays on Home.'**
  String get emptyHint;

  /// Full accessible quick action name.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportFull;

  /// Confirmation after restoring the default Home actions.
  ///
  /// In en, this message translates to:
  /// **'Default actions restored.'**
  String get defaultsRestored;

  /// Restore the complete preference from before Restore defaults.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Accessible action that moves this row onto Home, displacing its previous last action if full.
  ///
  /// In en, this message translates to:
  /// **'Move to Home'**
  String get moveToHome;

  /// Accessible action that moves this row below the fixed separator.
  ///
  /// In en, this message translates to:
  /// **'Move to More'**
  String get moveToMore;

  /// Explains whole-row long press and the Home capacity.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an action to move it. Home holds up to 3 actions.'**
  String get dragHint;
}

class _QuickActionsLocalizationsDelegate
    extends LocalizationsDelegate<QuickActionsLocalizations> {
  const _QuickActionsLocalizationsDelegate();

  @override
  Future<QuickActionsLocalizations> load(Locale locale) {
    return SynchronousFuture<QuickActionsLocalizations>(
      lookupQuickActionsLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_QuickActionsLocalizationsDelegate old) => false;
}

QuickActionsLocalizations lookupQuickActionsLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return QuickActionsLocalizationsEn();
    case 'fr':
      return QuickActionsLocalizationsFr();
  }

  throw FlutterError(
    'QuickActionsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
