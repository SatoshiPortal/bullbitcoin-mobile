# Contributing

## Git Workflow

TODO: Describe the branch structure, forking to a personal repository, pull request, etc.

## Generated files

A `makefile` is available to assist you during the setup of the project and generate all needed files using the command `make setup`.


## Guidelines

- Keep it simple.

- Write code that's easy to read and maintain think of your teammate who will read it next.

- Suffix your files (`_datasource.dart` `_repository.dart` `_model.dart` `_usecase.dart` `_entity.dart` `_widget.dart` `_page.dart` )

- Avoid creating unnecessary folders. Since most files have descriptive suffixes, only create a folder if you're placing multiple related files inside.

- Avoid abstract classes unless there's a clear current need. Don’t preemptively abstract for hypothetical future cases, start concrete, and refactor when it becomes necessary.

- Favor end-to-end and integration testing at the use case and widget level rather than relying on mocks. Since this is an app project, our priority is to catch real-world issues across layers. Mocking should be used only when necessary

## Adding a new feature

### Step 1: Define the different layers of the feature

Before starting to implement a new feature, it is important to define what and how to implement it. Since the project follows a specified [structure](/ARCHITECTURE.md#-project-structure) based on [Clean Architecture](/ARCHITECTURE.md#clean-architecture) principles, you should read the [ARCHITECTURE](/ARCHITECTURE.md) file if you haven't yet and first think about the different layers the feature need: domain, data, and presentation layer. To help you with this, you can try to answer the following questions first:

- What data does my feature need?
- Where does the data come from or where does it have to be stored or send to?
- What actions can be performed by the user and how does this affect the data?

With answers to these questions, dividing the feature into the different layers should be easier:

The first question helps you identify the entities and repository contracts needed in the domain layer. The second question helps you identify the data sources and repository implementations needed in the data layer. The third question helps you identify the use cases needed in the domain layer and how to connect them to the presentation layer.

With that in mind, create a comment on the issue of the feature you want to implement, describing the different layers of the feature. This will help you to get feedback on your approach and to make sure you are on the right track. Here is an example for the ['Import watch-only wallet' feature](/lib/import_watch_only_wallet):

```markdown
- domain
  - entities: Wallet, Settings (to get the environment to import the wallet to)
  - repository contracts: SettingsRepository
  - service contracts: WalletManagerService
  - use cases: ImportXpubUsecase (This will orchestrate the whole process of importing the xpub and registering the wallet in the app)
- data
  - models: WalletMetadataModel, SettingsModel, BalanceModel
  - data sources: WalletDatasource, BdkWalletDatasourceImpl, WalletMetadataDatasource, Bip32Datasource, DescriptorDatasource
  - repository implementations: SettingsRepositoryImpl
  - service implementations: WalletManagerServiceImpl
- presentation
  - bloc
    - ImportWatchOnlyWalletBloc
      - state: One state class with a status field (initial, loading, success) and following fields: String xpub, ScriptType scriptType, String label, Object? error
      - events: ImportWatchOnlyWalletXpubChanged, ImportWatchOnlyWalletLabelChanged, ImportWatchOnlyWalletSubmit
  - The screens and widgets shouldn't be described, since they are defined by the UI design already.
```

Some remarks on the example above:

- The above example is just an example and might not be complete or the same as the real current implementation.
- The example specifies a lot of things that were implemented in the [`_core`](lib/_core/) folder of the app. If classes exist already, you should not specify them. You can just clarify in the comment that you will use the existing implementations of certain repositories or services in the feature's use cases.
- Not every feature will require all layers, and it's important to consider which ones are necessary and why. For example, a simple data source might not need a model, and a simple single-screen feature might not require a Bloc.

Software development is not an exact science, and this step is about understanding the feature better and getting feedback on your approach. Don’t worry if you're unsure about all the layers initially or need to adjust them later; the goal is to have a starting point for discussion and refinement.

### Step 2: Implement the feature

- Add a new folder for the feature
- Implement the different layers of the feature as defined and signed-off on in the issue
- In case your feature requires some initialization or checks before the app starts, for initial routing or just initial setup, please create a use case for it and execute it in the `AppStartupBloc`'s `_onStarted` method. You can look at the existing use cases in the [`AppStartupBloc`](lib/app_startup/presentation/bloc/app_startup_bloc.dart) for reference.
- Use `GetIt` to register datasources, repositories, services, usecases and blocs. Generally, datasources, repositories and services should be registered as singletons, and usecases and blocs as a factory. You can create a `<feature>_locator.dart` file in the root of the feature's folder with a class with a `setup` function in which of the feature easily. E.g. [`HomeLocator`](lib/home/home_locator.dart). Make sure to then call the `setup` function in the [`AppLocator`](lib/locator.dart) so it gets registered at app startup.
- If the feature has subroutes, you can define a `<feature>_router.dart` file in the ui folder of the feature with a class that defines the subroutes. E.g. [`ReceiveRouter`](lib/receive/ui/receive_router.dart). Make sure to add the top-level routes to the [`AppRouter`](lib/router.dart) as well.

### Step 3: Write tests

Tests are an essential part of the development process. They help to ensure that the code works as expected and no existing or future code is accidentally broken. They also make it easier for reviewers to know if the code complies with the requirements and if all edge cases are covered. In this regard, tests might even be the best documentation for other code contributors. So the effort of writing tests, might save the need for extensive documentation and time-consuming regression testing. That's why we encourage you to write tests for your code.

#### Unit tests

Make sure all code of the data, domain and presentation layers of the feature is covered by unit tests:

- The data layer should be tested by mocking the data sources and checking if the repository implementations return the expected entities. If the data sources have dependencies that are not easily mocked, you can use integration tests to test them. To test services, mock the repositories they depend on and check if the service returns the expected entities.
- The domain layer should be tested by mocking the repository and service contracts and checking if the use cases return the expected entities or values.
- The presentation layer should be tested by mocking the use cases and checking if the Blocs emit the expected states when the events are added.

#### Widget tests

Make sure the ui of the feature is covered by widget tests.

#### Integration tests (optional)

Integration tests might be necessary if the feature requires interaction with external datasources and we want to make sure there is no compatibility issue between the models and calls made by the code and the actual API of the service.
Using integration tests can also be useful to test classes with dependencies that are not easily mocked and/or have dependencies, like `bdk_flutter` or `lwk`, that have native code. See the [integration_test](integration_test) folder for examples.
