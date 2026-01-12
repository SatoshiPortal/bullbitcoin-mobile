# Secrets Feature Architecture

This document describes the architecture of the Secrets feature, which manages cryptographic secret storage, usage tracking, and provides a public API for other features.

## Architecture Overview

The Secrets feature follows Clean Architecture principles with clear separation of concerns across distinct layers:

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

- **Presentation Layer**: Handles UI events and state
- **Public Facade**: Handles external calls from other features

Both depend on the Application Layer use cases but serve different clients.

## Architecture Diagrams

### Overview - Simplified Component Diagram

This diagram shows the main components and how they interact across layers:

```mermaid
graph LR
    subgraph Controllers
        PF[SecretsFacade]
        BLoC[SecretsViewBloc]
    end

    subgraph Application
        UC[Use Cases<br/>11 operations]
        Ports[Ports<br/>5 interfaces]
    end

    subgraph Adapters
        Repos[Repositories & Stores<br/>DriftSecretUsageRepository<br/>SecretStore]
        Crypto[Crypto Services<br/>BdkMnemonicGenerator<br/>Bip32And39SecretCrypto]
    end

    subgraph Domain
        Entities[SecretUsage<br/>Secret<br/>SecretUsagePurpose]
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
    class Secret {
        <<sealed>>
        +kind: SecretKind
    }

    class SeedSecret {
        +bytes: List~int~
    }

    class MnemonicSecret {
        +words: List~String~
        +passphrase: String?
    }

    class SecretUsagePurpose {
        <<enumeration>>
        wallet
        bip85
    }

    Secret <|-- SeedSecret
    Secret <|-- MnemonicSecret

    %% Domain Entities
    class SecretUsage {
        +id: int
        +fingerprint: String
        +purpose: SecretUsagePurpose
        +consumerRef: String
        +createdAt: DateTime
    }

    SecretUsage --> SecretUsagePurpose
```

### Application Layer - Ports (Interfaces)

Contracts that define dependencies on external systems:

```mermaid
classDiagram
    class SecretStorePort {
        <<interface>>
        +save(fingerprint, secret)
        +load(fingerprint) Secret
        +loadAll() List~Secret~
        +exists(fingerprint) bool
        +delete(fingerprint)
    }

    class SecretUsageRepositoryPort {
        <<interface>>
        +add(fingerprint, purpose, consumerRef) SecretUsage
        +isUsed(fingerprint) bool
        +getByConsumer(purpose, consumerRef) SecretUsage?
        +getAll() List~SecretUsage~
        +deleteById(id)
    }

    class MnemonicGeneratorPort {
        <<interface>>
        +generateMnemonic() List~String~
    }

    class SecretCryptoPort {
        <<interface>>
        +getFingerprintFromSecret(secret) String
    }

    class LegacySeedSecretStorePort {
        <<interface>>
        +loadAll() List~SeedSecret~
    }

    class SecretUsage {
        +id: int
        +fingerprint: String
    }

    SecretUsageRepositoryPort --> SecretUsage
```

### Application Layer - Use Cases

Orchestration and business logic operations. Each use case coordinates multiple ports to fulfill a specific application need:

```mermaid
classDiagram
    %% Ports (shown for reference)
    class SecretStorePort {
        <<interface>>
    }
    class SecretUsageRepositoryPort {
        <<interface>>
    }
    class MnemonicGeneratorPort {
        <<interface>>
    }
    class SecretCryptoPort {
        <<interface>>
    }
    class LegacySeedSecretStorePort {
        <<interface>>
    }

    %% Secret Creation & Import Use Cases
    class CreateNewMnemonicSecretUseCase {
        +execute(command) Result
    }

    class ImportMnemonicSecretUseCase {
        +execute(command) Result
    }

    class ImportSeedSecretUseCase {
        +execute(command) Result
    }

    %% Secret Usage Management
    class RegisterSecretUsageUseCase {
        +execute(command)
    }

    class DeregisterSecretUsageUseCase {
        +execute(command)
    }

    class GetSecretUsageByConsumerUseCase {
        +execute(query) Result
    }

    class DeregisterSecretUsageWithFingerprintCheckUseCase {
        +execute(command)
    }

    class ListUsedSecretsUseCase {
        +execute(query) Result
    }

    %% Secret Operations
    class GetSecretUseCase {
        +execute(query) Result
    }

    class DeleteSecretUseCase {
        +execute(command)
    }

    class LoadAllStoredSecretsUseCase {
        +execute(query) Result
    }

    class LoadLegacySecretsUseCase {
        +execute(query) Result
    }

    %% Dependencies
    CreateNewMnemonicSecretUseCase ..> MnemonicGeneratorPort
    CreateNewMnemonicSecretUseCase ..> SecretCryptoPort
    CreateNewMnemonicSecretUseCase ..> SecretStorePort
    CreateNewMnemonicSecretUseCase ..> SecretUsageRepositoryPort

    ImportMnemonicSecretUseCase ..> SecretStorePort
    ImportMnemonicSecretUseCase ..> SecretCryptoPort
    ImportMnemonicSecretUseCase ..> SecretUsageRepositoryPort

    ImportSeedSecretUseCase ..> SecretStorePort
    ImportSeedSecretUseCase ..> SecretCryptoPort
    ImportSeedSecretUseCase ..> SecretUsageRepositoryPort

    RegisterSecretUsageUseCase ..> SecretUsageRepositoryPort
    DeregisterSecretUsageUseCase ..> SecretUsageRepositoryPort
    GetSecretUsageByConsumerUseCase ..> SecretUsageRepositoryPort
    DeregisterSecretUsageWithFingerprintCheckUseCase ..> GetSecretUsageByConsumerUseCase
    DeregisterSecretUsageWithFingerprintCheckUseCase ..> DeregisterSecretUsageUseCase
    ListUsedSecretsUseCase ..> SecretUsageRepositoryPort

    GetSecretUseCase ..> SecretStorePort

    DeleteSecretUseCase ..> SecretStorePort
    DeleteSecretUseCase ..> SecretUsageRepositoryPort

    LoadAllStoredSecretsUseCase ..> SecretStorePort
    LoadAllStoredSecretsUseCase ..> SecretCryptoPort

    LoadLegacySecretsUseCase ..> LegacySeedSecretStorePort
    LoadLegacySecretsUseCase ..> SecretCryptoPort
```

### Interface Adapters Layer

Implementations of ports using external frameworks and services:

```mermaid
classDiagram
    %% Ports (for reference)
    class SecretStorePort {
        <<interface>>
    }
    class SecretUsageRepositoryPort {
        <<interface>>
    }
    class MnemonicGeneratorPort {
        <<interface>>
    }
    class SecretCryptoPort {
        <<interface>>
    }

    %% Implementations
    class SecretStore {
        -secretDatasource: SecretDatasource
        +save(fingerprint, secret)
        +load(fingerprint) Secret
        +loadAll() List~Secret~
        +exists(fingerprint) bool
        +delete(fingerprint)
    }

    class SecretDatasource {
        <<interface>>
        +store(fingerprint, secret)
        +get(fingerprint) SecretModel?
        +exists(fingerprint) bool
        +getAll() List~SecretModel~
        +delete(fingerprint)
    }

    class DriftSecretUsageRepository {
        -database: SqliteDatabase
        +add(fingerprint, purpose, consumerRef) SecretUsage
        +isUsed(fingerprint) bool
        +getByConsumer(purpose, consumerRef) SecretUsage?
        +getAll() List~SecretUsage~
        +deleteById(id)
    }

    class BdkMnemonicGenerator {
        +generateMnemonic() List~String~
    }

    class Bip32And39SecretCrypto {
        +getFingerprintFromSecret(secret) String
    }

    %% Relationships
    SecretStore ..|> SecretStorePort
    SecretStore --> SecretDatasource

    DriftSecretUsageRepository ..|> SecretUsageRepositoryPort

    BdkMnemonicGenerator ..|> MnemonicGeneratorPort

    Bip32And39SecretCrypto ..|> SecretCryptoPort
```

### Controllers - Public Facade & Presentation

Entry points for external features and UI:

```mermaid
classDiagram
    %% Use Cases (for reference)
    class CreateNewMnemonicSecretUseCase
    class ImportMnemonicSecretUseCase
    class GetSecretUseCase
    class DeregisterSecretUsageWithFingerprintCheckUseCase
    class LoadAllStoredSecretsUseCase
    class ListUsedSecretsUseCase
    class DeleteSecretUseCase
    class LoadLegacySecretsUseCase

    %% Public Facade (for other features)
    class SecretsFacade {
        +createNewMnemonic()
        +importMnemonic()
        +getSecret()
        +deregisterUsage()
    }

    SecretsFacade ..> CreateNewMnemonicSecretUseCase
    SecretsFacade ..> ImportMnemonicSecretUseCase
    SecretsFacade ..> GetSecretUseCase
    SecretsFacade ..> DeregisterSecretUsageWithFingerprintCheckUseCase

    %% Presentation (for UI)
    class SecretsViewBloc {
        +on~SecretsViewLoadRequested~()
        +on~SecretsViewDeleteRequested~()
    }

    class SecretViewModel {
        +fingerprint: String
        +secret: Secret
        +isLegacy: bool
        +isInUse: bool
    }

    class Secret {
        <<from domain>>
    }

    SecretsViewBloc ..> LoadAllStoredSecretsUseCase
    SecretsViewBloc ..> ListUsedSecretsUseCase
    SecretsViewBloc ..> DeleteSecretUseCase
    SecretsViewBloc ..> LoadLegacySecretsUseCase
    SecretsViewBloc --> SecretViewModel
    SecretViewModel --> Secret
```

## Layer Responsibilities

### Domain Layer

- **Entities**: Core business domain objects with rules (`SecretUsage`)
- **Value Objects**: Primitive types from `/lib/core/primitives/secrets/` (`Secret`, `SeedSecret`, `MnemonicSecret`, `SecretUsagePurpose`)

### Application Layer

- **Use Cases**: Orchestration and business rule enforcement (12 use cases)
  - Coordinate multiple ports to fulfill application requirements
  - Enforce business rules (e.g., "cannot delete secret if in use")
  - Implement application workflows (e.g., create → store → register usage)
  - **Composed Use Cases**: Higher-level use cases that combine multiple atomic use cases to handle complex scenarios while avoiding code duplication (e.g., `DeregisterSecretUsageWithFingerprintCheckUseCase` combines get-usage and deregister-usage with fingerprint validation)
- **Ports**: Interfaces defining boundaries with external systems

### Interface Adapters Layer

- **Repositories**: Data access implementations (`DriftSecretUsageRepository`)
- **Stores**: Secure storage adapters (`SecretStore`)
- **External Service Adapters**: Crypto and mnemonic generation (`BdkMnemonicGenerator`, `Bip32And39SecretCrypto`)

### Public Facade Layer

- **SecretsFacade**: Unified API for other features to interact with secrets
- Handles calls from external features
- Converts application errors to facade-level errors

### Presentation Layer

- **BLoC**: State management for UI (`SecretsViewBloc`)
- **View Models**: UI-specific data structures (`SecretViewModel`)
- Handles UI events and state updates

## Key Data Flows

### Creating a New Secret

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as CreateNewMnemonicSecretUseCase
    participant MG as MnemonicGeneratorPort
    participant SC as SecretCryptoPort
    participant SS as SecretStorePort
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(command)
    UC->>MG: generateMnemonic()
    MG-->>UC: words[]
    UC->>SC: getFingerprintFromSecret()
    SC-->>UC: fingerprint
    UC->>SS: save(fingerprint, secret)
    UC->>SR: add(fingerprint, purpose, consumerRef)
    SR-->>UC: SecretUsage
    UC-->>F: Result(fingerprint, secret)
```

### Deleting a Secret

```mermaid
sequenceDiagram
    participant B as SecretsViewBloc
    participant UC as DeleteSecretUseCase
    participant SR as SecretUsageRepositoryPort
    participant SS as SecretStorePort

    B->>UC: execute(DeleteSecretCommand)
    UC->>SR: isUsed(fingerprint)
    SR-->>UC: true/false
    alt Secret is in use
        UC-->>B: Error: SecretInUseError
    else Secret not in use
        UC->>SS: delete(fingerprint)
        UC-->>B: Success
    end
```

### Importing a Mnemonic Secret

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as ImportMnemonicSecretUseCase
    participant SC as SecretCryptoPort
    participant SS as SecretStorePort
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(command)
    UC->>SC: getFingerprintFromSecret()
    SC-->>UC: fingerprint
    UC->>SS: exists(fingerprint)
    SS-->>UC: true/false
    alt Secret already exists
        UC-->>F: Error: SecretAlreadyExistsError
    else Secret doesn't exist
        UC->>SS: save(fingerprint, secret)
        UC->>SR: add(fingerprint, purpose, consumerRef)
        SR-->>UC: SecretUsage
        UC-->>F: Result(fingerprint, secret)
    end
```

### Importing a Seed Secret (bytes)

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as ImportSeedSecretUseCase
    participant SC as SecretCryptoPort
    participant SS as SecretStorePort
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(command)
    UC->>SC: getFingerprintFromSecret()
    SC-->>UC: fingerprint
    UC->>SS: exists(fingerprint)
    SS-->>UC: true/false
    alt Secret already exists
        UC-->>F: Error: SecretAlreadyExistsError
    else Secret doesn't exist
        UC->>SS: save(fingerprint, secret)
        UC->>SR: add(fingerprint, purpose, consumerRef)
        SR-->>UC: SecretUsage
        UC-->>F: Result(fingerprint, secret)
    end
```

### Getting a Secret

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as GetSecretUseCase
    participant SS as SecretStorePort

    F->>UC: execute(query)
    UC->>SS: load(fingerprint)
    SS-->>UC: Secret
    UC-->>F: Result(secret)
```

### Deregistering Secret Usage with Fingerprint Check

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as DeregisterSecretUsageWithFingerprintCheckUseCase
    participant GetUC as GetSecretUsageByConsumerUseCase
    participant DeregUC as DeregisterSecretUsageUseCase
    participant SR as SecretUsageRepositoryPort
    participant SC as SecretCryptoPort
    participant SS as SecretStorePort

    F->>UC: execute(command)
    UC->>GetUC: execute(query)
    GetUC->>SR: getByConsumer(purpose, consumerRef)
    SR-->>GetUC: SecretUsage
    GetUC-->>UC: Result(SecretUsage)
    UC->>SS: load(fingerprint)
    SS-->>UC: Secret
    UC->>SC: getFingerprintFromSecret()
    SC-->>UC: actualFingerprint
    alt Fingerprint doesn't match
        UC-->>F: Error: FingerprintMismatchError
    else Fingerprint matches
        UC->>DeregUC: execute(command)
        DeregUC->>SR: deleteById(id)
        DeregUC-->>UC: Success
        UC-->>F: Success
    end
```

### Loading All Stored Secrets

```mermaid
sequenceDiagram
    participant B as SecretsViewBloc
    participant UC as LoadAllStoredSecretsUseCase
    participant SS as SecretStorePort
    participant SC as SecretCryptoPort

    B->>UC: execute(query)
    UC->>SS: loadAll()
    SS-->>UC: List<Secret>
    loop For each secret
        UC->>SC: getFingerprintFromSecret(secret)
        SC-->>UC: fingerprint
    end
    UC-->>B: Result(List<(fingerprint, secret)>)
```

### Loading Legacy Secrets

```mermaid
sequenceDiagram
    participant B as SecretsViewBloc
    participant UC as LoadLegacySecretsUseCase
    participant LSS as LegacySeedSecretStorePort
    participant SC as SecretCryptoPort

    B->>UC: execute(query)
    UC->>LSS: loadAll()
    LSS-->>UC: List<SeedSecret>
    loop For each legacy secret
        UC->>SC: getFingerprintFromSecret(secret)
        SC-->>UC: fingerprint
    end
    UC-->>B: Result(List<(fingerprint, secret)>)
```

### Listing Used Secrets

```mermaid
sequenceDiagram
    participant B as SecretsViewBloc
    participant UC as ListUsedSecretsUseCase
    participant SR as SecretUsageRepositoryPort

    B->>UC: execute(query)
    UC->>SR: getAll()
    SR-->>UC: List<SecretUsage>
    UC-->>B: Result(List<SecretUsage>)
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

1. **Secret Deletion Protection**: A secret cannot be deleted if it has registered usages
2. **Usage Tracking**: All secret access must be registered with a purpose and consumer reference
3. **Fingerprint Identity**: Secrets are uniquely identified by their BIP32 fingerprint
4. **Legacy Support**: Old secrets can be loaded and migrated through dedicated use case
5. **Secure Storage**: Secrets are stored separately from usage metadata (secrets in secure storage, usages in SQLite)
