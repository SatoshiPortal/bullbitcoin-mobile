# Bull Bitcoin Mobile Localization Skill

Automates the localization workflow for Bull Bitcoin Mobile features, ensuring consistency and proper naming conventions.

## When to Use This Skill

Use this skill when:
- Localizing a new feature in `lib/features/`
- The user asks to "localize [feature]" or "proceed with localization"
- Working through the localization backlog alphabetically

## How It Works

This skill will:
1. Create a feature branch with proper naming (`localization/features-<feature-name>`)
2. Scan the feature directory for hardcoded strings
3. Check for existing ARB keys or create new ones with proper naming convention
4. Update all Dart files to use `context.loc` calls
5. Run validation scripts
6. Create commit, push, and generate PR with detailed description
7. Update the tracking table

## Workflow Steps

### Step 1: Initialize
- Create branch: `git checkout -b localization/features-<feature-name>`
- Identify the feature directory: `lib/features/<feature-name>`

### Step 2: Scan for Strings
- Search for hardcoded strings in UI files
- Pattern: `['"][A-Z][^'"\n]{2,}['"]` in `lib/features/<feature-name>/ui/**/*.dart`
- Exclude: imports, class names, route names, asset paths

### Step 3: ARB Key Management
- Check if keys exist: `grep -i "<feature>" localization/app_en.arb`
- Naming convention: `<featureName><Screen><Element><Purpose>` (camelCase)
  - Example: `sendAmountInputLabel`, `receiveAddressQrCodeTitle`
- If keys don't exist, create them in all three ARB files (en, fr, es)
- Use proper prefixes: feature name without underscores (e.g., `legacySeedView`, `onboarding`)

### Step 4: Update Dart Files
For each file with hardcoded strings:
1. Add import: `import 'package:bb_mobile/core/utils/build_context_x.dart';`
2. Replace each hardcoded string with `context.loc.<keyName>`
3. Ensure proper key names are used

### Step 5: Validation
Run all three validation scripts:
```bash
python3 ./linux/validate_localizations.py
python3 ./linux/verify_localization_changes.py
python3 ./linux/check_localization_completion.py
```

All must pass before proceeding.

### Step 6: Commit & PR
```bash
# Commit
git add -A
git commit -m "feat: localization of features/<feature-name>

- Added context.loc calls for all UI strings
- Localized N strings across M files
- All ARB keys use proper <featureName> prefix
- Languages: English, French, Spanish"

# Push
git push -u origin localization/features-<feature-name>

# Create PR
gh pr create --title "feat: localization of features/<feature-name>" --body "<detailed-description>"
```

### Step 7: Update Tracking
- Update `linux/localization-overarching-plan.md`
- Change feature status to 👀 (In Review)
- Add PR number, branch name, assignee, and date
- Switch back to develop: `git checkout develop`

## Naming Conventions

### Branch Names
Pattern: `localization/features-<feature-name>` (use hyphens)
Examples:
- `localization/features-legacy-seed-view`
- `localization/features-onboarding`
- `localization/features-pin-code`

### ARB Key Names
Pattern: `<featureName><Screen><Element><Purpose>` (camelCase, no underscores)

**Feature Name Prefix:**
- Remove underscores from feature directory name
- Use camelCase
- Examples:
  - `legacy_seed_view` → `legacySeedView`
  - `pin_code` → `pinCode`
  - `recoverbull_google_drive` → `recoverbullGoogleDrive`

**Element Types:**
- `Title` - Screen/section titles
- `Label` - Field labels
- `Button` - Button text
- `Hint` - Input placeholders
- `Message` - Toast/snackbar messages
- `Error` - Error messages
- `Description` - Longer explanatory text
- `ScreenTitle` - AppBar titles

**Examples:**
- `sendScreenTitle` - "Send Bitcoin"
- `sendAmountInputLabel` - "Amount"
- `sendContinueButton` - "Continue"
- `sendInsufficientBalanceError` - "Insufficient balance"
- `receiveAddressQrCodeTitle` - "Receive Address"

### Commit Message Format
```
feat: localization of features/<feature-name>

- Added context.loc calls for all UI strings
- Localized N strings across M files
- All ARB keys use proper <featureName> prefix
- Languages: English, French, Spanish

Strings localized:
- [Brief list of main strings]
```

## PR Template

```markdown
## Localization: <feature-name>

### Overview
- Feature: `lib/features/<feature-name>`
- Strings localized: N
- Files modified: M (X Dart files + Y ARB files)
- Branch: `localization/features-<feature-name>`

### Changes
- [x] Added BuildContextX import to affected files
- [x] Replaced hardcoded strings with context.loc calls
- [x] Added/used ARB keys with proper naming
- [x] Validated with all three validation scripts
- [x] Tested with flutter analyze

### Localized Strings
1. **[Description]**: "[Original]" → `<keyName>`
...

### Validation Results
✅ Changed files pass flutter analyze

### Testing
- [x] All localization keys exist in ARB files
- [x] No hardcoded strings remain
- [x] Changed files pass flutter analyze
- [x] Follows naming conventions

### Notes
- [Any special notes about this feature]
```

## Common Patterns

### Adding Import
```dart
import 'package:bb_mobile/core/utils/build_context_x.dart';
```

### Replacing Strings
```dart
// Before
Text('Send Bitcoin')

// After
Text(context.loc.sendScreenTitle)
```

### Button Labels
```dart
// Before
BBButton.big(
  label: 'Continue',
  ...
)

// After
BBButton.big(
  label: context.loc.sendContinueButton,
  ...
)
```

### AppBar Titles
```dart
// Before (const)
AppBar(
  title: const BBText('Screen Title'),
)

// After (remove const)
AppBar(
  title: BBText(context.loc.featureScreenTitle),
)
```

## Validation Scripts

### 1. validate_localizations.py
- Checks all 3 ARB files are synchronized
- Verifies same keys in same order
- Validates JSON syntax

### 2. verify_localization_changes.py
- Analyzes git diff
- Verifies hardcoded strings were replaced
- Checks context.loc calls are valid

### 3. check_localization_completion.py
- Scans feature directory for remaining hardcoded strings
- Confirms localization is complete

## Error Handling

### Pre-commit Hook Failures
If pre-commit hook fails with errors in unrelated features (e.g., swap):
```bash
git commit --no-verify -m "..."
```
Only use if errors are pre-existing and unrelated to your changes.

### Missing ARB Keys
If validation finds missing keys:
1. Check if key exists with different name
2. Add to all three ARB files in correct alphabetical order
3. Regenerate: `fvm flutter gen-l10n`

### ARB File Conflicts
If working on multiple features simultaneously:
1. Pull latest develop before starting
2. Merge frequently
3. Resolve conflicts carefully maintaining key order

## Special Pattern: Features with Custom Error Classes

### ⚠️ IMPORTANT: New Pattern Available!

**As of 2025-11-20**, there is a **NEW RECOMMENDED PATTERN** for handling error translations.

📖 **See [error-handling-patterns.md](./error-handling-patterns.md) for complete documentation.**

### Quick Overview

Features with `lib/features/<feature-name>/errors.dart` files now use the **`toTranslated()` method pattern** instead of passing BuildContext through events.

**New Pattern (Recommended):**
```dart
// Error class
abstract class FeatureError {
  String toTranslated(BuildContext context);
}

class SomeError extends FeatureError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.featureErrorSome;
  }
}

// Bloc emits error without BuildContext
emit(state.copyWith(error: SomeError()));

// UI translates at display time
Text(state.error!.toTranslated(context))
```

**Benefits:**
- ✅ No BuildContext in business logic
- ✅ Clean event signatures
- ✅ Type-safe error handling
- ✅ Errors can store runtime data

**Features with custom errors.dart files:**
1. ✅ **recoverbull** - Now using toTranslated() pattern (PR #1538)
2. ⚠️ **recoverbull_google_drive** - Still using old pattern (can migrate)
3. ⚠️ **replace_by_fee** - Still using old pattern (can migrate)
4. ✅ **import_mnemonic** - Already localized (PR #1491)
5. ✅ **broadcast_signed_tx** - Already localized (PR #1478)
6. ✅ **bip85_entropy** - Already localized (PR #1474)

**When localizing a feature with errors.dart:**
1. Check if it already uses the old BuildContext parameter pattern
2. Use the NEW `toTranslated()` pattern (see [error-handling-patterns.md](./error-handling-patterns.md))
3. Migrate old pattern features when refactoring

---

## Legacy Pattern: BuildContext Parameter (Deprecated)

The following section describes the OLD pattern. **Use the new `toTranslated()` pattern instead.**

<details>
<summary>Click to view legacy BuildContext parameter pattern (deprecated)</summary>

### Why This Pattern Was Needed

**Standard Pattern (Most Features):**
- Errors stored in bloc state as strings
- UI layer handles localization when displaying
- No BuildContext needed in bloc

**Custom Error Pattern (Features with errors.dart):**
- Error classes extend `BullError` (framework exception)
- Errors thrown in bloc layer, caught by framework
- Framework displays error directly to user
- **Requires BuildContext to access localized strings**

### Architecture Difference

```dart
// Standard Pattern (receive, pin_code, psbt_flow, etc.)
// ✅ No context needed in bloc
try {
  await someOperation();
} catch (e) {
  emit(state.copyWith(error: e.toString()));  // String in state
}
// UI decides how to display using context.loc

// Custom Error Pattern (recoverbull, recoverbull_google_drive, replace_by_fee)
// ⚠️ Context REQUIRED in bloc
try {
  await someOperation();
} catch (e) {
  throw KeyServerConnectionError(context);  // BullError with localized message
}
// Framework catches and displays directly
```

### Implementation Steps for Custom Error Features

#### Step 1: Update Error Classes

**File:** `lib/features/<feature-name>/errors.dart`

Add BuildContext parameter to ALL error class constructors:

```dart
// Before
class KeyServerConnectionError extends BullError {
  KeyServerConnectionError() : super('Failed to connect to key server');
}

// After
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class KeyServerConnectionError extends BullError {
  KeyServerConnectionError(BuildContext context)
    : super(context.loc.recoverbullErrorConnectionFailed);
}
```

**Do this for ALL error classes in the file.**

#### Step 2: Update Event Classes

**File:** `lib/features/<feature-name>/presentation/event.dart`

Add optional `BuildContext? context` parameter to ALL event classes:

```dart
// Add to freezed event definition
@freezed
class RecoverBullEvent with _$RecoverBullEvent {
  const factory RecoverBullEvent.onVaultProviderSelection({
    required VaultProvider provider,
    BuildContext? context,  // ← Add this
  }) = OnVaultProviderSelection;

  const factory RecoverBullEvent.onVaultSelection({
    required VaultProvider provider,
    BuildContext? context,  // ← Add this
  }) = OnVaultSelection;

  // Add to ALL events
}
```

**Run build_runner after changes:**
```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

#### Step 3: Update Bloc Error Handling

**File:** `lib/features/<feature-name>/presentation/bloc.dart`

Use defensive pattern when instantiating errors:

```dart
// Add import
import 'package:flutter/material.dart';

// Defensive error instantiation pattern
try {
  // Business logic
} catch (e) {
  if (event.context != null) {
    // Localized error when context available
    emit(state.copyWith(
      error: KeyServerConnectionError(event.context!)
    ));
  } else {
    // Fallback to generic error when context unavailable
    emit(state.copyWith(
      error: BullError('Failed to connect to key server')
    ));
  }
}
```

**Why defensive?**
- Prevents crashes during bloc initialization
- Some events triggered internally without context
- Provides English fallback for edge cases

#### Step 4: Propagate Context Through Event Chain

When bloc dispatches internal events, pass context forward:

```dart
// Before
add(OnVaultSelection(provider: provider));

// After
add(OnVaultSelection(provider: provider, context: event.context));
```

**Trace the event flow and update ALL internal dispatches.**

#### Step 5: Update UI Event Dispatches

**Files:** All UI files that dispatch events

Add context when dispatching from UI:

```dart
// Before
context.read<RecoverBullBloc>().add(
  OnVaultProviderSelection(provider: provider),
);

// After
context.read<RecoverBullBloc>().add(
  OnVaultProviderSelection(provider: provider, context: context),
);
```

#### Step 6: Handle Const Constructor Events

In bloc constructor, events without context remain const:

```dart
class RecoverBullBloc extends Bloc<RecoverBullEvent, RecoverBullState> {
  RecoverBullBloc(...) : super(...) {
    // Register handlers...

    // These can stay const - no context needed during initialization
    add(const OnTorInitialization());
    add(const OnServerCheck());
  }
}
```

### Validation for Custom Error Pattern

After implementing, verify:

1. **All error classes accept BuildContext**
   ```bash
   grep "extends.*Error" lib/features/<feature>/errors.dart
   # Each should have (BuildContext context) parameter
   ```

2. **All events have optional context**
   ```bash
   grep "BuildContext?" lib/features/<feature>/presentation/event.dart
   # Should find context parameter in all events
   ```

3. **Bloc uses defensive pattern**
   ```bash
   grep -A 3 "event.context !=" lib/features/<feature>/presentation/bloc.dart
   # Should find if/else checks before error instantiation
   ```

4. **UI passes context**
   ```bash
   grep "context: context" lib/features/<feature>/ui/
   # Should find context being passed in event dispatches
   ```

### Testing Custom Error Pattern

Test scenarios:
1. ✅ Error during user action (context available) → Localized message
2. ✅ Error during bloc init (no context) → Generic English message
3. ✅ Error in French app → Message in French
4. ✅ Error in Spanish app → Message in Spanish

### Common Mistakes to Avoid

❌ **Forgetting defensive pattern:**
```dart
// BAD - will crash if context is null
throw KeyServerConnectionError(event.context!);
```

✅ **Correct - defensive:**
```dart
if (event.context != null) {
  throw KeyServerConnectionError(event.context!);
} else {
  throw BullError('Generic fallback message');
}
```

❌ **Not propagating context:**
```dart
// BAD - loses context in chain
add(OnNextEvent(data: data));  // No context!
```

✅ **Correct - propagate:**
```dart
add(OnNextEvent(data: data, context: event.context));
```

❌ **Making all events non-const:**
```dart
// BAD - unnecessary
add(OnTorInit());  // Could be const
```

✅ **Correct - keep const when possible:**
```dart
add(const OnTorInit());  // No context needed
```

### Summary Checklist for Custom Error Features (Legacy)

When localizing a feature with `errors.dart` using the OLD pattern:

- [ ] Add BuildContext parameter to all error classes
- [ ] Add optional context to all event classes
- [ ] Run build_runner to regenerate freezed code
- [ ] Update bloc with defensive error pattern
- [ ] Propagate context through event chains
- [ ] Update UI to pass context in event dispatches
- [ ] Keep const for initialization events
- [ ] Test errors in all 3 languages
- [ ] Verify no crashes when context unavailable
- [ ] Document pattern in PR description

**⚠️ This is the deprecated pattern. Use `toTranslated()` method pattern instead.**

</details>

---

## Tips

1. **Always start from develop**: `git checkout develop && git pull`
2. **Create branch first**: Before making any changes
3. **Use existing keys when possible**: Search ARB files first
4. **Follow naming convention strictly**: Consistent prefixes
5. **Test after each file**: Run flutter analyze frequently
6. **Validate before commit**: Run all 3 scripts
7. **Update tracking table**: Mark as In Review after PR creation

## File Locations

- **ARB Files**: `localization/app_*.arb`
- **Validation Scripts**: `linux/*.py`
- **Tracking Table**: `linux/localization-overarching-plan.md`
- **Feature Method Guide**: `linux/localization-feature-method.md`
- **Features**: `lib/features/<feature-name>/ui/**/*.dart`

## Success Criteria

A localization is complete when:
- ✅ All 3 validation scripts pass
- ✅ Flutter analyze shows no errors in changed files
- ✅ No hardcoded strings remain in feature
- ✅ All keys follow naming convention
- ✅ PR created with detailed description
- ✅ Tracking table updated

## Next Feature Selection

Always select alphabetically from remaining features:
1. Check `linux/localization-overarching-plan.md`
2. Find features with status ❌ (Not Started)
3. Select first alphabetically
4. Prioritize HIGH priority if multiple options
5. **Check if feature has `errors.dart` file** - requires special pattern

## Quick Reference: Feature Patterns

| Feature | Has errors.dart? | Pattern Required | Status |
|---------|-----------------|------------------|--------|
| recoverbull | ✅ Yes | Custom Error Pattern (Bloc) | ✅ Done (PR #1521) |
| recoverbull_google_drive | ✅ Yes | Custom Error Pattern (Bloc) | ✅ Done (PR #1522) |
| replace_by_fee | ✅ Yes | Custom Error Pattern (Cubit) | ✅ Done (PR #1524) |
| import_mnemonic | ✅ Yes | Custom Error Pattern | ✅ Done (PR #1491) |
| broadcast_signed_tx | ✅ Yes | Custom Error Pattern | ✅ Done (PR #1478) |
| bip85_entropy | ✅ Yes | Custom Error Pattern | ✅ Done (PR #1474) |
| **All other features** | ❌ No | **Standard Pattern** | Various |

**Standard Pattern Features (No errors.dart):**
receive, pin_code, psbt_flow, pay, onboarding, send, sell, swap, settings, transactions, wallet, and most others.

**All features with custom errors are now complete! ✅**

**To Check Before Starting:**
```bash
# Quick check for errors.dart
ls lib/features/<feature-name>/errors.dart 2>/dev/null && echo "⚠️  Use Custom Error Pattern" || echo "✅ Use Standard Pattern"
```
