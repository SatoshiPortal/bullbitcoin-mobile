# Seeds Feature Architecture

This document describes the architecture of the Seeds feature, which manages cryptographic seed storage, usage tracking, and provides a public API for other features.

## Architecture Overview

The Seeds feature follows Clean Architecture principles with clear separation of concerns across distinct layers:

```mermaid
graph TD
    UI[UI Layer] --> PL[Presentation Layer - BLoC]
    OF[Other Features] --> PF[Public Facade]
    PL --> UC[Application Layer - Use Cases]
    PF --> UC
    UC --> P[Application Layer - Ports]
    IA[Interface Adapters] -.implements.-> P
    IA --> FD[Frameworks & Drivers]
```

**Note**: Presentation Layer (BLoC) and Public Facade are both at the same architectural level - they are controllers for different triggers:

- **Presentation Layer**: Controls UI events and state
- **Public Facade**: Controls external calls from other features

Both depend on the Application Layer use cases but serve different clients.

## Architecture Diagrams

### Overview - Simplified Component Diagram

This diagram shows the main components and how they interact across layers:

```mermaid
graph LR
    subgraph Controllers
        PF[SeedsFacade]
        BLoC[SeedsViewBloc]
    end

    subgraph Application
        UC[Use Cases<br/>12 operations]
        Ports[Ports<br/>5 interfaces]
    end

    subgraph Adapters
        Repos[Repositories & Stores<br/>DriftSeedUsageRepository<br/>SeedSecretStore]
        Crypto[Crypto Services<br/>BdkMnemonicGenerator<br/>Bip32And39SeedCrypto]
    end

    subgraph Domain
        Entities[SeedUsage<br/>SeedSecret<br/>SeedUsagePurpose]
    end

    PF --> UC
    BLoC --> UC
    UC --> Ports
    Repos -.implements.-> Ports
    Crypto -.implements.-> Ports
    Ports -.uses.-> Entities
```

### Domain & Core Layer

Foundation types and business entities:

```mermaid
classDiagram
    %% Core/Primitives
    class SeedSecret {
        <<sealed>>
        +kind: SeedSecretKind
    }

    class SeedBytesSecret {
        +bytes: List~int~
    }

    class SeedMnemonicSecret {
        +words: List~String~
        +passphrase: String?
    }

    class SeedUsagePurpose {
        <<enumeration>>
        wallet
        bip85
    }

    SeedSecret <|-- SeedBytesSecret
    SeedSecret <|-- SeedMnemonicSecret

    %% Domain Entities
    class SeedUsage {
        +id: int
        +fingerprint: String
        +purpose: SeedUsagePurpose
        +consumerRef: String
        +createdAt: DateTime
    }

    SeedUsage --> SeedUsagePurpose
```

### Application Layer - Ports (Interfaces)

Contracts that define dependencies on external systems:

```mermaid
classDiagram
    class SeedSecretStorePort {
        <<interface>>
        +save(fingerprint, secret)
        +load(fingerprint) SeedSecret
        +loadAll() List~SeedSecret~
        +exists(fingerprint) bool
        +delete(fingerprint)
    }

    class SeedUsageRepositoryPort {
        <<interface>>
        +add(fingerprint, purpose, consumerRef) SeedUsage
        +isUsed(fingerprint) bool
        +getByConsumer(purpose, consumerRef) SeedUsage?
        +getAll() List~SeedUsage~
        +deleteById(id)
    }

    class MnemonicGeneratorPort {
        <<interface>>
        +generateMnemonic() List~String~
    }

    class SeedCryptoPort {
        <<interface>>
        +getFingerprintFromSeedSecret(secret) String
    }

    class LegacySeedSecretStorePort {
        <<interface>>
        +loadAll() List~SeedSecret~
    }

    class SeedUsage {
        +id: int
        +fingerprint: String
    }

    SeedUsageRepositoryPort --> SeedUsage
```

### Application Layer - Use Cases

Orchestration and business logic operations. Each use case coordinates multiple ports to fulfill a specific application need:

```mermaid
classDiagram
    %% Ports (shown for reference)
    class SeedSecretStorePort {
        <<interface>>
    }
    class SeedUsageRepositoryPort {
        <<interface>>
    }
    class MnemonicGeneratorPort {
        <<interface>>
    }
    class SeedCryptoPort {
        <<interface>>
    }
    class LegacySeedSecretStorePort {
        <<interface>>
    }

    %% Seed Creation & Import Use Cases
    class CreateNewSeedMnemonicUseCase {
        +execute(command) Result
    }

    class ImportSeedMnemonicUseCase {
        +execute(command) Result
    }

    class ImportSeedBytesUseCase {
        +execute(command) Result
    }

    %% Seed Usage Management
    class RegisterSeedUsageUseCase {
        +execute(command)
    }

    class DeregisterSeedUsageUseCase {
        +execute(command)
    }

    class GetSeedUsageByConsumerUseCase {
        +execute(query) Result
    }

    class DeregisterSeedUsageWithFingerprintCheckUseCase {
        +execute(command)
    }

    class ListUsedSeedsUseCase {
        +execute(query) Result
    }

    %% Seed Secret Operations
    class GetSeedSecretUseCase {
        +execute(query) Result
    }

    class DeleteSeedUseCase {
        +execute(command)
    }

    class LoadAllStoredSeedSecretsUseCase {
        +execute(query) Result
    }

    class LoadLegacySeedsUseCase {
        +execute(query) Result
    }

    %% Dependencies
    CreateNewSeedMnemonicUseCase ..> MnemonicGeneratorPort
    CreateNewSeedMnemonicUseCase ..> SeedCryptoPort
    CreateNewSeedMnemonicUseCase ..> SeedSecretStorePort
    CreateNewSeedMnemonicUseCase ..> SeedUsageRepositoryPort

    ImportSeedMnemonicUseCase ..> SeedSecretStorePort
    ImportSeedMnemonicUseCase ..> SeedCryptoPort
    ImportSeedMnemonicUseCase ..> SeedUsageRepositoryPort

    ImportSeedBytesUseCase ..> SeedSecretStorePort
    ImportSeedBytesUseCase ..> SeedCryptoPort
    ImportSeedBytesUseCase ..> SeedUsageRepositoryPort

    RegisterSeedUsageUseCase ..> SeedUsageRepositoryPort
    DeregisterSeedUsageUseCase ..> SeedUsageRepositoryPort
    GetSeedUsageByConsumerUseCase ..> SeedUsageRepositoryPort
    DeregisterSeedUsageWithFingerprintCheckUseCase ..> GetSeedUsageByConsumerUseCase
    DeregisterSeedUsageWithFingerprintCheckUseCase ..> DeregisterSeedUsageUseCase
    ListUsedSeedsUseCase ..> SeedUsageRepositoryPort

    GetSeedSecretUseCase ..> SeedSecretStorePort

    DeleteSeedUseCase ..> SeedSecretStorePort
    DeleteSeedUseCase ..> SeedUsageRepositoryPort

    LoadAllStoredSeedSecretsUseCase ..> SeedSecretStorePort
    LoadAllStoredSeedSecretsUseCase ..> SeedCryptoPort

    LoadLegacySeedsUseCase ..> LegacySeedSecretStorePort
    LoadLegacySeedsUseCase ..> SeedCryptoPort
```

### Interface Adapters Layer

Implementations of ports using external frameworks and services:

```mermaid
classDiagram
    %% Ports (for reference)
    class SeedSecretStorePort {
        <<interface>>
    }
    class SeedUsageRepositoryPort {
        <<interface>>
    }
    class MnemonicGeneratorPort {
        <<interface>>
    }
    class SeedCryptoPort {
        <<interface>>
    }

    %% Implementations
    class SeedSecretStore {
        -seedSecretDatasource: SeedSecretDatasource
        +save(fingerprint, secret)
        +load(fingerprint) SeedSecret
        +loadAll() List~SeedSecret~
        +exists(fingerprint) bool
        +delete(fingerprint)
    }

    class SeedSecretDatasource {
        <<interface>>
        +store(fingerprint, seed)
        +get(fingerprint) SeedSecretModel?
        +exists(fingerprint) bool
        +getAll() List~SeedSecretModel~
        +delete(fingerprint)
    }

    class DriftSeedUsageRepository {
        -database: SqliteDatabase
        +add(fingerprint, purpose, consumerRef) SeedUsage
        +isUsed(fingerprint) bool
        +getByConsumer(purpose, consumerRef) SeedUsage?
        +getAll() List~SeedUsage~
        +deleteById(id)
    }

    class BdkMnemonicGenerator {
        +generateMnemonic() List~String~
    }

    class Bip32And39SeedCrypto {
        +getFingerprintFromSeedSecret(secret) String
    }

    %% Relationships
    SeedSecretStore ..|> SeedSecretStorePort
    SeedSecretStore --> SeedSecretDatasource

    DriftSeedUsageRepository ..|> SeedUsageRepositoryPort

    BdkMnemonicGenerator ..|> MnemonicGeneratorPort

    Bip32And39SeedCrypto ..|> SeedCryptoPort
```

### Controllers - Public Facade & Presentation

Entry points for external features and UI:

```mermaid
classDiagram
    %% Use Cases (for reference)
    class CreateNewSeedMnemonicUseCase
    class ImportSeedMnemonicUseCase
    class GetSeedSecretUseCase
    class RegisterSeedUsageUseCase
    class DeregisterSeedUsageWithFingerprintCheckUseCase
    class LoadAllStoredSeedSecretsUseCase
    class ListUsedSeedsUseCase
    class DeleteSeedUseCase
    class LoadLegacySeedsUseCase

    %% Public Facade (for other features)
    class SeedsFacade {
        +createNewMnemonic()
        +importMnemonic()
        +getSeedSecret()
        +registerUsage()
        +deregisterUsage()
    }

    SeedsFacade ..> CreateNewSeedMnemonicUseCase
    SeedsFacade ..> ImportSeedMnemonicUseCase
    SeedsFacade ..> GetSeedSecretUseCase
    SeedsFacade ..> RegisterSeedUsageUseCase
    SeedsFacade ..> DeregisterSeedUsageWithFingerprintCheckUseCase

    %% Presentation (for UI)
    class SeedsViewBloc {
        +on~SeedsViewLoadRequested~()
        +on~SeedsViewDeleteRequested~()
    }

    class SeedViewModel {
        +fingerprint: String
        +seedSecret: SeedSecret
        +isLegacy: bool
        +isInUse: bool
    }

    class SeedSecret {
        <<from domain>>
    }

    SeedsViewBloc ..> LoadAllStoredSeedSecretsUseCase
    SeedsViewBloc ..> ListUsedSeedsUseCase
    SeedsViewBloc ..> DeleteSeedUseCase
    SeedsViewBloc ..> LoadLegacySeedsUseCase
    SeedsViewBloc --> SeedViewModel
    SeedViewModel --> SeedSecret
```

## Layer Responsibilities

### Domain Layer

- **Entities**: Core business objects (`SeedUsage`)
- **Value Objects**: Primitive types from `/lib/core/primitives/seeds/` (`SeedSecret`, `SeedUsagePurpose`)

### Application Layer

- **Use Cases**: Orchestration and business rule enforcement (12 use cases)
  - Coordinate multiple ports to fulfill application requirements
  - Enforce business rules (e.g., "cannot delete seed if in use")
  - Implement application workflows (e.g., create → store → register usage)
  - **Composed Use Cases**: Higher-level use cases that combine multiple atomic use cases to handle complex scenarios while avoiding code duplication (e.g., `DeregisterSeedUsageWithFingerprintCheckUseCase` combines get-usage and deregister-usage with fingerprint validation)
- **Ports**: Interfaces defining boundaries with external systems

### Interface Adapters Layer

- **Repositories**: Data access implementations (`DriftSeedUsageRepository`)
- **Stores**: Secure storage adapters (`SeedSecretStore`)
- **External Service Adapters**: Crypto and mnemonic generation (`BdkMnemonicGenerator`, `Bip32And39SeedCrypto`)

### Public Facade Layer

- **SeedsFacade**: Unified API for other features to interact with seeds
- Handles calls from external features
- Converts application errors to facade-level errors

### Presentation Layer

- **BLoC**: State management for UI (`SeedsViewBloc`)
- **View Models**: UI-specific data structures (`SeedViewModel`)
- Handles UI events and state updates

## Key Data Flows

### Creating a New Seed

```mermaid
sequenceDiagram
    participant F as SeedsFacade
    participant UC as CreateNewSeedMnemonicUseCase
    participant MG as MnemonicGeneratorPort
    participant SC as SeedCryptoPort
    participant SS as SeedSecretStorePort
    participant SR as SeedUsageRepositoryPort

    F->>UC: execute(command)
    UC->>MG: generateMnemonic()
    MG-->>UC: words[]
    UC->>SC: getFingerprintFromSeedSecret()
    SC-->>UC: fingerprint
    UC->>SS: save(fingerprint, secret)
    UC->>SR: add(fingerprint, purpose, consumerRef)
    SR-->>UC: SeedUsage
    UC-->>F: Result(fingerprint, secret)
```

### Deleting a Seed

```mermaid
sequenceDiagram
    participant B as SeedsViewBloc
    participant UC as DeleteSeedUseCase
    participant SR as SeedUsageRepositoryPort
    participant SS as SeedSecretStorePort

    B->>UC: execute(DeleteSeedCommand)
    UC->>SR: isUsed(fingerprint)
    SR-->>UC: true/false
    alt Seed is in use
        UC-->>B: Error: SeedInUseError
    else Seed not in use
        UC->>SS: delete(fingerprint)
        UC-->>B: Success
    end
```

## Design Patterns

- **Clean Architecture**: Layered architecture with dependency inversion
- **Use Case Pattern**: Each business operation encapsulated in a dedicated class
- **Repository Pattern**: Data access abstraction
- **Port/Adapter Pattern**: External dependencies hidden behind interfaces
- **Facade Pattern**: Simplified public API for complex subsystem
- **Command/Query Segregation**: Clear separation between operations that modify state vs read state
- **BLoC Pattern**: Business logic separation in presentation layer

## Key Business Rules

1. **Seed Deletion Protection**: A seed cannot be deleted if it has registered usages
2. **Usage Tracking**: All seed access must be registered with a purpose and consumer reference
3. **Fingerprint Identity**: Seeds are uniquely identified by their BIP32 fingerprint
4. **Legacy Support**: Old seeds can be loaded and migrated through dedicated use case
5. **Secure Storage**: Seed secrets are stored separately from usage metadata (secrets in secure storage, usages in SQLite)
