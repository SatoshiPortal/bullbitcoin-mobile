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
        UC[Use Cases<br/>10 operations]
        Ports[Ports<br/>5 interfaces]
    end

    subgraph Adapters
        Repos[Repositories & Stores<br/>DriftSecretUsageRepository<br/>SecretStore]
        Crypto[Crypto Services<br/>BdkMnemonicGenerator<br/>Bip32And39SecretCrypto]
    end

    subgraph Domain
        Entities[Entities<br/>Secret, SecretUsage]
        VOs[Value Objects<br/>Fingerprint, SecretConsumer, etc.]
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
    %% Domain Entities
    class Secret {
        <<sealed>>
        +fingerprint: Fingerprint
    }

    class SeedSecret {
        +fingerprint: Fingerprint
        +bytes: SeedBytes
    }

    class MnemonicSecret {
        +fingerprint: Fingerprint
        +words: MnemonicWords
        +passphrase: Passphrase?
    }

    Secret <|-- SeedSecret
    Secret <|-- MnemonicSecret

    class SecretUsage {
        +id: SecretUsageId
        +fingerprint: Fingerprint
        +consumer: SecretConsumer
        +createdAt: DateTime
    }

    %% Value Objects
    class Fingerprint {
        +value: String
        +fromHex(hex) Fingerprint
    }

    class SecretUsageId {
        +value: int
    }

    class SecretConsumer {
        <<sealed>>
    }

    class WalletConsumer {
        +walletId: String
    }

    class Bip85Consumer {
        +bip85Path: String
    }

    class MnemonicWords {
        +value: List~String~
    }

    class Passphrase {
        +value: String
        +empty() Passphrase
    }

    class SeedBytes {
        +value: List~int~
    }

    SecretConsumer <|-- WalletConsumer
    SecretConsumer <|-- Bip85Consumer

    Secret --> Fingerprint
    SecretUsage --> Fingerprint
    SecretUsage --> SecretUsageId
    SecretUsage --> SecretConsumer
    SeedSecret --> SeedBytes
    MnemonicSecret --> MnemonicWords
    MnemonicSecret --> Passphrase
```

### Application Layer - Ports (Interfaces)

Contracts that define dependencies on external systems:

```mermaid
classDiagram
    class SecretStorePort {
        <<interface>>
        +save(secret)
        +load(fingerprint) Secret
        +loadAll() List~Secret~
        +exists(fingerprint) bool
        +delete(fingerprint)
    }

    class SecretUsageRepositoryPort {
        <<interface>>
        +add(fingerprint, consumer) SecretUsage
        +isUsed(fingerprint) bool
        +getByConsumer(consumer) List~SecretUsage~
        +getAll() List~SecretUsage~
        +deleteById(id)
        +deleteByConsumer(consumer)
    }

    class MnemonicGeneratorPort {
        <<interface>>
        +generateMnemonic() MnemonicWords
    }

    class SecretCryptoPort {
        <<interface>>
        +getFingerprintFromMnemonic(mnemonicWords, passphrase) Fingerprint
        +getFingerprintFromSeed(seedBytes) Fingerprint
    }

    class LegacySeedSecretStorePort {
        <<interface>>
        +loadAll() List~SeedSecret~
    }

    class SecretUsage {
        +id: SecretUsageId
        +fingerprint: Fingerprint
        +consumer: SecretConsumer
    }

    class Fingerprint {
        +value: String
    }

    class SecretConsumer {
        <<sealed>>
    }

    class MnemonicWords {
        +value: List~String~
    }

    class SecretUsageId {
        +value: int
    }

    SecretUsageRepositoryPort --> SecretUsage
    SecretUsageRepositoryPort --> Fingerprint
    SecretUsageRepositoryPort --> SecretConsumer
    SecretUsageRepositoryPort --> SecretUsageId
    SecretCryptoPort --> Fingerprint
    SecretCryptoPort --> MnemonicWords
    MnemonicGeneratorPort --> MnemonicWords
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
    class DeregisterSecretUsageUseCase {
        +execute(command)
    }

    class GetSecretUsagesByConsumerUseCase {
        +execute(query) Result
    }

    class DeregisterSecretUsagesOfConsumerUseCase {
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

    DeregisterSecretUsageUseCase ..> SecretUsageRepositoryPort
    GetSecretUsagesByConsumerUseCase ..> SecretUsageRepositoryPort
    DeregisterSecretUsagesOfConsumerUseCase ..> SecretUsageRepositoryPort
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
    class GetSecretUsagesByConsumerUseCase
    class DeregisterSecretUsageUseCase
    class DeregisterSecretUsagesOfConsumerUseCase
    class LoadAllStoredSecretsUseCase
    class ListUsedSecretsUseCase
    class DeleteSecretUseCase
    class LoadLegacySecretsUseCase

    %% Public Facade (for other features)
    class SecretsFacade {
        +createNewMnemonicForWallet(passphrase, walletId)
        +importMnemonicForWallet(mnemonicWords, passphrase, walletId)
        +getSecret(fingerprint)
        +getSecretUsagesByWalletConsumer(walletId)
        +deregisterUsage(usageId)
        +deregisterUsagesOfWalletConsumer(walletId)
    }

    SecretsFacade ..> CreateNewMnemonicSecretUseCase
    SecretsFacade ..> ImportMnemonicSecretUseCase
    SecretsFacade ..> GetSecretUseCase
    SecretsFacade ..> GetSecretUsagesByConsumerUseCase
    SecretsFacade ..> DeregisterSecretUsageUseCase
    SecretsFacade ..> DeregisterSecretUsagesOfConsumerUseCase

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

- **Entities**: Core business domain objects with rules (`Secret`, `SeedSecret`, `MnemonicSecret`, `SecretUsage`)
  - Located in `/lib/features/secrets/domain/entities/`
- **Value Objects**: Immutable types with validation (`Fingerprint`, `SecretUsageId`, `SecretConsumer`, `MnemonicWords`, `Passphrase`, `SeedBytes`)
  - Located in `/lib/features/secrets/domain/value_objects/`
  - Enforce domain constraints (e.g., fingerprint must be 8 hex chars, mnemonic must be 12/15/18/21/24 words)
- **Domain Errors**: Domain-specific exceptions (`InvalidFingerprintFormatError`, `InvalidMnemonicWordCountError`, etc.)

### Application Layer

- **Use Cases**: Orchestration and business rule enforcement (10 use cases)
  - Coordinate multiple ports to fulfill application requirements
  - Enforce business rules (e.g., "cannot delete secret if in use")
  - Implement application workflows (e.g., create → store → register usage as atomic operation)
  - Registration now happens within import/create use cases (no separate RegisterSecretUsageUseCase)
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

    F->>UC: execute(CreateNewMnemonicSecretCommand.forWallet())
    UC->>MG: generateMnemonic()
    MG-->>UC: MnemonicWords
    UC->>SC: getFingerprintFromMnemonic(words, passphrase)
    SC-->>UC: Fingerprint
    Note over UC: Create MnemonicSecret with value objects
    UC->>SS: save(secret)
    UC->>SR: add(fingerprint, WalletConsumer)
    SR-->>UC: SecretUsage
    UC-->>F: Result(MnemonicSecret)
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

    F->>UC: execute(ImportMnemonicSecretCommand.forWallet())
    Note over UC: Validate MnemonicWords, Passphrase
    UC->>SC: getFingerprintFromMnemonic(words, passphrase)
    SC-->>UC: Fingerprint
    Note over UC: Create MnemonicSecret with value objects
    UC->>SS: save(secret)
    UC->>SR: add(fingerprint, WalletConsumer)
    SR-->>UC: SecretUsage
    UC-->>F: Result(Fingerprint)
```

### Importing a Seed Secret (bytes)

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as ImportSeedSecretUseCase
    participant SC as SecretCryptoPort
    participant SS as SecretStorePort
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(ImportSeedSecretCommand)
    Note over UC: Validate SeedBytes
    UC->>SC: getFingerprintFromSeed(seedBytes)
    SC-->>UC: Fingerprint
    Note over UC: Create SeedSecret with value objects
    UC->>SS: save(secret)
    UC->>SR: add(fingerprint, consumer)
    SR-->>UC: SecretUsage
    UC-->>F: Result(Fingerprint)
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

### Getting Secret Usages by Consumer

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as GetSecretUsagesByConsumerUseCase
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(GetSecretUsagesByConsumerQuery.byWallet())
    Note over UC: Create WalletConsumer from walletId
    UC->>SR: getByConsumer(WalletConsumer)
    SR-->>UC: List<SecretUsage>
    UC-->>F: Result(List<SecretUsage>)
```

### Deregistering All Usages of a Consumer

```mermaid
sequenceDiagram
    participant F as SecretsFacade
    participant UC as DeregisterSecretUsagesOfConsumerUseCase
    participant SR as SecretUsageRepositoryPort

    F->>UC: execute(DeregisterSecretUsagesOfConsumerCommand.ofWallet())
    Note over UC: Create WalletConsumer from walletId
    UC->>SR: deleteByConsumer(WalletConsumer)
    SR-->>UC: Success
    UC-->>F: Success
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
- **BLoC Pattern**: Transform data between Application and Presentation layers
- **Domain Boundary Protection**: Entities and Value Objects cannot be constructed outside domain/application layers (see Business Rules)
- **Error Boundary Pattern**: Each layer catches and transforms errors from lower layers, preventing error leakage (see Error Handling Strategy)

## Key Business Rules

1. **Secret Deletion Protection**: A secret cannot be deleted if it has registered usages
2. **Atomic Registration**: Secret creation/import and usage registration happen atomically within the same use case
3. **Fingerprint Identity**: Secrets are uniquely identified by their BIP32 fingerprint (4 bytes, 8 hex chars)
4. **Value Object Validation**: Domain constraints are enforced at creation time:
   - Fingerprint: Must be exactly 8 hexadecimal characters
   - MnemonicWords: Must be 12, 15, 18, 21, or 24 words
   - Passphrase: Maximum 256 characters
   - SeedBytes: Must be 16, 32, or 64 bytes (128, 256, or 512 bits)
5. **Consumer-Based Tracking**: Usages are tracked by consumer (WalletConsumer, Bip85Consumer) rather than generic purpose/reference strings
6. **Legacy Support**: Old secrets can be loaded and migrated through dedicated use case
7. **Secure Storage**: Secrets are stored separately from usage metadata (secrets in secure storage, usages in SQLite)
8. **Domain Boundary Protection**: Business rules are enforced exclusively within the domain and application layers:
   - **Input Constraint**: Use case commands/queries, facade methods, and BLoC events accept only primitive types (String, int, List\<String\>, etc.), never Entities or Value Objects
   - **Output Freedom**: Use cases, facade methods, and BLoC state can return Entities and Value Objects
   - **Validation Location**: All domain validation happens when Value Objects are constructed within use cases
   - **Prevents Business Rule Bypass**: External callers cannot construct invalid domain objects or bypass validation rules

## Error Handling Strategy

The Secrets feature implements a strict error boundary pattern where each layer catches and transforms errors from lower layers. This prevents error leakage and ensures each layer uses its own error vocabulary appropriate for its consumers.

### Error Layer Hierarchy

```mermaid
graph TD
    D[Domain Errors<br/>SecretsDomainError] --> A[Application Errors<br/>SecretsApplicationError]
    A --> F[Facade Errors<br/>SecretsFacadeError]
    A --> P[Presentation Errors<br/>SecretsPresentationError]

    style D fill:#ffcccc,stroke:#cc0000,stroke-width:2px,color:#000
    style A fill:#cce5ff,stroke:#0066cc,stroke-width:2px,color:#000
    style F fill:#ccffcc,stroke:#00cc00,stroke-width:2px,color:#000
    style P fill:#ffffcc,stroke:#cccc00,stroke-width:2px,color:#000
```

### Layer-by-Layer Error Handling

#### 1. Domain Layer (`SecretsDomainError`)

**Purpose**: Enforce domain invariants and validation rules

**When Thrown**: When Value Objects are constructed with invalid data

---

#### 2. Application Layer (`SecretsApplicationError`)

**Purpose**: Distinguish user input errors from infrastructure failures, use application-specific vocabulary

**Key Principle**: Use cases NEVER let domain errors escape. They catch all `SecretsDomainError` exceptions and transform them to `SecretsApplicationError`.

---

#### 3. Facade Layer (`SecretsFacadeError`)

**Purpose**: Provide clean error API for external features, hide internal implementation details

**Key Principle**: Facade NEVER lets application errors escape. All `SecretsApplicationError` exceptions are caught and transformed to `SecretsFacadeError`.

---

#### 4. Presentation Layer (`SecretsPresentationError`)

**Purpose**: Provide user-friendly error messages for UI display

**Key Principle**: Presentation NEVER lets application errors escape. All `SecretsApplicationError` exceptions are caught and transformed to `SecretsPresentationError` with user-friendly messages.

---

### Error Flow Example

**Scenario**: User imports a mnemonic with 11 words (invalid)

```mermaid
sequenceDiagram
    participant UI as UI
    participant BLoC as SecretsViewBloc
    participant UC as ImportMnemonicUseCase
    participant VO as MnemonicWords (Value Object)

    UI->>BLoC: Import mnemonic (11 words)
    BLoC->>UC: execute(command)
    UC->>VO: new MnemonicWords(11 words)

    Note over VO: Domain Layer Boundary
    VO-->>UC: ❌ InvalidMnemonicWordCountError(actualCount: 11)

    Note over UC: Application Layer Boundary<br/>Catch & Transform
    UC-->>BLoC: ❌ InvalidMnemonicInputError(11)

    Note over BLoC: Presentation Layer Boundary<br/>Catch & Transform
    BLoC-->>UI: ❌ InvalidMnemonicPresentationError(11)<br/>"Invalid recovery phrase: Expected 12, 15, 18, 21,<br/>or 24 words but got 11 words. Please check<br/>your input and try again."

    UI->>UI: Display error message to user
```

### Benefits of This Strategy

1. **Error Isolation**: Errors are contained within layer boundaries and never leak upward
2. **Appropriate Vocabulary**: Each layer uses terminology appropriate for its consumers
3. **User Experience**: End users see friendly, actionable messages
4. **Developer Experience**: External features get clear, documented error types
5. **Debugging**: Error chain preserved via `cause` field for troubleshooting
6. **Flexibility**: Layers can group, split, or transform errors differently based on their needs
7. **Type Safety**: Exhaustive pattern matching ensures all error cases are handled
