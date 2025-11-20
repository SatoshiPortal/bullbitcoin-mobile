# Bull Bitcoin Mobile Localization Skill

This skill automates the localization workflow for Bull Bitcoin Mobile features.

## Documentation Files

### [skill.md](./skill.md)
Main skill documentation covering:
- When to use this skill
- Complete workflow steps (branch creation, scanning, ARB management, validation, PR creation)
- Naming conventions for branches, ARB keys, and commits
- PR template and validation scripts
- Legacy error handling pattern (deprecated)

### [error-handling-patterns.md](./error-handling-patterns.md) ⭐ NEW
**Recommended error handling pattern** for features with custom error classes:
- `toTranslated()` method pattern (NEW - PR #1538)
- Complete implementation guide
- Migration guide from old BuildContext parameter pattern
- Examples and best practices
- ARB key naming for errors

## Quick Reference

### Standard Features (No errors.dart)
Use the main skill workflow - simple string replacement with `context.loc` calls.

### Features with Custom Errors (Has errors.dart)
**Use the NEW pattern** documented in [error-handling-patterns.md](./error-handling-patterns.md):

```dart
// Abstract base class
abstract class FeatureError {
  String toTranslated(BuildContext context);
}

// Implementation
class SomeError extends FeatureError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.featureErrorSome;
  }
}

// Bloc (no BuildContext needed)
emit(state.copyWith(error: SomeError()));

// UI (translate at display time)
Text(state.error!.toTranslated(context))
```

## Recent Updates

- **2025-11-20**: Added new `toTranslated()` error handling pattern (PR #1538)
- **2025-11-17**: Completed all features with custom error classes
- Initial skill creation with BuildContext parameter pattern

## See Also

- Main project guide: [CLAUDE.md](../../CLAUDE.md)
- Localization planning: [linux/localization-overarching-plan.md](../../linux/localization-overarching-plan.md)
- Feature method guide: [linux/localization-feature-method.md](../../linux/localization-feature-method.md)
