# 🏗 Architecture

This project follows a **feature-based** and **layered architecture** to ensure **separation of concerns**, **scalability** and **maintainability**.

## 📦 Feature-Based Architecture

Features are self-contained modules that encapsulate all code related to a specific functionality, domain, or resource of the application.

A feature is the single owner of its domain, meaning it is solely responsible for enforcing all business rules and domain logic related to that domain. No other feature may directly access or modify a feature’s internal domain models, state, or persistence details.

When other features need to interact with a domain, the feature should expose a well-defined public API (facade) that serves as the only entry point for cross-feature interaction. This facade defines the feature’s stable contract and ensures that business rules cannot be bypassed. And as long as the facade remains unchanged, the feature’s internal implementation can evolve freely without impacting dependent features.

This approach enables clear ownership, strong encapsulation, and independent development and testing of features. It also helps in maintaining a well-defined, acyclic dependency graph between features, preventing circular dependencies as visualized in the [Features Dependency Diagram](FEATURES.md).

## 🎯 Layered Architecture

The layers that can be encountered in the architecture are highly inspired by [**Clean Architecture**](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) and [**Hexagonal Architecture (Ports and Adapters)**](https://alistair.cockburn.us/hexagonal-architecture) principles.
They overlap and complement each other well, as Clean Architecture focuses on separation of concerns and dependency rules between layers, while Hexagonal Architecture emphasizes isolating the application’s business logic from external systems through well-defined ports and adapters.

We use the `Entities` and `Use Cases` concepts from Clean Architecture which together form the `Application` boundary in Hexagonal Architecture. They represent the pure business logic of the application and include domain models, business rules, and the orchestration of operations to achieve specific business goals.

From Hexagonal Architecture we use the concept of `Ports` (interfaces defined by the Application) and `Adapters` (concrete implementations) to isolate the Application from external systems such as databases, APIs, or UI frameworks.

More specifically, we consider `BLoC/Cubits`, feature `Facades`, and event watchers to be **Primary (Driving) Adapters**, as they drive the application by invoking `Use Cases` through inbound `Ports`.

Persistence implementations (e.g. repository or store implementations), external API clients, or other concrete infrastructure concerns are considered **Secondary (Driven) Adapters**, as they are invoked by the `Application` through outbound ports to perform operations on external systems (e.g. databases or APIs) or with concrete implementations (either with or without external dependencies). `Ports` define the needs of the `Application`, while Adapters fulfill those needs. What and how are thus clearly separated and the how is easily replaceable without affecting the business logic.

A simple example with one persistence outbound port looks like this:

               UI Adapter (Controller / BLoC)
                     |
             Inbound Port (Use Case)
                     |
               the Application
                     |
            Outbound Port (Repository)
                     |
         DB Adapter (Drift / SQL implementation)
                     |
                  Database

The adapters in Hexagonal Architecture map to the `Interface Adapters` and `Frameworks & Drivers` layers in Clean Architecture.

## 🗂️ Concrete Structure

Now how does all of the above concepts map to the actual structure and terminology used in this codebase?

Each feature folder (e.g. `/secrets`, `/labels`, `/settings`, `/wallets`) represents a self-contained feature module with the following structure:

- `domain/` contains domain models & business rules (Entities, Value Objects).
- `application/` contains use cases, ports and optionally services for code repeated in different use cases (orchestration, workflows).

> [!NOTE]
> Together, `domain/ + application/` form what many texts call the "inside" of Clean/Hex (i.e., the business logic isolated from frameworks).

- `adapters/` contains secondary/driven adapters (e.g., repository implementations).
- `frameworks/` contains external dependencies and infrastructure code (e.g., datasources, API clients, drivers) generally used by the secondary adapters if it makes sense to keep them separate for better organization, reusability or further abstraction if needed.
- `presentation/` contains the primary (driving) UI adapters namely BLoCs/Cubits and View Models if any.
- `ui/` contains UI widgets and screens that compose the visual parts of the feature. They depend on the BLoCs/Cubits from the `presentation/` layer to get their state and invoke actions.
- `public/` contains the Facade/API of the feature for cross-feature interaction.
- `watchers/` optionally contains event watchers or listeners that listen to events or data streams from external systems and invoke use cases accordingly.

Something to note is that all secondary adapters are grouped together in the `adapters/` folder, while the primary adapters have their own dedicated folder, like `presentation/`, `public/` and `watchers/`. This is mostly just for clarity, organization and ease of navigation.

In the end, these folders can be mapped to the layers of Clean/Hexagonal Architecture and their interactions can be visualized like this:

```mermaid
graph TD
    UI[UI] --> PL[Presentation]
    OF[Other Features] --> PF[Public]
    PL --> AL
    PF --> AL
    W[Watchers] --> AL

    subgraph AL[Application]
        UC[Use Cases]
        P[Ports]
        UC --> P
    end

    AL --> D[Domain]
    IA[Interface Adapters] -.implements.-> P
    IA --> FD[Frameworks]
```

As can be seen, the `Dependency Rule` and `Ports and Adapters` concepts are followed strictly.

### Special Note on Core Module

`/lib/core` is a shared technical module of low level primitives/drivers/helpers, not the “core” business logic. Core should be completely independent of any business/feature specific logic.

### Error handling

Each layer and feature should handle errors appropriately according to its responsibility. It should define its own error types and only propagate its own errors to other layers or features that depend on it. This also means every layer should make sure it catches and maps all errors from other layers it depends on to its own error types before propagating them further.

A simple convention to follow is to just create an error file per layer:

- `domain/` → `domain_errors.dart`
- `application/` → `application_errors.dart`
- `presentation/` → `presentation_errors.dart`

The feature name is already implied by the path (`lib/features/<feature>/<layer>/`), so the filename stays short.

You can add a sealed class with different error types or exceptions as needed. As well as mappers from errors from the used layers to the layer's error types. This way each layer has its own clearly defined error types and can handle errors appropriately without leaking implementation details or error types from other layers.

## 🔺 Common Architectural Pitfalls

While the architecture described above represents our current standards, the codebase contains legacy code that predates these principles. We're actively refactoring to align with these standards. When working in the codebase, watch out for—and avoid replicating—these common anti-patterns:

**Breaking Feature Boundaries**

- **Problem**: Features directly import usecases, domain models, repositories, or services from other features
- **Impact**: Creates tight coupling, bypasses business rules, and leads to circular dependencies
- **Solution**: Always define and use a public facade for cross-feature communication

**Business Logic in Presentation Layer**

- **Problem**: BLoCs/Cubits contain orchestration logic, decision-making, or complex transformations that belong in use cases
- **Impact**: Makes business logic untestable in isolation, duplicates logic across features, and indicates poorly defined or too coarse-grained use cases
- **Root Cause**: Often happens when directly using other features' use cases instead of creating feature-specific orchestration
- **Solution**: Keep BLoCs thin—they should only transform between UI state and use case calls

**Bypassing the Application Layer**

- **Problem**: Watchers or other primary adapters directly invoke repositories, creating flows like `watcher ↔ repository ↔ datasource`
- **Impact**: Mixes primary and secondary adapter responsibilities, bypassing business rules
- **Example**: Payjoin and swap datasources managing event streams with watchers listening directly
- **Solution**: Watchers should invoke use cases, which then use repositories: `watcher → use case → repository`

**Core Module Bloat**

- **Problem**: Feature-specific business logic placed in `/core`
- **Impact**: Creates implicit coupling and makes core non-reusable across projects
- **Solution**: Keep core limited to generic primitives, low level drivers, and infrastructure helpers with no business logic

**Anemic Domain Models**

- **Problem**: Entities defined as simple data containers (DTOs) that mirror database schemas without encapsulating business rules
- **Impact**: Business logic scatters into services/use cases instead of living in the domain where it belongs
- **Solution**: Entities should encapsulate business rules and be independent of persistence concerns

**Over-Abstraction in Adapters**

- **Problem**: Unnecessary layers (e.g., both repository AND datasource for simple CRUD operations)
- **Impact**: Adds complexity and indirection without meaningful benefit
- **Solution**: Use a single repository if there's no meaningful transformation or clear logic to separate

**State Management Confusion**

- **Problem**: Mixing ephemeral widget state with BLoC state
- **Impact**: Makes state management unpredictable and harder to test
- **Solution**: Use local widget state (StatefulWidget) for UI-only concerns; use BLoC only for business state

## 📦 Monorepo Migration (melos workspace)

The codebase is migrating, incrementally, from a single Flutter package to a [melos](https://melos.invertase.dev/) pub-workspace. This is an organizational change layered on top of the architecture above — it does not alter the feature-based / layered rules, it gives them a stronger, compile-time boundary.

**Current state (skeleton).** The app remains a single package at the repo root, declared as the workspace package via `useRootAsPackage: true` in the `melos:` block of `pubspec.yaml`. No code has moved yet. `packages/` and `features/` exist as reserved, empty homes.

**Target layout.** As modules are extracted (one at a time, never a big-bang), they become pub-workspace members:

- **root = the app shell** — thin: routing, DI/get_it wiring, and composition of feature packages. It ships no domain or UI of its own beyond that wiring.
- **`features/`** — Flutter packages, one per user-facing flow (`send`, `receive`, `buy`, `sell`, `recoverbull`, …). Each owns its domain behind its `public/` facade and is mounted into the shell (routes + DI). A feature may carry an `example/` mini-app to run it in isolation during development; the shipped artifact is the shell embedding the feature, not a standalone app.
- **`packages/`** — pure-Dart packages with no Flutter UI: the shared foundation consumed by features. This is both shared domain (`wallet`, `secrets`) and infrastructure (`storage`, `electrum`, `blockchain`, …). The lone exception is a package that must own a sealed UI component (see "Sealed UI" below), which may depend on Flutter.

Each extracted package gets `resolution: workspace` and is listed under a `workspace:` key in the root `pubspec.yaml`; the root app keeps `useRootAsPackage: true` and consumes the members. Dependencies point one way and stay acyclic: **shell → features → packages**. `packages/` never import `features/`; a feature touches a package only through its published API.

**Why it matters for architecture.** Package boundaries turn the existing rules into *enforced* ones rather than conventions:

- The **Dependency Rule** and **acyclic feature graph** become compile errors when violated — a `packages/` infrastructure package physically cannot import a `features/` module, and a feature cannot reach into another feature's internals (only its published API is importable).
- **Core-as-infrastructure-only** (rule #7) is enforced by construction: `packages/` members declare no dependency on `features/`.
- The **facade-only cross-feature** rule (rule #1) is backed by Dart's package privacy — only what a feature package exports is reachable.

**Encapsulation is enforced, not conventional.** Each package exposes a curated public API in `lib/<name>.dart` (`export 'src/…' show …`); everything under `lib/src/` is package-internal. Importing another package's `src/` trips the `implementation_imports` lint, which CI (`flutter analyze --fatal-infos`) and the pre-commit hook turn into a failure — and CI forbids bypassing it with `// ignore`. The most sensitive internals stay library-private (`_`) so they are not in any importable library at all.

**Sealed UI as a security tool.** A package can expose a *widget* that uses a secret internally without ever exposing the secret value. The mnemonic-display case is the canonical example: `secrets` exports a `MnemonicView` widget but no function that returns the words. The mnemonic lives only in `lib/src/`, is read inside the widget's `build`, and never crosses the package boundary — so a feature developer can show the user their words but cannot obtain them programmatically. Because Dart has no cross-package "friend" visibility, the widget must live in the same package that holds the seed, which is why `secrets` is the one package allowed to depend on Flutter. This seal stops programmatic/API leakage only — not OS-level capture; pair it with screenshot blocking (`no_screenshot`), exclusion from the accessibility/semantics tree, and treating the revealed value as ephemeral.

This is a slow, deliberate migration. Until a module is extracted, it stays in `lib/` and follows the same rules it does today. Do not move code into `packages/`/`features/` opportunistically — extraction is its own scoped, reviewed change with the security/bitcoin/build implications considered per module.

## 🤖 Rules for AI

See [AGENTS.md](AGENTS.md) — architecture enforcement, theme-only colors, refuse-and-suggest on rule breaks, and unit-test requirements for use cases and entities are documented there alongside the rest of the agent contract.
