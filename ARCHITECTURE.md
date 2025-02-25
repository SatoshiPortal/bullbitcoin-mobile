# 🏗 Architecture

## 📁 Project structure

This project follows a feature-based and layered architecture to ensure scalability, maintainability, and separation of concerns.

The lib/ directory is organized into the following main sections:

- [Core](lib/core/): Contains fundamental ui-independendent components that are used across multiple features and consists of its own set of layers and locator:
  - [Data](lib/core/data/): Contains data sources, models, and repository implementations that are shared across multiple features.
  - [Domain](lib/core/domain/): Contains entities, repository contracts, services, and use cases that are shared across multiple features.
  - [Presentation](lib/core/presentation/): Contains shared blocs and view models that are used across multiple features.
  - [Core Locator](lib/core/): Contains the locator (dependency injection) setup for the core layer.
- [UI](lib/ui/): Contains shared UI components, widgets, and themes that are used across multiple features.
- [Features](lib/features/): Each feature is self-contained and consists of its own set of layers, locator, and routes:
  - Data (lib/features/`<feature>`/data/): Contains data sources, models, and repository implementations specific to the feature.
  - Domain (lib/features/`<feature>`/domain/): Contains entities, repository contracts, services, and use cases specific to the feature.
  - Presentation (lib/features/`<feature>`/presentation/): Contains blocs, view models, and other ui-independendent components specific to the feature.
  - UI (lib/features/`<feature>`/ui/): Contains the UI components, screens, widgets, themes and routes specific to the feature.
  - Locator (lib/features/`<feature>`/): Contains the locator (dependency injection) setup for the feature.
- [Localization](lib/l10n/): Contains localization files with translations for different languages.
- [Utils](lib/utils/): Contains small utility functions and extensions used throughout the app.
- App-Level Configuration in the root directory [lib/](lib/): Contains the main app entry point, configuration, and global utilities.
  - [App Bloc Observer](app_bloc_observer.dart) – Observes global Bloc events for debugging and logging.
  - [App Locator](app_locator.dart) – Configures dependency injection registration by calling the core and feature locators.
  - [App Router](app_router.dart) – Defines the app router and top-level routes for navigation.
  - [App Theme](app_theme.dart) – Contains the app-wide theme configuration.
  - [App](app.dart) – The main app entry point, setting up app-wide providers and lifecycle events.
  - [Main](main.dart) – The main function that initializes and runs the app.

## ✨ Clean Architecture

Clean Architecture is a software design philosophy that separates software into three layers: data, domain, and presentation. Each layer has a specific responsibility and is built around the business domain. The separation of concerns and predictable data flow between the layers ensures that the data and presentation layers can be changed or replaced without affecting the core business logic. This also enhances testability, maintainability, and scalability. While it may seem intimidating at first and introduce some boilerplate code, it pays off in the long run—especially in larger projects, more complex systems, and bigger teams.

### Domain Layer

The domain layer is the most crucial layer and heart of the application. It consists of entities, repository interfaces/contracts, services and use cases that define the pure business logic of the application. It is accessible to both the Data Layers and the Presentation Layer, but it should not depend on them. The domain layer should be independent of the data layer and the presentation layer, so that the business logic can be tested and reused without being tied to a specific data source or UI framework.

#### Entities

The classes that represent business data and rules, independent of any specific data source or presentation. Entities should be unaware of how they are stored or retrieved.

If the domain data consists of native Dart types or simple value objects, you might not need an entity for it.

E.g. [`WalletMetadata`](lib/features/wallet/domain/entities/wallet_metadata.dart), [`UnlockAttempt`](lib/features/pin_code/domain/entities/unlock_attempt.dart).

#### Repository interfaces or contracts

The interfaces (abstract classes) that define the methods the business logic needs to retrieve and/or store entity data. Repositories in the [data layer](#data-layer) have to implement these interfaces. They effectively decouple the domain layer from the data layer, making it possible to switch the data source or concrete repository implementation without changing the domain layer.

E.g. [`PinCodeRepository`](lib/features/pin_code/domain/repositories/pin_code_repository.dart), [`WalletRepository`](lib/features/wallet/domain/repositories/wallet_repository.dart).

#### Services

Services can be created to make some logic that combines different repositories reusable, as well as for logic that is not directly related to retrieving or storing data, but more about generating, deriving or calculating themselves. They generally have things like `Manager`, `Factory` or `Calculator` in their class name.

E.g. [`WalletRepositoryManager`](lib/core/domain/services/wallet_repository_manager.dart), [`WalletMetadataDerivator`](lib/core/domain/services/wallet_metadata_derivation_service.dart), [`MnemonicSeedFactory`](lib/core/domain/services/mnemonic_seed_factory.dart), [`TimeoutCalculator`](lib/features/pin_code/domain/services/timeout_calculator.dart).

#### Use cases

They contain business logic and are responsible for orchestrating data flow from and to the entities by using the repository contracts and services. They essentially represent the actions that can be performed within the application.

E.g. [`CreateDefaultWalletsUseCase`](lib/features/onboarding/domain/usecases/create_default_wallets_usecase.dart), [`AttemptUnlockWithPinCodeUseCase`](lib/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart).

### Data Layer

The data layer is responsible for retrieving and storing data from and to different sources, like APIs, databases, or local storage. It consists of data sources, models, and repository implementations.

#### Data sources

Classes responsible for the actual retrieving or storing of the data, like APIs, databases, or local storage.

E.g. [`ExchangeDataSource`](lib/core/data/datasources/exchange_data_source.dart), [`Bip39WordListDataSource`](lib/features/recover_wallet/data/datasources/bip39_word_list_data_source.dart).

#### Models

Data structures as provided or expected by the data sources. They can be different from the entities in the domain layer, as they might have less or more fields or be structured differently. The model classes can have `toEntity` and `fromEntity` methods to convert to and from entities if an entity can be derived from the model directly or vice versa.

E.g. [`SeedModel`](lib/core/data/models/seed_model.dart) [`WalletMetadataModel`](lib/core/data/models/wallet_metadata_model.dart).

#### Repository implementations

The concrete implementations of the repository contracts to retrieve data from the data sources and map the models to entities defined in the domain.

E.g. [`WalletMetadataRepositoryImpl`](lib/core/data/repositories/hive_wallet_metadata_repository_impl.dart).

### Presentation Layer

The presentation layer is responsible for managing the state for the user interface to listen to and be rendered correctly. It does this by storing the current state and updating it by invoking use cases based on user interactions or other events. In our app this consists of blocs/cubits, other apps might use view models or providers or other state management solutions.

### Rules of thumb

> 💡 **Tip:** These rules of thumb help resolve doubts, validate code, and ensure the architecture is on the right track. 👍

- The domain layer should be completely independent of the data and presentation layer. It should not import any classes from the data or presentation layer.
- The data layer should only import the repository contract abstract classes and entity classes from the domain layer, it should never import anything from the presentation layer.
- The presentation layer should only import the use cases and entities from the domain layer, it should never import anything from the data layer directly.
- Dependency injection flow should be unidirectional: datasources -> repositories -> use cases -> blocs/cubits
  - Data sources are injected into repository implementations and not used directly in the use cases or anywhere else.
  - Repositories are injected into use cases and not used directly in the presentation layer or anywhere else.
  - Use cases are injected into blocs/cubits or used in the presentation layer and nowhere else.
- The only classes that should use models are the data layer classes. The domain layer should only use entities as data classes, not models.

### Further reading

You can read more about Clean Architecture principles applied to Flutter in the following articles:

- https://medium.com/@yamen.abd98/clean-architecture-in-flutter-mvvm-bloc-dio-79b1615530e1
- https://medium.com/@semihaltin99/flutter-clean-architecture-8759ad0213dd
