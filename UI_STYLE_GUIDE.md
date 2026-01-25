# UI Style Guide

This document outlines the design philosophy and component updates implemented in the Bull Bitcoin mobile app UI overhaul, inspired by the stacker project's cypherpunk aesthetic.

---

## Design Philosophy

### Core Principles

1. **Subtle over Loud**
   - Avoid large blocks of color or heavy visual elements
   - Use thin borders, muted colors, and subtle shadows
   - Draw attention through typography and spacing, not bold containers

2. **No Ugly Greys**
   - Avoid heavy grey backgrounds on cards and containers
   - Use transparent backgrounds with subtle borders instead
   - When containers are needed, use very light opacity borders (0.15-0.3 alpha)

3. **Numbers as Heroes**
   - Financial data (balances, amounts) should be the visual focus
   - Supporting UI elements recede into the background
   - Use primary color sparingly for maximum impact

4. **Dark-First Design**
   - Optimized for OLED screens and low-light usage
   - All colors must work in both light and dark modes
   - Use theme-aware colors (`context.appColors.text`, `textMuted`, etc.)

5. **Locked Interactions**
   - Snap-scrolling prevents messy partial scroll states
   - PageView-based lists for transaction groups and logs
   - Clear visual boundaries with "X more" hints

6. **Blending over Boxing**
   - Elements flow into the background rather than sitting in heavy cards
   - Minimize visual chrome (borders, shadows, containers)
   - Use whitespace and typography for hierarchy

---

## Color Usage

### Theme Colors (Always Use These)

| Color | Usage |
|-------|-------|
| `context.appColors.text` | Primary text, important values |
| `context.appColors.textMuted` | Secondary text, descriptions, labels |
| `context.appColors.primary` | Accent color (red), interactive elements, selected states |
| `context.appColors.success` | Positive indicators, received amounts |
| `context.appColors.warning` | Pending states, caution indicators |
| `context.appColors.error` | Error states, destructive actions |
| `context.appColors.background` | Screen backgrounds |
| `context.appColors.border` | Subtle borders (use with low alpha) |

### Avoid

- Hardcoded colors (`Colors.grey`, `Color(0xFF...)`)
- `onPrimary` for general text (doesn't adapt to light mode)
- Heavy background colors on containers

---

## Updated Components

### SettingsEntryItem

**Before:** Custom `InkWell` with manual layout
**After:** Standard `ListTile` with proper spacing

```dart
SettingsEntryItem(
  icon: Icons.language,
  title: 'Language',
  subtitle: 'Optional description',  // NEW
  trailing: BBSettingsDropdown<Language>(...),
  onTap: () => ...,
)
```

- Uses `bodyLarge` for titles (proper hierarchy)
- Optional `subtitle` in `labelSmall` with `textMuted` color
- Primary colored chevrons for navigation items
- Consistent vertical spacing from `ListTile`

### WalletCard

**Before:** 98px height, heavy shadows
**After:** 72px height, subtle shadows

Changes:
- Container height: 90px → 68px
- Vertical padding: 4px → 2px
- Font sizes: `bodyLarge` → `bodyMedium`, `labelMedium` → `labelSmall`
- Shadow elevation: 2 → 1
- Left border: 4px → 3px
- Colors: `secondary` → `text`/`textMuted`

### SnapScrollList

PageView-based vertical scrolling with snap behavior.

```dart
SnapScrollList<Transaction>(
  items: transactions,
  itemHeight: 64,
  visibleItemCount: 3,  // Show up to 3 items
  showExpandHint: true,  // Show "X more" hint
  itemBuilder: (context, tx, index) => TxListItem(tx: tx),
)
```

Used in:
- Wallet cards on home (2 visible)
- Transaction preview on home
- Daily transaction groups
- Logs viewer

### TxListItem

**Before:** Heavy container with multiple decorations
**After:** Minimal row with direction icon

Changes:
- Removed container background
- Simple direction icons (`Icons.south_west_rounded`, `Icons.north_east_rounded`)
- Icon color: primary for receive, textMuted for send
- Amount prefix: `+` for receive, `-` for send
- Relative dates using `timeago` package
- Reduced padding: 16px → 12px horizontal

### BBSettingsDropdown

Minimal popup menu dropdown matching stacker style.

```dart
BBSettingsDropdown<Language>(
  value: currentLanguage,
  items: Language.values,
  labelBuilder: (lang) => lang.label,
  onChanged: (lang) => ...,
)
```

- No heavy input decoration
- Primary colored text and chevron
- Popup menu instead of dropdown overlay

### AutoswapWarningCard

**Before:** Heavy grey background, bold styling
**After:** Subtle border, clean layout

Changes:
- Transparent background with subtle border
- Icon color: `success` (green) instead of primary
- Softer text colors
- Reduced visual weight

### LogsViewerWidget

**Before:** Standard ListView with horizontal scroll
**After:** PageView-based locked scrolling

Features:
- Calculates visible items based on screen height
- Color-coded log levels (dot indicator)
- Tap to open detail bottom sheet
- Copy, share, delete actions in header
- Clean entry tiles with border (no grey background)

### PriceChartWidget

**Before:** Hardcoded `onPrimary` colors
**After:** Theme-aware colors

Changes:
- Price text: `text` color
- Date/currency: `textMuted` color
- Chart line: `textMuted` color
- Selection dot: `warning` color (orange)
- Dot border: `text` color

---

## Layout Patterns

### Settings Screens

```dart
Scaffold(
  appBar: AppBar(
    title: BBText(
      'Settings',
      style: context.font.headlineMedium,
      color: context.appColors.text,
    ),
    backgroundColor: context.appColors.transparent,
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: context.appColors.text),
      onPressed: () => context.pop(),
    ),
  ),
  body: SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SettingsEntryItem(...),
            SettingsEntryItem(...),
          ],
        ),
      ),
    ),
  ),
)
```

### Subtle Containers

When containers are needed, use thin borders with low opacity:

```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: context.appColors.border.withValues(alpha: 0.3),
      width: 0.5,
    ),
  ),
  child: ...,
)
```

### Bottom Sheets

```dart
Container(
  decoration: BoxDecoration(
    color: context.appColors.background,  // Not grey!
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  ),
  child: Column(
    children: [
      // Handle bar
      Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: context.appColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      // Content
    ],
  ),
)
```

---

## Typography

| Style | Usage |
|-------|-------|
| `displaySmall` | Large hero numbers (price display) |
| `headlineMedium` | Screen titles in app bar |
| `bodyLarge` | Settings item titles, primary content |
| `bodyMedium` | Card titles, important values |
| `bodySmall` | Descriptions, secondary content |
| `labelMedium` | Badges, tags |
| `labelSmall` | Timestamps, hints, subtitles |

---

## Spacing

- Screen horizontal padding: 16px
- Between major sections: 16px (Gap)
- Between related items: 8px (Gap)
- Card internal padding: 12px horizontal, 6-10px vertical
- ListTile uses built-in spacing (don't override)

---

## Icon Guidelines

- Size: 20-22px for settings/list items
- Color: `text` for leading icons, `primary` for trailing chevrons
- Use outlined variants when available (`Icons.article_outlined`)
- Direction icons: `south_west_rounded` (receive), `north_east_rounded` (send)

---

## Anti-Patterns (Avoid These)

1. **Heavy grey containers**
   ```dart
   // BAD
   Container(color: Colors.grey[800], ...)
   
   // GOOD
   Container(
     decoration: BoxDecoration(
       border: Border.all(color: context.appColors.border.withValues(alpha: 0.3)),
     ),
   )
   ```

2. **Hardcoded colors**
   ```dart
   // BAD
   color: Colors.white
   
   // GOOD
   color: context.appColors.text
   ```

3. **Bold everything**
   ```dart
   // BAD
   fontWeight: FontWeight.bold
   
   // GOOD
   fontWeight: FontWeight.w500  // or just use the theme style
   ```

4. **Large shadows**
   ```dart
   // BAD
   elevation: 8
   
   // GOOD
   elevation: 1
   ```

5. **Thick borders**
   ```dart
   // BAD
   Border.all(width: 2)
   
   // GOOD
   Border.all(width: 0.5)
   ```

---

## Summary

The new UI follows a "less is more" approach:
- Subtle borders instead of heavy backgrounds
- Theme colors that adapt to light/dark mode
- Snap-scrolling for locked, clean interactions
- Primary color used sparingly for accents
- Typography and spacing create hierarchy, not heavy containers
- Clean, minimal components that blend into the background
