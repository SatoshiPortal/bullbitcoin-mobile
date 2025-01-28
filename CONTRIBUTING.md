# Contributing

## Git Workflow

TODO: Describe the branch structure, forking to a personal repository, pull request, etc.

## Adding a new feature

### Step 1: Define the different layers of the feature

Before starting to implement a new feature, it is important to define what and how to implement it. Since the project follows the [Clean Architecture](#appendix-a-clean-architecture) principles, you should think about the different layers the feature need: data, domain, and presentation layer. To help you with this, you can try to answer the following questions first:

- What data does my feature need for its business logic to work?
- Where does all data come from or where does it have to be stored or send to?
- What should the feature do with the data? What actions can be performed with it?

With answers to these questions, dividing the feature into the different layers should be easier.

The first question helps you identify the entities and repository contracts needed in the domain layer. The second question helps you identify the data sources and repository implementations needed in the data layer. The third question helps you identify the use cases needed in the domain layer and the blocs needed in the presentation layer.

With that in mind, create a comment on the issue of the feature you want to implement, describing the different layers of the feature. This will help you to get feedback on your approach and to make sure you are on the right track. Here is an example for the [Pin code feature](/lib/features/pin_code):

```markdown
- domain
  - entities: UnlockAttempt
  - repository contracts: PinCodeRepository
  - services: TimeoutCalculator (to calculate the timeout to insert a pin based on failed unlock attempts)
  - use cases: AttemptUnlockWithPinCodeUseCase, CheckPinCodeExistsUseCase, GetLatestUnlockAttemptUseCase, SetPinCodeUseCase
- data
  - models: No models are needed since the pin code is just a simple string and the only other data that needs to be stored is the number of failed unlock attempts, which can be stored as a simple integer. Both can be stored individually in the secure storage. If better to store them together, under a single key, a model could be created for that though, but the pin itself shouldn't always be retrieved when the failed attempts are needed, so it might be better to store them separately.
  - data sources: KeyValueStorageDataSource with SecureKeyValueStorageDataSourceImpl (already implemented in the core folder)
  - repository implementations: PinCodeRepositoryImpl
- presentation
  - blocs (used two blocs since the setting and unlocking of the pin code are things done in different parts of the app and with different purposes)
    - PinCodeSettingBloc
      - state: One state class with a status field and following fields
      - events:
    - PinCodeUnlockBloc
      - state: One state class with a status field and following fields
      - events:
  - The screens and widgets shouldn't be described, since they are defined by the UI design already.
```

Not every feature will need all these layers. But it would be good to still think about them and explain why they are not needed for the feature you want to contribute. For example, if a data source just returns a simple value, you might not need a model for it. Or if a feature is just one screen, you might not even need a bloc for it. Also a Cubit might be good instead of a Bloc and so the event file might not be necessary. Software development is not an exact science, the idea of this step is to

Also, don't worry if you are not sure about all the layers yet, or if you need to change them later as really implementing the feature might give other insights. This is just a starting point to help you get a better understanding of the feature and get quick feedback on your approach. So please comment on the issue of the feature you want to implement with your thoughts on the different layers of the feature before starting to implement it.

### Step 2: Implement the feature

- Add a new folder for the feature
- In case your feature requires some initialization at startup of the app, please create a use case for it and execute it in the `AppStartupBloc`'s `_onStarted` method.
- If a direct mapping from model to domain entity is possible, a `toEntity` and `fromEntity` can be added to the models.
- Entities should be unaware of how the data is stored/retrieved/derived or displayed exactly, making them usable in all layers.
- Use `GetIt` to register datasources, repositories, services, usecases and blocs. Generally, datasources, repositories and services should be registered as singletons, usecases and blocs as factory. You can create a file and function in the feature folder to register all di of the feature easily. E.g. [pin_code/locator/di_setup.dart](/lib/features/pin_code/locator/di_setup.dart).
- Describe the flow of injecting dependencies: datasources -> repository implementations -> use cases -> blocs, no other dependencies should be injected into those classes except for the one before them.

### Step 3: Write tests

Tests are an essential part of the development process. They help to ensure that the code works as expected and no existing or future code is accidentally broken. They also make it easier for reviewers to know if the code complies with the requirements and if all edge cases are covered. In this regard, tests might even be the best documentation for other code contributors. So the effort of writing tests, might save the need for extensive documentation and time-consuming regression testing. That's why we encourage you to write tests for your code to get it merged faster.

#### Unit tests

Make sure all code of the data and domain layers of the feature is covered by unit tests.
Considering the code is structured

#### Widget tests

Make sure the presentation layer is covered by widget tests.
As long as the BloC of the feature is limited to using use cases and updating the state, the widget tests should be enough to cover the presentation layer.
Since the use cases will already be tested by the unit tests, and the state changes will be tested by the widget tests.

#### Integration tests (optional)

Integration tests might be necessary if the feature requires interaction with external datasources and we want to make sure there is no compatibility issue between the models and calls made by the code and the actual API of the service.

## Appendix A: Clean Architecture

The Clean Architecture is a software design philosophy that separates the software into three layers: data, domain and presentation layer. Each layer has a specific responsibility and should be independent of the other layers. This separation allows for easier testing, maintenance, and scalability of the software.

- domain
  - entities: The classes that represent pure business data independent of any specific data source or presentation. E.g. [`WalletMetadata`](lib/features/wallet/domain/entities/wallet_metadata.dart), [UnlockAttempt](lib/features/pin_code/domain/entities/unlock_attempt.dart). If the domain data consists of native Dart types or simple value objects, you might not need an entity for it.
  - repository contracts: The interfaces (abstract classes) that define the methods the feature needs to retrieve, receive, store or send data. E.g. [PinCodeRepository](lib/features/pin_code/domain/repositories/pin_code_repository.dart), [`WalletRepository`](lib/features/wallet/domain/repositories/wallet_repository.dart). They decouple the domain layer from the data layer, making it possible to switch the data source without changing the domain layer.
  - services: If the feature requires some logic that is not directly related to obtaining or sending data, but is still part of the domain and should be reusable across different use cases, you can create a service for it. E.g. [`TimeoutCalculator`](lib/features/pin_code/domain/services/timeout_calculator.dart) for pin input attempts.
  - use cases: The classes that contain the business logic of the feature. They are responsible for orchestrating data flow between the data layer and the presentation layer, using the repository contracts and services. They essentially represent the actions that can be performed with the feature. E.g. [`UnlockWallet`](lib/features/pin_code/domain/usecases/attempt_unlock_with_pin_code_usecase.dart).
- data
  - data sources: Classes responsible for retrieving or storing data, like APIs, databases, or local storage. E.g. [`Bip39WordListDataSource`](lib/features/recover_wallet/data/datasources/bip39_word_list_data_source.dart). Common data sources like Flutter Secure Storage, Hive, Exchange API's and others are already placed in the [`lib/core/datasources`](lib/core/data/datasources/) folder. You don't need to create a new data source for these.
  - models: Data structures as returned or received by the data sources, that are needed to derive the domain entities data from. E.g. API responses or models such as [`WalletMetadataModel`](lib/features/wallet/data/models/wallet_metadata_model.dart).
  - repository implementations: The classes that implement the repository contracts to retrieve data from the data sources and map the models to entities defined in the domain. E.g. [`WalletRepositoryImpl`](lib/features/wallet/data/repositories/wallet_repository_impl.dart).
- presentation

You can read more about Clean Architecture principles applied to Flutter in the following articles:

- https://medium.com/@yamen.abd98/clean-architecture-in-flutter-mvvm-bloc-dio-79b1615530e1
- https://medium.com/@semihaltin99/flutter-clean-architecture-8759ad0213dd

```

## Appendix B: State Management with BLoC

- bloc
  - state: All data that is needed to render the UI, to make decisions in the presentation layer or that comes from user input and should be send to or used in the domain layer. E.g. [`RecoverWalletState`](lib/features/recover_wallet/presentation/bloc/recover_wallet_state.dart).
  - event: All events that can trigger a state change. E.g. [`PinCodeEvent`](lib/features/pin_code/presentation/blocs/pin_code/pin_code_event.dart).
  - bloc: The class that contains the logic to handle the events and update the state by using the use cases of the domain layer. E.g. [`PinCodeBloc`](lib/features/pin_code/presentation/blocs/pin_code/pin_code_bloc.dart).
```
