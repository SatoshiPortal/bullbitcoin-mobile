# Error Handling Patterns for Translations

> **Reference PR:** [#1538 - refactor(Recoverbull): better error handling pattern for translations](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/1538)
>
> **Last Updated:** 2025-11-20
>
> **Status:** NEW RECOMMENDED PATTERN (replaces BuildContext parameter pattern)

## Overview

This document describes the **improved error handling pattern** for translating error messages in features with custom error classes. This is the **new recommended approach** that eliminates the need to pass BuildContext through Bloc events.

## The Problem

Previously, features with custom error classes (`lib/features/<feature>/errors.dart`) required passing `BuildContext` through Bloc events to access localized error messages. This created several issues:

1. **Architectural violation**: Blocs shouldn't depend on UI layer (BuildContext)
2. **Complexity**: Needed optional context parameters on all events
3. **Error-prone**: Required defensive null-checking patterns
4. **Maintenance burden**: Context had to be propagated through event chains

## The Solution: `toTranslated()` Method Pattern

The new pattern **defers localization to display time** using an abstract method that accepts BuildContext when the error is shown to the user.

### Key Principles

1. **Separation of Concerns**: Error classes store error state, not translated messages
2. **Late Localization**: Translation happens at display time in UI layer
3. **Type Safety**: Abstract base class enforces translation contract
4. **Clean Blocs**: No BuildContext needed in business logic layer

---

## Pattern Comparison

### ❌ Old Pattern (BuildContext Parameter)

**Error Class:**
```dart
class KeyServerConnectionError extends RecoverBullError {
  KeyServerConnectionError(BuildContext context)
    : super(context.loc.recoverbullErrorConnectionFailed);
}
```

**Event Class:**
```dart
const factory RecoverBullEvent.onVaultSelection({
  required VaultProvider provider,
  BuildContext? context,  // ← Required for errors
}) = OnVaultSelection;
```

**Bloc Usage:**
```dart
try {
  await someOperation();
} catch (e) {
  if (event.context != null) {
    throw KeyServerConnectionError(event.context!);  // Defensive check
  } else {
    throw BullError('Fallback message');  // Generic fallback
  }
}
```

**UI Dispatch:**
```dart
context.read<RecoverBullBloc>().add(
  OnVaultSelection(
    provider: provider,
    context: context,  // ← Must pass context
  ),
);
```

**Drawbacks:**
- BuildContext in business logic layer ❌
- Optional context parameters everywhere ❌
- Defensive null-checking required ❌
- Context propagation through event chains ❌
- Generic fallbacks needed ❌

---

### ✅ New Pattern (toTranslated Method)

**Error Base Class:**
```dart
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

abstract class RecoverBullError {
  String toTranslated(BuildContext context);
}
```

**Error Implementation:**
```dart
class KeyServerConnectionError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorConnectionFailed;
  }
}
```

**Error with Parameters:**
```dart
class VaultRateLimitedError extends RecoverBullError {
  final Duration retryIn;

  VaultRateLimitedError({required this.retryIn});

  @override
  String toTranslated(BuildContext context) {
    final seconds = retryIn.inSeconds;
    final minutes = retryIn.inMinutes;

    final String formattedTime;
    if (seconds < 60) {
      formattedTime = context.loc.durationSeconds(seconds.toString());
    } else {
      formattedTime = minutes == 1
          ? context.loc.durationMinute(minutes.toString())
          : context.loc.durationMinutes(minutes.toString());
    }

    return context.loc.recoverbullErrorRateLimited(formattedTime);
  }
}
```

**Event Class (Simplified):**
```dart
const factory RecoverBullEvent.onVaultSelection({
  required VaultProvider provider,
  // ← NO BuildContext needed!
}) = OnVaultSelection;
```

**Bloc State:**
```dart
@freezed
class RecoverBullState with _$RecoverBullState {
  const factory RecoverBullState({
    // ...
    @Default(null) RecoverBullError? error,  // ← Custom error type
    // ...
  }) = _RecoverBullState;
}
```

**Bloc Usage (Clean):**
```dart
try {
  await someOperation();
} catch (e) {
  emit(state.copyWith(error: KeyServerConnectionError()));  // ✅ Simple!
}
```

**Bloc Error Mapping:**
```dart
try {
  final vaultKey = await _fetchVaultKeyUsecase.execute(
    vault: event.vault,
    password: event.password,
  );
  emit(state.copyWith(vaultKey: vaultKey));
} catch (e) {
  // Map core errors to feature errors
  switch (e) {
    case core.InvalidCredentialsError():
      emit(state.copyWith(error: InvalidVaultCredentials()));
    case core.RateLimitedError():
      emit(state.copyWith(error: VaultRateLimitedError(retryIn: e.retryIn)));
    case core.KeyServerErrorRejected():
      emit(state.copyWith(error: InvalidVaultCredentials()));
    case core.KeyServerErrorServiceUnavailable():
      emit(state.copyWith(error: VaultKeyFetchError()));
    default:
      emit(state.copyWith(error: UnexpectedError()));
  }
}
```

**UI Dispatch (Simplified):**
```dart
context.read<RecoverBullBloc>().add(
  const OnVaultSelection(provider: provider),  // ✅ No context!
);
```

**UI Display:**
```dart
BlocListener<RecoverBullBloc, RecoverBullState>(
  listenWhen: (previous, current) => current.error != null,
  listener: (context, state) {
    if (state.error != null) {
      // Translate at display time
      SnackBarUtils.showSnackBar(
        context,
        state.error!.toTranslated(context),  // ← Localize here
      );
      context.read<RecoverBullBloc>().add(const OnClearError());
    }
  },
  // ...
)
```

**Or in Widget:**
```dart
if (state.error != null)
  BBText(
    state.error!.toTranslated(context),  // ← Localize at display time
    style: context.font.bodyMedium?.copyWith(
      color: context.colour.error,
    ),
  ),
```

**Benefits:**
- No BuildContext in business logic ✅
- Clean event signatures ✅
- No null-checking needed ✅
- No context propagation ✅
- Type-safe error handling ✅
- Errors can store runtime data ✅

---

## Implementation Guide

### Step 1: Create Abstract Base Error Class

**File:** `lib/features/<feature>/errors.dart`

```dart
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

/// Base class for all <Feature> errors
abstract class <Feature>Error {
  /// Convert error to localized string
  String toTranslated(BuildContext context);
}
```

**Example:**
```dart
abstract class RecoverBullError {
  String toTranslated(BuildContext context);
}
```

### Step 2: Implement Error Classes

#### Simple Error (No Parameters)

```dart
class <ErrorName> extends <Feature>Error {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.<featureName>Error<ErrorType>;
  }
}
```

**Example:**
```dart
class VaultIsNotSetError extends RecoverBullError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullErrorVaultNotSet;
  }
}
```

#### Error with Parameters

```dart
class <ErrorName> extends <Feature>Error {
  final <Type> <fieldName>;

  <ErrorName>({required this.<fieldName>});

  @override
  String toTranslated(BuildContext context) {
    // Use field to build localized message
    return context.loc.<featureName>Error<ErrorType>(<fieldName>);
  }
}
```

**Example:**
```dart
class VaultRateLimitedError extends RecoverBullError {
  final Duration retryIn;

  VaultRateLimitedError({required this.retryIn});

  @override
  String toTranslated(BuildContext context) {
    final formattedTime = retryIn.inMinutes > 0
        ? context.loc.durationMinutes(retryIn.inMinutes.toString())
        : context.loc.durationSeconds(retryIn.inSeconds.toString());

    return context.loc.recoverbullErrorRateLimited(formattedTime);
  }
}
```

#### Generic Fallback Error

**Always include an "unexpected error" catch-all:**

```dart
class UnexpectedError extends <Feature>Error {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.<featureName>ErrorUnexpected;
  }
}
```

### Step 3: Update Bloc State

**File:** `lib/features/<feature>/presentation/state.dart`

```dart
@freezed
class <Feature>State with _$<Feature>State {
  const factory <Feature>State({
    // ...
    @Default(null) <Feature>Error? error,  // ← Use custom error type
    // ...
  }) = _<Feature>State;
}
```

**Example:**
```dart
@freezed
class RecoverBullState with _$RecoverBullState {
  const factory RecoverBullState({
    @Default(null) RecoverBullError? error,
    // ...
  }) = _RecoverBullState;
}
```

### Step 4: Update Bloc Error Handling

**File:** `lib/features/<feature>/presentation/bloc.dart` (or `cubit.dart`)

#### Simple Error Emission

```dart
try {
  // Business logic
  await someOperation();
} catch (e) {
  emit(state.copyWith(error: <ErrorClass>()));
}
```

#### Error Mapping Pattern

When catching errors from core/domain layer, map to feature errors:

```dart
try {
  final result = await usecase.execute();
  emit(state.copyWith(data: result));
} catch (e) {
  // Map domain/core errors to feature errors
  switch (e) {
    case core.SpecificError():
      emit(state.copyWith(error: FeatureSpecificError()));
    case core.ValidationError():
      emit(state.copyWith(error: FeatureValidationError(field: e.field)));
    case core.NetworkError():
      emit(state.copyWith(error: FeatureNetworkError()));
    default:
      emit(state.copyWith(error: UnexpectedError()));
  }
}
```

**Example from PR #1538:**
```dart
try {
  final vaultKey = await _fetchVaultKeyUsecase.execute(
    vault: event.vault,
    password: event.password,
  );
  emit(state.copyWith(vaultKey: vaultKey));
} catch (e) {
  switch (e) {
    case core.InvalidCredentialsError():
      emit(state.copyWith(error: InvalidVaultCredentials()));
    case core.RateLimitedError():
      emit(state.copyWith(error: VaultRateLimitedError(retryIn: e.retryIn)));
    case core.KeyServerErrorRejected():
      emit(state.copyWith(error: InvalidVaultCredentials()));
    case core.KeyServerErrorServiceUnavailable():
      emit(state.copyWith(error: VaultKeyFetchError()));
    default:
      emit(state.copyWith(error: UnexpectedError()));
  }
}
```

#### Validation Errors

For validation errors that don't throw, emit directly:

```dart
void validateAndSubmit() {
  if (state.vault == null) {
    emit(state.copyWith(error: VaultIsNotSetError()));
    return;
  }

  if (state.password == null) {
    emit(state.copyWith(error: PasswordIsNotSetError()));
    return;
  }

  // Proceed with valid state
  // ...
}
```

### Step 5: Add Error Clearing Event (Optional but Recommended)

**File:** `lib/features/<feature>/presentation/event.dart`

```dart
class OnClearError extends <Feature>Event {
  const OnClearError();
}
```

**File:** `lib/features/<feature>/presentation/bloc.dart`

```dart
class <Feature>Bloc extends Bloc<<Feature>Event, <Feature>State> {
  <Feature>Bloc() : super(<Feature>State.initial()) {
    // Register handlers
    on<OnClearError>(_onClearError);
    // ...
  }

  Future<void> _onClearError(
    OnClearError event,
    Emitter<<Feature>State> emit,
  ) async {
    emit(state.copyWith(error: null));
  }
}
```

### Step 6: Update UI Layer

#### BlocListener Pattern

```dart
BlocListener<<Feature>Bloc, <Feature>State>(
  listenWhen: (previous, current) => current.error != null,
  listener: (context, state) {
    if (state.error != null) {
      SnackBarUtils.showSnackBar(
        context,
        state.error!.toTranslated(context),  // ← Translate here
      );
      context.read<<Feature>Bloc>().add(const OnClearError());
    }
  },
  child: ...,
)
```

#### Inline Display Pattern

```dart
BlocBuilder<<Feature>Bloc, <Feature>State>(
  builder: (context, state) {
    return Column(
      children: [
        // ...
        if (state.error != null)
          BBText(
            state.error!.toTranslated(context),  // ← Translate at display
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
          ),
        // ...
      ],
    );
  },
)
```

#### Fallback Pattern (Defensive)

If error might be null in some branches, provide fallback:

```dart
Text(
  state.error?.toTranslated(context) ?? context.loc.genericErrorMessage,
)
```

---

## Core Layer Error Pattern

For errors thrown from core/domain layer that need to be caught by feature layer:

### Core Error Class

**File:** `lib/core/<module>/errors.dart`

```dart
import 'package:bb_mobile/core/errors/bull_exception.dart';

class <Module>Error extends BullException {
  <Module>Error(super.message);
}

class SpecificError extends <Module>Error {
  final SomeData data;  // ← Can store runtime data

  SpecificError({required this.data})
    : super('Generic English message for logging');
}
```

**Example from PR #1538:**
```dart
class RateLimitedError extends ServerError {
  final Duration retryIn;  // ← Runtime data

  RateLimitedError({required this.retryIn})
    : super(
        'Rate-limited. Retry in ${retryIn.inMinutes == 0 ? "${retryIn.inSeconds} seconds" : "${retryIn.inMinutes} minutes"}',
      );
}
```

### Feature Layer Mapping

Feature layer catches core errors and maps to feature errors with `toTranslated()`:

```dart
// Feature error that maps from core error
class FeatureRateLimitedError extends FeatureError {
  final Duration retryIn;  // ← Extract data from core error

  FeatureRateLimitedError({required this.retryIn});

  @override
  String toTranslated(BuildContext context) {
    // Use extracted data for localization
    return context.loc.featureErrorRateLimited(
      formatDuration(context, retryIn),
    );
  }
}

// In bloc:
try {
  await coreUsecase.execute();
} catch (e) {
  if (e is core.RateLimitedError) {
    emit(state.copyWith(
      error: FeatureRateLimitedError(retryIn: e.retryIn),  // ← Extract data
    ));
  }
}
```

---

## ARB Localization Keys

### Naming Convention

```
<featureName>Error<ErrorType>
```

**Examples:**
- `recoverbullErrorVaultNotSet`
- `recoverbullErrorConnectionFailed`
- `recoverbullErrorRateLimited`
- `recoverbullErrorUnexpected`
- `sendErrorInsufficientBalance`
- `receiveErrorAddressGeneration`

### ARB Entry Format

#### Simple Error (No Parameters)

```json
{
  "featureNameErrorType": "Human-readable error message",
  "@featureNameErrorType": {
    "description": "Error shown when [specific condition]"
  }
}
```

**Example:**
```json
{
  "recoverbullErrorVaultNotSet": "No vault selected. Please select a vault.",
  "@recoverbullErrorVaultNotSet": {
    "description": "Error shown when attempting operation without selecting a vault"
  }
}
```

#### Error with Placeholder

```json
{
  "featureNameErrorType": "Error message with {placeholder}",
  "@featureNameErrorType": {
    "description": "Error shown when [condition]",
    "placeholders": {
      "placeholder": {
        "type": "String"
      }
    }
  }
}
```

**Example:**
```json
{
  "recoverbullErrorRateLimited": "Too many attempts. Please retry in {duration}.",
  "@recoverbullErrorRateLimited": {
    "description": "Error shown when user is rate-limited",
    "placeholders": {
      "duration": {
        "type": "String",
        "example": "5 minutes"
      }
    }
  }
}
```

### Supporting Keys for Durations

For errors with time parameters, create reusable duration keys:

```json
{
  "durationSeconds": "{count} seconds",
  "@durationSeconds": {
    "description": "Duration format for seconds",
    "placeholders": {
      "count": {"type": "String"}
    }
  },
  "durationMinute": "{count} minute",
  "@durationMinute": {
    "description": "Duration format for single minute",
    "placeholders": {
      "count": {"type": "String"}
    }
  },
  "durationMinutes": "{count} minutes",
  "@durationMinutes": {
    "description": "Duration format for multiple minutes",
    "placeholders": {
      "count": {"type": "String"}
    }
  }
}
```

---

## Testing Checklist

When implementing this pattern, verify:

### Compilation
- [ ] `fvm flutter analyze` passes with no errors
- [ ] Build runner generates without issues: `make build-runner`
- [ ] All error classes implement `toTranslated()`

### Functionality
- [ ] Errors display correctly in English
- [ ] Errors display correctly in French
- [ ] Errors display correctly in Spanish
- [ ] Error parameters (if any) format correctly
- [ ] Error clearing works (state.error becomes null)

### Architecture
- [ ] No BuildContext in Bloc/Cubit layer
- [ ] No BuildContext in Event classes
- [ ] Error translation happens only in UI layer
- [ ] Errors can store runtime data as needed

### Edge Cases
- [ ] Null error states don't crash
- [ ] Multiple rapid errors handled correctly
- [ ] Error clearing after navigation works
- [ ] Errors with complex formatting (durations, plurals) work

---

## Migration Guide: Old Pattern → New Pattern

If you have features using the old BuildContext parameter pattern, migrate them:

### Step 1: Update Error Classes

**Before:**
```dart
class SomeError extends FeatureError {
  SomeError(BuildContext context) : super(context.loc.errorKey);
}
```

**After:**
```dart
class SomeError extends FeatureError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.errorKey;
  }
}
```

### Step 2: Remove BuildContext from Events

**Before:**
```dart
const factory FeatureEvent.onAction({
  required Data data,
  BuildContext? context,  // ← Remove
}) = OnAction;
```

**After:**
```dart
const factory FeatureEvent.onAction({
  required Data data,
  // ← No BuildContext
}) = OnAction;
```

Run build_runner after freezed changes:
```bash
make build-runner
```

### Step 3: Simplify Bloc Error Handling

**Before:**
```dart
try {
  await operation();
} catch (e) {
  if (event.context != null) {
    emit(state.copyWith(error: SomeError(event.context!)));
  } else {
    emit(state.copyWith(error: BullError('Fallback')));
  }
}
```

**After:**
```dart
try {
  await operation();
} catch (e) {
  emit(state.copyWith(error: SomeError()));
}
```

### Step 4: Update UI Event Dispatches

**Before:**
```dart
context.read<FeatureBloc>().add(
  OnAction(data: data, context: context),
);
```

**After:**
```dart
context.read<FeatureBloc>().add(
  const OnAction(data: data),
);
```

### Step 5: Update UI Error Display

**Before:**
```dart
if (state.error != null)
  Text(state.error!.message)  // ← String message
```

**After:**
```dart
if (state.error != null)
  Text(state.error!.toTranslated(context))  // ← Method call
```

### Step 6: Update Bloc State Type

**Before:**
```dart
@Default(null) BullError? error,
```

**After:**
```dart
@Default(null) FeatureError? error,
```

---

## When to Use This Pattern

### ✅ Use This Pattern When:

1. **Feature has custom error classes** (`lib/features/<feature>/errors.dart`)
2. **Errors need localization** (displayed to users)
3. **Errors contain runtime data** (amounts, durations, names)
4. **Multiple error types** need different messages
5. **Clean architecture** is important (no UI in business logic)

### ❌ Don't Use This Pattern When:

1. **Simple string errors** - Just emit `state.copyWith(errorMessage: 'text')`
2. **Errors never shown to users** - Use plain exceptions
3. **Single generic error** - Use a simple error string in state
4. **Errors from external libraries** - Catch and map to domain errors first

---

## Complete Example: Feature Error Handling

### File Structure
```
lib/features/my_feature/
├── errors.dart              # ← Error classes with toTranslated()
├── presentation/
│   ├── bloc.dart            # ← Emits custom error types
│   ├── event.dart           # ← NO BuildContext parameters
│   └── state.dart           # ← error field is MyFeatureError?
└── ui/
    └── screens/
        └── my_screen.dart   # ← Calls toTranslated(context)
```

### errors.dart
```dart
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

abstract class MyFeatureError {
  String toTranslated(BuildContext context);
}

class NetworkError extends MyFeatureError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.myFeatureErrorNetwork;
  }
}

class ValidationError extends MyFeatureError {
  final String fieldName;

  ValidationError({required this.fieldName});

  @override
  String toTranslated(BuildContext context) {
    return context.loc.myFeatureErrorValidation(fieldName);
  }
}

class UnexpectedError extends MyFeatureError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.myFeatureErrorUnexpected;
  }
}
```

### state.dart
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bb_mobile/features/my_feature/errors.dart';

part 'state.freezed.dart';

@freezed
class MyFeatureState with _$MyFeatureState {
  const factory MyFeatureState({
    @Default(false) bool loading,
    @Default(null) MyFeatureError? error,  // ← Custom error type
    @Default(null) String? data,
  }) = _MyFeatureState;
}
```

### bloc.dart
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/my_feature/errors.dart';
import 'package:bb_mobile/features/my_feature/presentation/event.dart';
import 'package:bb_mobile/features/my_feature/presentation/state.dart';

class MyFeatureBloc extends Bloc<MyFeatureEvent, MyFeatureState> {
  MyFeatureBloc() : super(const MyFeatureState()) {
    on<OnSubmit>(_onSubmit);
    on<OnClearError>(_onClearError);
  }

  Future<void> _onSubmit(
    OnSubmit event,
    Emitter<MyFeatureState> emit,
  ) async {
    if (event.value.isEmpty) {
      emit(state.copyWith(error: ValidationError(fieldName: 'value')));
      return;
    }

    try {
      emit(state.copyWith(loading: true, error: null));
      final result = await someUsecase.execute(event.value);
      emit(state.copyWith(loading: false, data: result));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e is NetworkException
            ? NetworkError()
            : UnexpectedError(),
      ));
    }
  }

  Future<void> _onClearError(
    OnClearError event,
    Emitter<MyFeatureState> emit,
  ) async {
    emit(state.copyWith(error: null));
  }
}
```

### my_screen.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<MyFeatureBloc, MyFeatureState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!.toTranslated(context)),  // ← HERE
            ),
          );
          context.read<MyFeatureBloc>().add(const OnClearError());
        }
      },
      child: BlocBuilder<MyFeatureBloc, MyFeatureState>(
        builder: (context, state) {
          return Scaffold(
            body: Column(
              children: [
                if (state.loading) CircularProgressIndicator(),
                if (state.error != null)
                  Text(
                    state.error!.toTranslated(context),  // ← OR HERE
                    style: TextStyle(color: Colors.red),
                  ),
                // ... rest of UI
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## Benefits Summary

| Aspect | Old Pattern (BuildContext param) | New Pattern (toTranslated) |
|--------|----------------------------------|----------------------------|
| **Architecture** | ❌ BuildContext in business logic | ✅ UI layer only |
| **Event Complexity** | ❌ Optional context everywhere | ✅ Clean event signatures |
| **Bloc Complexity** | ❌ Defensive null-checking | ✅ Simple error emission |
| **Type Safety** | ⚠️ Optional context can be missed | ✅ Compiler enforces translation |
| **Context Propagation** | ❌ Manual through event chains | ✅ Not needed |
| **Error Data** | ⚠️ Harder to store runtime data | ✅ Easy to include parameters |
| **Testing** | ❌ Must mock BuildContext | ✅ Test errors independently |
| **Maintainability** | ❌ Scattered context handling | ✅ Centralized in UI layer |

---

## Summary

The **`toTranslated()` method pattern** is the recommended approach for handling localized errors in features with custom error classes. It provides:

1. **Clean Architecture**: No UI dependencies in business logic
2. **Type Safety**: Compiler enforces translation contract
3. **Simplicity**: No context propagation needed
4. **Flexibility**: Errors can carry runtime data
5. **Testability**: Business logic tests don't need BuildContext

**Use this pattern for all new features and migrate existing features when refactoring.**

---

## References

- **Reference PR**: [#1538 - refactor(Recoverbull): better error handling pattern](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/1538)
- **Related Skill**: [bullbitcoin-localization/skill.md](./skill.md)
- **ARB Guidelines**: [CLAUDE.md - Localization Workflow](../../CLAUDE.md#localization-workflow)
