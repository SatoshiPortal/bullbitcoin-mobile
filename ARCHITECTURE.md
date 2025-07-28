# 🏗 Architecture

## 📁 Project structure

This project follows a **feature-based** and **layered architecture** to ensure **scalability**, **maintainability**, and **separation of concerns**.

The lib/ directory is organized into the following main sections:

- [Core](lib/_core/): Contains fundamental **UI-independent** components that are **used across multiple features**. It has its own set of layers and a dependency locator:
  - [Data](lib/_core/data/): Contains **data sources**, **models**, and concrete **repository and service implementations** that are shared across multiple features.
  - [Domain](lib/_core/domain/): Contains **entities**, abstract **repository and service contracts**, and **use cases** that are shared across multiple features.
  - [Presentation](lib/_core/presentation/): Contains **BLoCs** that are used in multiple features.
  - [Core Locator](lib/_core/): Manages **dependency injection setup** for the core layer.
- [UI](lib/_ui/): Contains **shared UI components**, like widgets, fonts, colors and themes that are used across multiple features.
- [Features](lib/): Each **feature** is self-contained and consists of its own set of **layers**, **locator**, and **routes**:
  - Data (lib/`<feature>`/data/): Contains **feature-specific** data sources, models, and repository and service implementations.
  - Domain (lib/`<feature>`/domain/): Contains **feature-specific** entities, repository and service contracts, and use cases.
  - Presentation (lib/`<feature>`/presentation/): Contains **feature-specific** BLoCs.
  - UI (lib/`<feature>`/ui/): Contains **feature-specific** UI components, screens, widgets, themes and routes.
  - Locator (lib/`<feature>`/): Defines **dependency injection** setup for the feature.
- [Localization](lib/_l10n/): Contains **localization files** with translations for different languages, re-generate the files using `flutter gen-l10n`.
- [Utils](lib/_utils/): Contains **small utility functions, extensions and constants** used throughout the app.
- App-Level Configuration in the root directory [lib/](lib/): Contains the main app entry point, configuration, and global utilities.
  - [App Bloc Observer](bloc_observer.dart) – Observes **global BLoC events** for debugging and logging.
  - [App Locator](locator.dart) – Configures **dependency injection** registration by calling the **core and feature locators**.
  - [App Router](router.dart) – Defines the **global app router and top-level navigation setup**.
  - [Main](main.dart) – Initializes and **launches the app** and sets up **global providers and lifecycle event handlers**.

## ✨ Clean Architecture

Clean Architecture is a software design philosophy that separates software into three layers: data, domain, and presentation.

Each layer has a specific responsibility and is built around the business domain. The separation of concerns and predictable data flow between the layers ensures that the data and presentation layers can be changed or replaced without affecting the core business logic.

This also enhances testability, maintainability, and scalability. While it may seem intimidating at first and introduce some boilerplate code, it pays off in the long run—especially in larger projects, more complex systems, and bigger teams.

### Domain Layer

The domain layer is the heart of the application. It consists of entities, repository and service interfaces/contracts and use cases that define the pure business logic of the application, making it independent of the data and presentation layers. This allows the business logic to be tested and reused without being tied to a specific data source or UI framework.

> [!TIP]
> You can think of the domain layer as the 'what' of the application. It defines what the application should permit the user to do, but not how it should be done or how it should be displayed. That's why repositories and services are not implemented here, but only defined as abstract classes.

#### Entities

Entities represent business data and rules, independent of any specific data source or UI. Entities should be unaware of how they are stored or retrieved.

_(If the domain data consists of native Dart types or simple value objects, you might not need an entity for it.)_

E.g. [`Wallet`](lib/_core/domain/entities/wallet.dart), [`UnlockAttempt`](lib/pin_code/domain/entities/unlock_attempt.dart).

#### Repository contracts

The interfaces (abstract classes) that define what is needed from the data layer to fulfill the business logic needs. Repositories in the [data layer](#data-layer) must implement these interfaces. They effectively decouple the domain layer from the data layer, making it possible to switch the data source or concrete repository implementation without changing the domain layer.

E.g. [`PinCodeRepository`](lib/pin_code/domain/repositories/pin_code_repository.dart), [`WalletManagerService`](lib/_core/domain/repositories/wallet_manager_repository.dart).

#### Service contracts

Services are helper classes that:

- Make logic that combines multiple repositories reusable.
- Separate and perform calculations, transformations, derivations or business rules not directly related to retrieving or storing data.
- Typically include `Manager`, `Factory` or `Calculator` or other -er/-or suffixes in their names.

Just as for the repositories, the domain layer defines service contracts as abstract classes that are implemented in the data layer.

E.g. [`WalletManagerService`](lib/_core/domain/services/wallet_manager_service.dart), [`MnemonicSeedFactory`](lib/_core/domain/services/mnemonic_seed_factory.dart), [`TimeoutCalculator`](lib/app_unlock/domain/services/timeout_calculator.dart).

#### Use cases

Use cases define **business operations** by orchestrating data flow from and to the entities by using the repository contracts and services. They essentially represent the actions that can be performed within the application.

E.g. [`CreateDefaultWalletsUsecase`](lib/app_startup/domain/usecases/create_default_wallets_usecase.dart), [`AttemptUnlockWithPinCodeUsecase`](lib/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart).

### Data Layer

The data layer is responsible for retrieving and storing data from and to different sources, like APIs, databases, or local storage. It consists of data sources, models, and concrete repository implementations.

> [!TIP]
> You can think of the data layer as the 'how' to achieve the 'what' defined in the domain layer.

#### Data sources

Classes responsible for the actual retrieving or storing of the data that directly interact with APIs, databases, or local storage sources.
They generally take in [models](#models) as parameters and return models as well.

E.g. [`ExchangeDatasource`](lib/_core/data/datasources/exchange_datasource.dart), [`Bip39WordListDatasource`](lib/_core/data/datasources/bip39_word_list_datasource.dart).

#### Models

Data structures as provided or expected by the data sources. They can be different from the entities in the domain layer, as they might have less or more fields or be structured differently. It is also possible that a repository has to use data from multiple models to compose an entity. If an entity can be derived directly from one model or vice versa, the model class can have `toEntity` and `fromEntity` methods to convert to and from entities.

E.g. [`SeedModel`](lib/_core/data/models/seed_model.dart) [`WalletMetadataModel`](lib/_core/data/models/wallet_metadata_model.dart).

#### Repository and service implementations

The concrete implementations of the repository and service contracts to retrieve data from the data sources and map the models to entities defined in the domain.
Repositories convert models to entities and vice versa, while services use entities only, as they are not directly related to data retrieval or storage.

E.g. [`WalletManagerServiceImpl`](lib/_core/data/repositories/wallet_manager_repository_impl.dart), [`SettingsRepositoryImpl`](lib/_core/data/repositories/settings_repository_impl.dart).

### Presentation Layer

The presentation layer is responsible for managing the state for the user interface to listen to and be rendered correctly. It does this by storing the current state and updating it by invoking use cases based on user interactions or other events.

In this project, BLoCs/Cubits are used for state management, but other solutions like ViewModels, Providers, or Riverpod could also be used.

> [!TIP]
> You can think of the data layer as the 'how' to present the 'what' defined in the domain layer.

### Rules of Thumb

> [!TIP]
> Use these rules of thumb to validate your code and ensure Clean Architecture principles are followed.

✅ Layer dependencies:

- The **domain layer** should be **completely independent** of the **data or presentation layer**. It should not import any classes from the data or presentation layer.
- The **data layer** should **only depend on the domain layer**, never on the presentation layer. From the domain layer it should only import the repository and service contract abstract classes and entity classes, it should never import anything from the presentation layer.
- The **presentation layer** should **only depend on the domain layer**, never on the data layer. From the domain layer it should only import the use cases and entities, it should never import anything from the data layer directly.

✅ Dependency Injection flow:

**Dependency injection** flow should be **unidirectional** from the **data layer to the domain layer to the presentation layer** as follows:

1. **Data Sources** → Injected into **Repository Implementations** only, not used directly in use cases or anywhere else.
2. **Repositories** → Injected into **Use Cases or Services** only, not used directly in the presentation layer or anywhere else.
   _(Services themselves may also be injected into use cases just like repositories.)_
3. **Use Cases** → Injected into **Blocs/Cubits** or used in the presentation layer only, not in other layers.

✅ Entity vs Model:

- The **domain and presentation layer should use entities**, not models.
- Only the **data layer should use models**, and transform them to entities.

### Further reading

You can read more about Clean Architecture principles applied to Flutter in the following articles:

- https://medium.com/@yamen.abd98/clean-architecture-in-flutter-mvvm-bloc-dio-79b1615530e1
- https://medium.com/@semihaltin99/flutter-clean-architecture-8759ad0213dd