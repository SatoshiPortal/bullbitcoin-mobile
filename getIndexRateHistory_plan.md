# getIndexRateHistory Implementation Plan

## Overview
Implement rate history feature with API integration, SQLite caching, and incremental updates.

## Components to Create/Modify

### 1. Domain Layer - Enums & Entities

#### 1.1 Create Enums (if not existing)
**File:** `lib/core/exchange/domain/entity/rate_history.dart`

- Reuse existing `FiatCurrency` enum from `lib/core/exchange/domain/entity/order.dart`
  - Values: `USD`, `CAD`, `CRC`, `EUR`, `MXN`, `ARS`
  - Note: Only fiat currencies against BTC
  - For INR (if needed), extend `FiatCurrency` enum or handle as special case

- `RateTimelineInterval` enum:
  - Values: `hour`, `day`, `week`
  - String values matching API spec: `"hour"`, `"day"`, `"week"`

#### 1.2 Create Entities
**File:** `lib/core/exchange/domain/entity/rate_history.dart`

- `Rate` entity (freezed):
  - `fromCurrency`: `FiatCurrency?` (reuse existing enum)
  - `toCurrency`: `String?` (always "BTC")
  - `marketPrice`: `double?` (converted from int/precision)
  - `price`: `double?` (converted from int/precision)
  - `priceCurrency`: `String?`
  - `precision`: `int?`
  - `indexPrice`: `double?` (converted from int/precision)
  - `userPrice`: `double?` (converted from int/precision)
  - `createdAt`: `DateTime?` (converted from ISO string)

- `RateHistory` entity (freezed):
  - `fromCurrency`: `FiatCurrency?` (reuse existing enum)
  - `toCurrency`: `String?` (always "BTC")
  - `precision`: `int?`
  - `interval`: `RateTimelineInterval?`
  - `rates`: `List<Rate>?`

### 2. Data Layer - Models

#### 2.1 Create Models
**File:** `lib/core/exchange/data/models/rate_history_model.dart`

- `RateModel` (freezed with json_serializable):
  - All fields as optional (matching API spec)
  - `fromJson` factory
  - `toEntity()` method: converts to `Rate` entity, handles precision division, DateTime parsing
  - `fromEntity()` method: converts from entity to model

- `RateHistoryModel` (freezed with json_serializable):
  - All fields as optional (matching API spec, including `interval` from API)
  - `fromJson` factory
  - `toEntity()` method: converts to `RateHistory` entity, converts interval string to enum
  - `fromEntity()` method: converts from entity to model, converts interval enum to string

#### 2.2 Create Request Payload Model
**File:** `lib/core/exchange/data/models/rate_history_request_model.dart`

- `RateHistoryRequestModel`:
  - `fromCurrency`: `String` (required)
  - `toCurrency`: `String` (required)
  - `fromDate`: `String?` (milliseconds since epoch)
  - `toDate`: `String?` (milliseconds since epoch)
  - `interval`: `String` (required, one of: "hour", "day", "week")
  - `toApiParams()`: returns Map for API request

### 3. Data Source Layer

#### 3.1 Add API Method
**File:** `lib/core/exchange/data/datasources/bullbitcoin_api_datasource.dart`

- Add method:
  ```dart
  Future<RateHistoryModel> getIndexRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    DateTime? fromDate,
    DateTime? toDate,
  })
  ```
  - Uses `_pricePath` endpoint
  - JSON-RPC 2.0 format
  - Accepts `interval` parameter ("hour", "day", "week")
  - Handles precision conversion in response parsing
  - Returns `RateHistoryModel`

#### 3.2 Create Local Datasource
**File:** `lib/core/exchange/data/datasources/local_rate_history_datasource.dart`

- `LocalRateHistoryDatasource`:
  - `storeRates(List<RateModel> rates, String fromCurrency, String toCurrency, String interval)`: Store rates in SQLite
    - **Overwrite strategy**: Delete existing records in date range before inserting (or use unique constraint)
  - `getLatestRateDate(String fromCurrency, String toCurrency, String interval)`: Get latest `createdAt` from DB for specific interval
  - `getRates(String fromCurrency, String toCurrency, String interval, DateTime? fromDate, DateTime? toDate)`: Query rates from DB filtered by interval
  - `cleanupOldRates(String fromCurrency, String toCurrency, Duration maxAge)`: Delete records older than maxAge (4 years = Duration(days: 1460))
  - `deleteRates(String fromCurrency, String toCurrency, String interval)`: Delete old rates for specific interval (optional cleanup)

### 4. SQLite Table

#### 4.1 Create Table
**File:** `lib/core/storage/tables/rate_history_table.dart`

- `RateHistory` table (Drift):
  - `id`: `IntColumn` (auto-increment primary key)
  - `fromCurrency`: `TextColumn` (indexed, stores FiatCurrency code)
  - `toCurrency`: `TextColumn` (indexed, always "BTC")
  - `interval`: `TextColumn` (indexed, stores: "hour", "day", "week")
  - `marketPrice`: `RealColumn` (nullable, stored as double)
  - `price`: `RealColumn` (nullable, stored as double)
  - `priceCurrency`: `TextColumn` (nullable)
  - `precision`: `IntColumn` (nullable, original precision from API)
  - `indexPrice`: `RealColumn` (nullable, stored as double)
  - `userPrice`: `RealColumn` (nullable, stored as double)
  - `createdAt`: `TextColumn` (indexed, ISO 8601 string in UTC)
  - Composite index on: `(fromCurrency, toCurrency, interval, createdAt)`
  - Unique constraint on: `(fromCurrency, toCurrency, interval, createdAt)` for overwrite strategy
  - Note: Single table stores all intervals, filtered by `interval` column

#### 4.2 Update Database
**File:** `lib/core/storage/sqlite_database.dart`
- Add `RateHistory` to `@DriftDatabase` tables list
- Increment `schemaVersion` to 10

#### 4.3 Create Migration
**File:** `lib/core/storage/migrations/schema_9_to_10.dart`
- Create `RateHistory` table
- Add indexes

### 5. Repository Layer

#### 5.1 Update Repository Interface
**File:** `lib/core/exchange/domain/repositories/exchange_rate_repository.dart`

- Add method:
  ```dart
  Future<RateHistory> getIndexRateHistory({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    DateTime? fromDate,
    DateTime? toDate,
  });
  ```
  - `interval`: One of "hour", "day", "week"
  - Fetches and stores data for single interval

- Add method for chart UI (all intervals):
  ```dart
  Future<Map<String, RateHistory>> getAllIntervalsRateHistory({
    required String fromCurrency,
    required String toCurrency,
    DateTime? fromDate,
    DateTime? toDate,
  });
  ```
  - Returns Map<interval, RateHistory> for all intervals
  - Fetches all intervals in parallel (or sequentially)
  - Ensures all intervals are available for chart toggling

#### 5.2 Update Repository Implementation
**File:** `lib/core/exchange/data/repository/exchange_rate_repository_impl.dart`

- Add `LocalRateHistoryDatasource` dependency
- Implement `getIndexRateHistory`:
  1. Check local DB for existing rates (filtered by `fromCurrency`, `toCurrency`, `interval`)
  2. Determine date range to fetch from API:
     - If no local data: fetch from `fromDate` (or 1 year ago) to `toDate` (or now)
     - If local data exists: fetch from `latestDate + 1 interval` to `toDate` (or now)
       - For "hour": +1 hour
       - For "day": +1 day
       - For "week": +1 week
  3. If date range is valid, call API with specified `interval`
  4. Store new rates in local DB using overwrite strategy:
     - Delete existing records in fetched date range, OR
     - Use `insertOnConflictUpdate` with unique constraint
  5. Query all rates from local DB (including newly inserted)
  6. Return `RateHistory` entity
  7. Filter by `fromDate`/`toDate` if provided (handled in UI layer for display ranges)

- Implement `getAllIntervalsRateHistory`:
  1. For each interval ("hour", "day", "week"):
     - Call `getIndexRateHistory` for that interval
     - Store result in map
  2. Execute in parallel using `Future.wait()` for better performance
  3. Return Map<interval, RateHistory>
  4. This ensures all intervals are fetched and cached for instant toggling

### 6. Use Case Layer

#### 6.1 Create Use Cases
**File:** `lib/core/exchange/domain/usecases/get_index_rate_history_usecase.dart`

- `GetIndexRateHistoryUsecase`:
  - Dependencies: `ExchangeRateRepository` (mainnet/testnet), `SettingsRepository`
  - `execute()`:
    - Get current environment from settings
    - Select appropriate repository
    - Call repository `getIndexRateHistory` method
    - Return `RateHistory` entity

**File:** `lib/core/exchange/domain/usecases/get_all_intervals_rate_history_usecase.dart`

- `GetAllIntervalsRateHistoryUsecase`:
  - Dependencies: `ExchangeRateRepository` (mainnet/testnet), `SettingsRepository`
  - `execute()`:
    - Get current environment from settings
    - Select appropriate repository
    - Call repository `getAllIntervalsRateHistory` method
    - Return `Map<String, RateHistory>` (key = interval string)
    - Use this for chart UI to ensure all intervals are available

### 7. Locator Registration

#### 7.1 Update Exchange Locator
**File:** `lib/core/exchange/exchange_locator.dart`

- Register `LocalRateHistoryDatasource` in `registerDatasources()`
- Update `ExchangeRateRepositoryImpl` registration to include local datasource
- Register `GetIndexRateHistoryUsecase` in `registerUseCases()`
- Register `GetAllIntervalsRateHistoryUsecase` in `registerUseCases()`

## Implementation Details

### Date Handling
- **Decision: Use UTC consistently**
- Store dates as ISO 8601 strings in SQLite (per memory: dates as strings in models)
- Convert to `DateTime` in entity layer (always UTC)
- API expects milliseconds since epoch as strings (UTC)
- All date comparisons and queries use UTC
- UI can convert to local timezone for display only

### Precision Conversion
- **Decision: Store as `double` (converted values)**
- API returns prices as integers (e.g., 12345678 with precision 2 = 123456.78)
- Convert in model's `toEntity()`: `price / pow(10, precision)`
- Store converted `double` values in SQLite
- **Rationale**: Easier to query, no precision handling needed in queries, simpler calculations

### Incremental Updates
- Query DB for latest `createdAt` per `(fromCurrency, toCurrency, interval)` combination
- Only fetch from API for missing date ranges with the specified `interval`
- Calculate next fetch date based on interval:
  - "hour": latestDate + 1 hour
  - "day": latestDate + 1 day
  - "week": latestDate + 1 week
- Merge results before returning

### Chart UI Strategy (All Intervals)
- **Initial Load**: Use `getAllIntervalsRateHistory` to fetch all intervals in parallel
  - Ensures all intervals are available for instant toggling
  - May take longer on first load, but provides smooth UX
- **Subsequent Loads**: Use incremental updates per interval
- **Toggling**: Query from local DB only (no API calls needed)
  - All intervals are already cached after initial load
  - Instant switching between intervals
- **Data Persistence**: All intervals stored in same table, filtered by `interval` column
- **UI Date Range Display**:
  - "hour" interval: Show last 24 hours (1 day) - filter in UI
  - "day" interval: Show last 30 days (1 month) - filter in UI
  - "week" interval: Show last 54 weeks (1 year) - filter in UI
  - Repository stores all available data (up to 4 years)
  - UI layer filters data for display based on selected interval

### Error Handling
- Handle API errors gracefully
- Fall back to local data if API fails
- Log warnings for missing data

## File Structure Summary

```
lib/core/exchange/
├── domain/
│   ├── entity/
│   │   └── rate_history.dart (NEW - enums + entities)
│   ├── repositories/
│   │   └── exchange_rate_repository.dart (MODIFY - add method)
│   └── usecases/
│       └── get_index_rate_history_usecase.dart (NEW)
├── data/
│   ├── datasources/
│   │   ├── bullbitcoin_api_datasource.dart (MODIFY - add method)
│   │   └── local_rate_history_datasource.dart (NEW)
│   ├── models/
│   │   ├── rate_history_model.dart (NEW)
│   │   └── rate_history_request_model.dart (NEW)
│   └── repository/
│       └── exchange_rate_repository_impl.dart (MODIFY - add implementation)

lib/core/storage/
├── tables/
│   └── rate_history_table.dart (NEW)
├── migrations/
│   └── schema_9_to_10.dart (NEW)
└── sqlite_database.dart (MODIFY - add table, increment version)
```

## Reusable Structures

1. **FiatCurrency enum**: Can extend or create separate `RateCurrency` enum (includes BTC, LBTC, LNBTC)
2. **Existing precision handling**: Similar to `getPrice()` method in datasource
3. **Repository pattern**: Follow same pattern as `ExchangeRateRepositoryImpl`
4. **Use case pattern**: Follow same pattern as `GetExchangeFundingDetailsUsecase`
5. **Local datasource pattern**: Follow same pattern as `LocalPayjoinDatasource`
6. **Table pattern**: Follow same pattern as `Swaps` table

## Storage and Performance Analysis

### Records Per Year (per currency pair, all intervals):
- **"hour"**: 365 days × 24 hours = **8,760 records/year**
- **"day"**: 365 days = **365 records/year**
- **"week"**: ~52 weeks = **52 records/year**
- **Total**: **9,177 records/year per currency pair**

### Storage Per Record:
- id: 4 bytes (int, primary key)
- fromCurrency: ~4 bytes (text, indexed)
- toCurrency: ~4 bytes (text, indexed)
- interval: ~6 bytes (text, indexed)
- marketPrice: 8 bytes (real)
- price: 8 bytes (real)
- priceCurrency: ~4 bytes (text)
- precision: 4 bytes (int)
- indexPrice: 8 bytes (real)
- userPrice: 8 bytes (real)
- createdAt: ~20 bytes (text, ISO string, indexed)
- SQLite row overhead: ~20-30 bytes
- **Total**: ~**120-150 bytes per record**

### Storage Estimates:

**1 Year of Data:**
- 1 currency pair: 9,177 × 150 bytes = **1.38 MB**
- With indexes (~40% overhead): **~1.9-2.0 MB per currency pair**
- 5 currency pairs: **~9.5-10 MB**
- 10 currency pairs: **~19-20 MB**

**4 Years of Data:**
- 1 currency pair: 36,708 × 150 bytes = **5.5 MB**
- With indexes: **~7.7-8.0 MB per currency pair**
- 5 currency pairs: **~38.5-40 MB**
- 10 currency pairs: **~77-80 MB**

### Database Read Performance:

**With composite index `(fromCurrency, toCurrency, interval, createdAt)`:**
- **1 year (9K records)**: Query time **< 5ms** (indexed lookup)
- **4 years (37K records)**: Query time **< 10ms** (indexed lookup)
- **10 years (92K records)**: Query time **< 20ms** (indexed lookup)

**Query pattern**: `WHERE fromCurrency = ? AND toCurrency = ? AND interval = ? AND createdAt BETWEEN ? AND ?`
- Uses composite index efficiently
- Only scans relevant date range
- Performance scales logarithmically with data size

### Recommended Retention Policy:

**Decision: Keep 4 years of data**

**Rationale:**
1. **Storage**: 4 years = ~7.7-8.0 MB per currency pair (very reasonable for mobile)
2. **Performance**: Query times remain < 10ms (excellent UX)
3. **Use case**: Provides good historical context for charts
4. **Mobile constraints**: Storage is very manageable at this level

**Implementation:**
- Store up to 4 years of data
- Auto-cleanup: Delete records older than 4 years on insert
- Or: Periodic cleanup job (e.g., monthly)
- Keep "day" and "week" intervals longer if needed (they're small)

### Cleanup Strategy:

Add to `LocalRateHistoryDatasource`:
```dart
Future<void> cleanupOldRates({
  required String fromCurrency,
  required String toCurrency,
  required Duration maxAge, // Duration(days: 1460) for 4 years
}) async {
  final cutoffDate = DateTime.now().subtract(maxAge).toUtc();
  // Delete records older than cutoffDate (UTC)
}
```

**Overwrite Strategy Implementation:**
```dart
Future<void> storeRates(...) async {
  // Option 1: Delete existing records in date range, then insert
  // Option 2: Use unique constraint on (fromCurrency, toCurrency, interval, createdAt)
  //           with insertOnConflictUpdate
  // Recommended: Option 2 (more efficient, atomic operation)
}
```

## Decisions Made:

1. **Currency Enum**: Reuse existing `FiatCurrency` enum (USD, CAD, CRC, EUR, MXN, ARS)
   - `toCurrency` always "BTC" (stored as String)
   - If INR support needed later, extend `FiatCurrency` enum

2. **Price Storage**: Store as `double` (converted from integer/precision)
   - Easier to query and calculate
   - Conversion happens once on insert
   - No precision handling needed in queries

3. **Data Retention**: Keep 4 years of data
   - ~7.7-8.0 MB per currency pair
   - Query times < 10ms
   - Good historical context

4. **Timezone**: Use UTC consistently
   - All dates stored in UTC
   - Convert to local timezone in UI layer only
   - API uses UTC (milliseconds since epoch)

5. **Overlapping Data**: Overwrite local DB
   - Delete existing records in date range before inserting new ones
   - Or use `insertOnConflictUpdate` with unique constraint on (fromCurrency, toCurrency, interval, createdAt)
   - API data is always authoritative

## Additional Dependencies

- **fl_chart**: Add to `pubspec.yaml` for chart UI
  ```yaml
  fl_chart: ^0.69.0  # or latest version
  ```

## Database Design Decision: Single Table vs Separate Tables

**Decision: Single table with `interval` column**

**Rationale:**
- Matches existing codebase patterns (e.g., `Swaps` table with `direction` enum column)
- Less code duplication (single table structure)
- Easier to maintain and extend (add new intervals without schema changes)
- Simpler migrations (one table to manage)
- Efficient queries with composite index: `(fromCurrency, toCurrency, interval, createdAt)`
- All intervals share the same data structure
- **Perfect for chart UI**: All intervals in one table, easy to query and toggle

**Alternative (not chosen):**
- Separate tables per interval would require:
  - 3 tables: `rate_history_hour`, `rate_history_day`, `rate_history_week`
  - Code duplication for each table
  - More complex migrations
  - Harder to query across intervals if needed in future
  - More complex to fetch all intervals for chart UI

## Chart UI Integration Strategy

**Goal**: Enable smooth interval toggling in fl_chart with all data pre-loaded

**Approach**:
1. **Initial Load**: `GetAllIntervalsRateHistoryUsecase` fetches all intervals in parallel
   - User opens chart screen → fetch all intervals for date range
   - All intervals stored in DB for instant access
   
2. **Toggling**: Query from local DB only
   - No API calls when user switches intervals
   - Instant response (data already cached)
   
3. **Incremental Updates**: Per-interval updates
   - Background sync or on-demand updates
   - Each interval updated independently
   
4. **Data Structure for Chart**:
   - `Map<String, RateHistory>` where key = interval
   - Chart widget can switch between intervals instantly
   - fl_chart receives `List<Rate>` for selected interval

**Benefits**:
- Smooth UX: No loading when toggling intervals
- Efficient: Parallel fetching on initial load
- Persistent: All data cached in SQLite
- Flexible: Can still fetch single interval if needed

## UI Implementation Plan

### Chart UI Location
- **Trigger**: User clicks on fiat balance (e.g., "119.19 CAD") in `WalletHomeTopSection`
- **Location**: Replace content in top section (red background area) with chart
- **File**: `lib/features/wallet/ui/widgets/wallet_home_top_section.dart`

### UI Behavior

**When Chart is Hidden (Default State):**
- Show normal wallet home UI:
  - BTC balance
  - Fiat balance (tappable)
  - Eye toggle
  - App bar icons (refresh, settings)
  - Red background image

**When Chart is Shown:**
- **Top Section Transformation**:
  - Hide all icons (refresh, settings, eye toggle)
  - Hide balance text (BTC and fiat)
  - Change background from red image to **full black**
  - Show interactive price chart
  - Show back button in top left corner
  - Slide in animation when transitioning

**Chart Features:**
- **Background**: Full black (`Colors.black`)
- **Chart Line**: White color
- **Interactive**:
  - User can tap anywhere on graph to show red dot
  - Red dot can be dragged along curve
  - Show price at that point when dragging (tooltip/overlay)
- **Minimal Design**: No axes, no labels, just the line and interactive dot

**Bottom Section (Below Chart):**
- Interval toggle buttons: "Hour", "Day", "Week"
- Bull logo in center
- Back button (or use top left back button)

**Data Fetching Strategy:**
- On home page load: Always fetch all intervals in background
- When user clicks fiat balance:
  - First: Show data from local DB (instant)
  - Then: Update in background from API
- Subsequent interval toggles: Instant (data already cached)

**UI Date Range Display (per interval):**
- **"hour" interval**: Show last 24 hours (1 day) of data
- **"day" interval**: Show last 30 days (1 month) of data
- **"week" interval**: Show last 54 weeks (1 year) of data
- Filter data in UI layer based on selected interval
- Repository stores all available data (up to 4 years)

### Implementation Components

**New Files to Create:**
1. `lib/features/wallet/ui/widgets/price_chart_widget.dart` - Main chart widget
2. `lib/features/wallet/presentation/bloc/price_chart_bloc.dart` - State management for chart
3. `lib/features/wallet/presentation/bloc/price_chart_state.dart` - Chart state
4. `lib/features/wallet/presentation/bloc/price_chart_event.dart` - Chart events

**Files to Modify:**
1. `lib/features/wallet/ui/widgets/wallet_home_top_section.dart` - Add chart toggle
2. `lib/features/wallet/ui/widgets/home_fiat_balance.dart` - Make tappable
3. `lib/features/wallet/ui/screens/wallet_home_screen.dart` - Initialize chart data fetching

**State Management:**
- Use BLoC pattern (consistent with existing codebase)
- Chart state: `showChart`, `selectedInterval`, `chartData`, `selectedPoint`
- Events: `ToggleChart`, `SelectInterval`, `SelectPoint`, `LoadChartData`

**Chart Library:**
- Use `fl_chart` package
- Line chart with touch interaction
- Custom painter for red dot and dragging

