# UI Overhaul Plan

Inspired by the stacker project (`/Users/ishi/Code/stacker`), this plan outlines a comprehensive UI update for bullbitcoin-mobile focusing on a cleaner, more unified design aesthetic.

---

## Design Philosophy (From Stacker)

### Core Principles
1. **Minimal chrome** - No heavy borders, shadows, or containers
2. **Numbers as heroes** - Financial data is the star, everything else recedes
3. **Consistent green accents** - Primary color used sparingly for maximum impact
4. **Dark-first design** - Optimized for OLED screens and low-light use
5. **Locked interactions** - Snapping scrolls prevent "messy" partial states
6. **Subtle feedback** - Linear progress and toasts over modal spinners
7. **Blending over boxing** - Elements flow into background rather than sitting in cards

### Key UI Components from Stacker
- `BBDropdown` - Clean popup menu style dropdown with primary color accent
- `SnapScrollList` - Locked vertical scroll showing 1 item at a time with "X more" hint
- `SettingsEntryItem` - Consistent list item with optional subtitle
- `TransactionItem` - Clean transaction row with icon, label, date, and amount
- `FadingLinearProgress` - Thin progress line at top of screen

---

## Phase 1: Homepage Redesign

### 1.1 Remove Visual Separation
**Current State:**
- Top section with red background image (`bg-red.png`)
- Wallet cards in a separate scrollable section below
- Clear visual divide between balance area and wallet list

**Target State:**
- Single unified background (app background color, no image)
- Seamless flow from balance display through wallet cards to transaction preview

**Files to Modify:**
- `lib/features/wallet/ui/widgets/wallet_home_top_section.dart`
- `lib/features/wallet/ui/screens/wallet_home_screen.dart`

**Changes:**
1. Remove the background image from `WalletHomeTopSection`
2. Remove the Stack layout that creates visual separation
3. Use scaffold background color throughout
4. Remove fixed height constraints (264 + 78 + 46)

### 1.2 Wallet Cards in SnapScrollList Widget
**Current State:**
- Wallet cards displayed in a vertical Column
- Each card takes full width with margin

**Target State:**
- Wallet cards inside a `SnapScrollList` component
- Shows 1 wallet at a time with "X more" indicator
- Page-based snapping (no partial scrolls)
- Tap expands to full wallet list or detail

**Files to Modify:**
- `lib/features/wallet/ui/widgets/wallet_cards.dart`
- Create new `lib/core/widgets/snap_scroll_list.dart` (port from stacker)

**Changes:**
1. Port `SnapScrollList` widget from stacker
2. Wrap wallet cards in `SnapScrollList`
3. Add `onExpand` callback to navigate to wallet detail
4. Set appropriate `itemHeight` (approximately 80-100px)

### 1.3 Remove Address Display from Homepage
**Current State:**
- Address may be visible somewhere on home
- Transaction history icon in app bar

**Target State:**
- No address displayed on homepage (address is shown in receive flow)
- Remove transactions icon from top right app bar

**Files to Modify:**
- `lib/features/wallet/ui/widgets/wallet_home_app_bar.dart`

**Changes:**
1. Remove the transactions history icon button from actions
2. Keep settings icon and other essential navigation

### 1.4 Add Latest Transaction Preview
**Current State:**
- No transaction preview on homepage
- Must navigate to transactions screen to see activity

**Target State:**
- Show 1 latest transaction from all wallets in a `SnapScrollList`
- Displays when there are no warnings
- Tapping navigates to full transactions list

**Files to Create/Modify:**
- Create `lib/features/wallet/ui/widgets/home_transaction_preview.dart`
- Modify `lib/features/wallet/ui/screens/wallet_home_screen.dart`

**Component Structure:**
```dart
class HomeTransactionPreview extends StatelessWidget {
  // Uses SnapScrollList with 1 visible item
  // Shows latest transaction from WalletBloc state
  // Taps navigate to TransactionsRoute.transactions
}
```

**Layout Logic:**
1. Check if there are active warnings (`HomeWarnings`, `AutoSwapFeeWarning`)
2. If no warnings AND transactions exist, show `HomeTransactionPreview`
3. If warnings exist, hide transaction preview

### 1.5 Update App Bar
**Current State:**
- Bull logo in center
- Chart, chat icons on left
- Transactions, settings icons on right

**Target State:**
- Keep "Last synced: X" text in center (like stacker)
- Settings icon on right only
- Remove transactions icon (accessible via transaction preview tap)
- Keep chart and chat on left

**Files to Modify:**
- `lib/features/wallet/ui/widgets/wallet_home_app_bar.dart`

---

## Phase 2: Transactions Screen Update

### 2.1 Update Transaction List Item Styling
**Current State (TxListItem):**
- Container with surface background color
- Icon in bordered box on left
- Amount and labels in center
- Network tag and status on right

**Target State (inspired by stacker TransactionItem):**
- Cleaner, more minimal design
- Direction icon (arrow) with color based on type
- "Received/Sent" label with pending indicator
- Relative date (Today, Yesterday, 3d ago)
- Amount on right with +/- prefix

**Files to Modify:**
- `lib/features/transactions/ui/widgets/tx_list_item.dart`

**Changes:**
1. Simplify the container decoration (reduce visual weight)
2. Use direction arrows (south_west for receive, north_east for send)
3. Color the icon based on transaction type (primary for receive, muted for send)
4. Simplify date display to relative format
5. Add +/- prefix to amount based on direction

### 2.2 Update Filter Chips Styling
**Current State (TxsFilterItem):**
- Basic filter chips in horizontal scroll

**Target State (inspired by stacker _FilterChip):**
- Filled background when selected (primary color)
- Border only when not selected
- Show count badge for each filter
- Text color inverts when selected

**Files to Modify:**
- `lib/features/transactions/ui/widgets/txs_filter_item.dart`
- `lib/features/transactions/ui/widgets/txs_filter_row.dart`

**Changes:**
1. Add count prop to filter items
2. Update styling to match stacker filter chips
3. Selected state: primary background, inverted text
4. Unselected state: transparent background, border only

### 2.3 PageView-Based Transaction List
**Current State:**
- Standard ListView with all transactions

**Target State:**
- PageView-based vertical scrolling
- Calculate visible items based on screen height
- Snap to page boundaries

**Files to Modify:**
- `lib/core/widgets/lists/transactions_by_day_list.dart`
- `lib/features/transactions/ui/widgets/tx_list.dart`

---

## Phase 3: Dropdown Component Update

### 3.1 Replace BBDropdown Implementation
**Current State (`lib/core/widgets/dropdown/bb_dropdown.dart`):**
- Uses `DropdownButtonFormField`
- Has filled surface background
- Full-width with input decoration
- Requires `DropdownMenuItem<T>` items list

**Target State (inspired by stacker `BBDropdown`):**
- Uses `InkWell` + `showMenu` for popup menu approach
- Minimal, transparent background
- Only shows selected value with chevron
- Uses generic type with `labelBuilder` function

**Files to Modify:**
- `lib/core/widgets/dropdown/bb_dropdown.dart`

**New API:**
```dart
class BBDropdown<T> extends StatelessWidget {
  const BBDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) labelBuilder;
}
```

**Visual Changes:**
1. Remove InputDecoration wrapper
2. Use popup menu instead of dropdown overlay
3. Selected value in primary color
4. Chevron icon in primary color
5. Menu appears below with subtle border
6. Selected item highlighted with primary tint

### 3.2 Update All Dropdown Usages
**Files using dropdowns that need updating:**

1. **Settings Language Dropdown:**
   - `lib/features/settings/ui/screens/app_settings/app_settings_screen.dart`
   - Currently uses raw `DropdownButton<Language>`
   - Update to new `BBDropdown<Language>`

2. **Currency Settings:**
   - `lib/features/settings/ui/screens/currency/currency_settings_screen.dart`
   - May have currency/bitcoin unit dropdowns

3. **Any other dropdown usages:**
   - Search codebase for `DropdownButton` and `BBDropdown` usages
   - Update to new API pattern

**Migration Pattern:**
```dart
// Before
DropdownButton<Language>(
  value: currentLanguage,
  items: Language.values.map((l) => DropdownMenuItem(value: l, child: Text(l.label))).toList(),
  onChanged: (lang) => cubit.changeLanguage(lang),
)

// After
BBDropdown<Language>(
  value: currentLanguage,
  items: Language.values,
  labelBuilder: (lang) => lang.label,
  onChanged: (lang) => cubit.changeLanguage(lang),
)
```

---

## Phase 4: Settings Screen Update

### 4.1 Add Subtitle Support to SettingsEntryItem
**Current State:**
- Icon, title, and trailing widget
- No subtitle support

**Target State:**
- Add optional subtitle property
- Subtitle in muted text below title
- Useful for showing preview values (e.g., "5yr: $4K • 10yr: $14K")

**Files to Modify:**
- `lib/core/widgets/settings_entry_item.dart`

**Changes:**
```dart
class SettingsEntryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;  // NEW
  final VoidCallback? onTap;
  final Widget? trailing;
  // ...
}
```

### 4.2 Update Settings Screen Styling
**Files to Modify:**
- `lib/features/settings/ui/screens/app_settings/app_settings_screen.dart`
- `lib/features/settings/ui/screens/all_settings_screen.dart`

**Changes:**
1. Use new `BBDropdown` for language selector
2. Ensure consistent trailing widget styling
3. Add subtitles where helpful (e.g., growth rate preview)

---

## Phase 5: Logs Screen Update

### 5.1 Enhanced Logs Screen
**Current State (`lib/features/settings/ui/screens/app_settings/log_settings_screen.dart`):**
- Basic FutureBuilder with LogsViewerWidget
- Simple AppBar with title

**Target State (inspired by stacker `logs_screen.dart`):**
- Refresh button in app bar
- Entry count display with share/delete buttons
- Color-coded log levels (fine, info, warning, severe)
- Tap to copy individual log entry
- Delete confirmation dialog
- Share logs functionality

**Files to Modify:**
- `lib/features/settings/ui/screens/app_settings/log_settings_screen.dart`
- May need to update `lib/core/widgets/log_viewer_widget.dart`

**Features to Add:**
1. App bar with refresh action
2. Entry count header row
3. Share and delete action buttons
4. Log level color coding
5. Individual log entry tiles with timestamp, level, message
6. Tap to copy toast feedback

---

## Phase 6: Port Required Widgets

### 6.1 SnapScrollList Widget
**Source:** `stacker/lib/core/widgets/snap_scroll_list.dart`
**Target:** `bullbitcoin-mobile/lib/core/widgets/snap_scroll_list.dart`

Port the widget with adaptations for bullbitcoin-mobile's theme system.

### 6.2 Toast Widget (if not exists)
Check if bullbitcoin-mobile has a toast system, otherwise port from stacker.

### 6.3 FadingLinearProgress (already exists)
**Location:** `lib/core/widgets/loading/fading_linear_progress.dart`
Verify it matches stacker's implementation and is used in app bars.

---

## Implementation Order

### Sprint 1: Foundation
1. Port `SnapScrollList` widget
2. Update `BBDropdown` component
3. Update `SettingsEntryItem` with subtitle

### Sprint 2: Homepage
1. Remove background image and visual separation
2. Restructure home layout to unified design
3. Wrap wallet cards in `SnapScrollList`
4. Add transaction preview widget
5. Update app bar

### Sprint 3: Transactions
1. Update `TxListItem` styling
2. Update filter chip styling
3. Consider PageView-based list

### Sprint 4: Settings & Logs
1. Update settings screen with new dropdown
2. Update all dropdown usages project-wide
3. Enhance logs screen

---

## Testing Checklist

### Homepage
- [ ] No red background image visible
- [ ] Unified background throughout
- [ ] Wallet cards snap-scroll properly
- [ ] "X more" indicator shows for multiple wallets
- [ ] Tap wallet card navigates to detail
- [ ] Transaction preview visible when no warnings
- [ ] Transaction preview tap navigates to transactions list
- [ ] App bar shows settings only (no transactions icon)
- [ ] Pull-to-refresh works

### Transactions
- [ ] Transaction items styled correctly
- [ ] Direction icons colored appropriately
- [ ] Relative dates display correctly
- [ ] Filter chips show counts
- [ ] Selected filter has filled background

### Dropdowns
- [ ] Language dropdown uses new styling
- [ ] Popup menu appears below trigger
- [ ] Selected item highlighted in primary color
- [ ] All dropdown usages updated

### Settings
- [ ] Subtitles display where applicable
- [ ] New dropdown styling applied

### Logs
- [ ] Entry count visible
- [ ] Share button works
- [ ] Delete with confirmation
- [ ] Log levels color-coded
- [ ] Tap to copy works

---

## File Reference

### Files to Create
- `lib/core/widgets/snap_scroll_list.dart`
- `lib/features/wallet/ui/widgets/home_transaction_preview.dart`

### Files to Modify
- `lib/core/widgets/dropdown/bb_dropdown.dart`
- `lib/core/widgets/settings_entry_item.dart`
- `lib/features/wallet/ui/screens/wallet_home_screen.dart`
- `lib/features/wallet/ui/widgets/wallet_home_top_section.dart`
- `lib/features/wallet/ui/widgets/wallet_home_app_bar.dart`
- `lib/features/wallet/ui/widgets/wallet_cards.dart`
- `lib/features/transactions/ui/widgets/tx_list_item.dart`
- `lib/features/transactions/ui/widgets/txs_filter_item.dart`
- `lib/features/transactions/ui/widgets/txs_filter_row.dart`
- `lib/features/settings/ui/screens/app_settings/app_settings_screen.dart`
- `lib/features/settings/ui/screens/app_settings/log_settings_screen.dart`

### Reference Files from Stacker
- `stacker/lib/core/widgets/snap_scroll_list.dart`
- `stacker/lib/core/widgets/inputs/dropdown.dart`
- `stacker/lib/core/widgets/settings_entry_item.dart`
- `stacker/lib/features/stack/ui/screens/stack_screen.dart`
- `stacker/lib/features/wallet/ui/screens/transactions_screen.dart`
- `stacker/lib/features/wallet/ui/widgets/transaction_item.dart`
- `stacker/lib/features/settings/ui/screens/logs_screen.dart`
- `stacker/lib/features/settings/ui/screens/settings_screen.dart`
