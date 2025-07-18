# Settings Flow Update Plan

## Overview
We need to restructure the settings flow to add a new entry point called "AllSettings". The current settings screen will become the new "AllSettings" screen, and we'll create a new UI component for settings entry items. Clicking these top level sections will either open a new page of specific settings that will lead to subsections, or it maybe a single page like the PIN setting. 

## Primary challenge

Ensure that no existing settings are removed; they should just be logically routed to from the new top level settings.

## Current Structure Analysis

### Existing Settings Items (from current settings_screen.dart):
1. **Backup Settings** - `SettingsRoute.backupSettings` → `BackupSettingsScreen` - DEDICATED SETTINGS PAGE
2. **Wallet Details** - `SettingsRoute.walletDetailsWalletList` → `WalletsListScreen` - PART OF BITCOIN SETTINGS PAGE
3. **Electrum Server Settings** - `ElectrumSettingsRouter.showElectrumServerSettings()` (bottom sheet) - PART OF WALLET SETTINGS PAGE
4. **Pin Code Settings** - `SettingsRoute.pinCode` → `PinCodeSettingFlow` - DIRECT ROUTE FROM SETTINGS
5. **Currency Settings** - `SettingsRoute.currency` → `CurrencySettingsScreen` - DEDICATED SETTINGS PAGE
6. **Auto Swap Settings** - `AutoSwapSettingsRouter.showAutoSwapSettings()` (bottom sheet) - PART OF WALLET SETTINGS PAGE
7. **Logs** - `SettingsRoute.logs` → `LogSettingsScreen` - PART OF APP SETTINGS
8. **Legacy Seeds** - `SettingsRoute.legacySeeds` → `LegacySeedViewScreen` (conditional) - PART OF BITCOIN SETTINGS
9. **Terms & Conditions** - External URL - DIRECT ROUTE FROM SETTINGS 
10. **Experimental/Danger Zone** - `SettingsRoute.experimental` → `ExperimentalSettingsScreen` (superuser + debug)
11. **Testnet Mode** - Toggle switch (superuser) - PART OF BITCOIN SETTINGS
12. **Language Settings** - `SettingsRoute.language` → `LanguageSettingsScreen` (superuser) - DEDICATED LANGUAGE SETTINGS PAGE
13. **Import watch-only** - `ImportWatchOnlyRoutes.import` (superuser) - Part of BITCOIN SETTINGS

### Bottom Section:
- App version display
- Telegram link
- Github link

## New Structure Plan

### AllSettings Screen (New Entry Point)
Will contain the following subsections:

1. **Exchange Account** - Placeholder (to be implemented)
2. **Wallet Backup** - Maps to existing backup settings
3. **Bitcoin Settings** - Maps to a new page with all the bitcoin related settings like existing electrum server, testnet mode, enable rbf, and everything else not included below
4. **Security Pin** - Maps to existing pin code settings
5. **Language** - Maps to existing language settings
6. **Currency** - Maps to existing currency settings to select bitcoin unit and fiat unit
7. **App Settings** - Maps to a new page which has Logs and later also Theme
7. **Terms of Service** - Maps to existing

### Bottom Section (Preserved):
- App version display
- Telegram link
- Github link

## Implementation Plan

### 1. Create New UI Component
**File:** `lib/ui/components/settings/settings_entry_item.dart`

Create a reusable component for settings entry items with:
- Icon on the left
- Title text
- Chevron right icon
- Consistent styling with the app theme
- Tap handling

### 2. Create AllSettings Screen
**File:** `lib/features/settings/ui/screens/all_settings_screen.dart`

Features:
- Clean list of settings subsections
- Uses the new `SettingsEntryItem` component
- Preserves the bottom section with version and links
- Proper navigation to existing settings screens

### 3. Update Router Configuration
**File:** `lib/features/settings/ui/settings_router.dart`

Changes:
- Add new route for `AllSettings`
- Update the main settings route to point to `AllSettingsScreen`
- Keep all existing sub-routes intact

### 4. Create Placeholder Screens
**Files:**
- `lib/features/settings/ui/screens/exchange_account_screen.dart`
- `lib/features/settings/ui/screens/help_screen.dart`

Simple placeholder screens with basic content.

### 5. Update Route Enum
**File:** `lib/features/settings/ui/settings_router.dart`

Add new routes:
- `allSettings('/all-settings')`
- `exchangeAccount('exchange-account')`
- `help('help')`

## File Structure Changes

### New Files to Create:
```
lib/ui/components/settings/
└── settings_entry_item.dart

lib/features/settings/ui/screens/
├── all_settings_screen.dart
├── exchange_account_screen.dart
└── help_screen.dart
```

### Files to Modify:
```
lib/features/settings/ui/settings_router.dart
lib/features/settings/ui/screens/settings_screen.dart (rename to all_settings_screen.dart)
```

## Navigation Mapping

### Existing → New Mapping:
- **Backup Settings** → Wallet Backup
- **Electrum Server Settings** → Bitcoin Settings  
- **Pin Code Settings** → Security Pin
- **Language Settings** → Language
- **Currency Settings** → Currency
- **Auto Swap Settings** → (Remove from main settings, keep accessible via other means)
- **Wallet Details** → (Remove from main settings, keep accessible via other means)
- **Logs** → (Remove from main settings, keep accessible via other means)
- **Legacy Seeds** → (Remove from main settings, keep accessible via other means)
- **Terms & Conditions** → (Remove from main settings, keep accessible via other means)
- **Experimental/Danger Zone** → (Remove from main settings, keep accessible via other means)
- **Testnet Mode** → (Remove from main settings, keep accessible via other means)
- **Import watch-only** → (Remove from main settings, keep accessible via other means)

## Implementation Steps

1. **Create SettingsEntryItem component**
2. **Create AllSettings screen**
3. **Create placeholder screens for Exchange Account and Help**
4. **Update router configuration**
5. **Test navigation flow**
6. **Update any references to the old settings screen**

## Notes

- The current `settings_screen.dart` will be replaced by `all_settings_screen.dart`
- All existing functionality will be preserved, just reorganized
- The new structure provides a cleaner, more focused settings experience
- Placeholder screens can be implemented later without breaking the current flow 