# core – Shared Infrastructure, Primitives & UI

## Purpose

The `core` folder contains **only**:

- **Shared infrastructure** (frameworks & drivers)
- **Shared, pure primitives** (canonical application & Bitcoin language)
- **Shared UI & theming** (design system and generic widgets)

**Warning:** Nothing should live in `core` unless it is _truly shared_ across multiple features.

This rule exists to prevent `core` from turning into a dumping ground and to avoid the old **“God-core folder”** problem.

- If something is used by **only one feature**, it **must live inside that feature**.
- Don’t move something to `core` just because it’s used in two places.
  - First ask:
    - Do both features really need to share the same implementation?
    - Could one feature _own_ it, and the other interact via a well-defined interface?
    - Do these two features actually represent a single feature that should be modeled together if they share a lot of domain logic?

Only when something is **conceptually shared** and **technically reused** across the app should it graduate into `core`.

This keeps:

- Features cohesive
- Core minimal
- Technical coupling low
- Long-term refactors safe

---

## core/primitives

### Purpose

This folder contains the **canonical, shared, framework-agnostic ubiquitous language primitives** used across multiple features.

---

### What belongs here

- Enums
- Small immutable value objects with **simple validation rules**
- Money / amount representations
- Strongly typed identifiers

Examples:

- `Network` → bitcoin, liquid, lightning, ark, cashu
- `NetworkEnvironment` → mainnet, testnet3, testnet4, signet
- `BtcAmount`, `FiatAmount`

All of these:

- Are **pure Dart**
- Have **no Flutter / Drift / HTTP / platform imports**
- Are **safe to reuse** in any feature
- Can later be extracted into a **standalone Dart package** for use in for example the exchange SDK or other projects

---

### What does NOT belong here

- Framework or platform code
- Database models or Drift types
- API DTOs
- Flutter widgets
- Repository implementations
- Data mappers
- Data sources
- Use cases
- Service classes
- Feature-specific domain models

**Warning:** If a value object or enum is only used in a single feature, it **must stay in that feature's domain**.

---

## core/infra

### Purpose

This folder contains **shared technical infrastructure**:  
frameworks & drivers used by **multiple features**.

This is the **lowest technical layer** of the app.

---

### What belongs here

Only infrastructure that is:

- Used by **multiple features**
- Low-level
- Free of business meaning

Examples:

- Drift `AppDatabase`
- HTTP clients
- Secure storage
- Logging

---

### What must NOT go here

These must stay in their respective features:

- Feature-specific API clients
- Feature-specific storage library clients (for example shared preferences for settings)

---

## core/ui – Shared UI Kit & Theming

Contains the **shared design system and generic reusable widgets**.

This is the **app-wide visual and interaction language**.

---

### Examples

- `AppTheme`, `BrandColor`, `TextStyles`, `Spacing`
- `EmailTextFormField`, `PrimaryButton`, `InfoCard`
- `FadingLinearProgressIndicator`
- Reusable input validation and formatting rules

---

### Rules

- Used across **multiple features**
- Generic and **app-wide**
- May depend on Flutter and `core/primitives`
- No feature-specific UI
- No domain wording tied to a single feature
- No business logic

If a widget is specific to one feature (even if reused inside that feature), it **must live in that feature’s presentation layer**.

## Golden Rule

> If it is **not shared across at least two features**, it **does not belong in `core`**.
