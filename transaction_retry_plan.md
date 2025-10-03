# Transaction Building Retry Logic Implementation Plan

## Problem Statement
There is a problem in this project with all flows where we build transactions - send, sell, pay and swap. We need to add retry logic in the prepareLiquid/Bitcoin send usecases and retry at least once, and if it errors twice only then return the error.

## Transaction Building Flows Identified

I found that transaction building happens in **4 main flows** across the app:

### 1. **Send Flow** (`lib/features/send/presentation/bloc/send_cubit.dart`)
- **Bitcoin**: Uses `PrepareBitcoinSendUsecase` in `createTransaction()` method (lines 1081-1162)
- **Liquid**: Uses `PrepareLiquidSendUsecase` in `createTransaction()` method (lines 1040-1079)

### 2. **Sell Flow** (`lib/features/sell/presentation/bloc/sell_bloc.dart`)
- **Fee calculation**: Uses both usecases in `_onWalletSelected()` (lines 206-231)
- **Payment execution**: Uses both usecases in `_onSendPaymentConfirmed()` (lines 395-443)

### 3. **Pay Flow** (`lib/features/pay/presentation/pay_bloc.dart`)
- **Fee calculation**: Uses both usecases in `_onWalletSelected()` (lines 339-364)
- **Payment execution**: Uses both usecases in `_onSendPaymentConfirmed()` (lines 550-575)

### 4. **Swap Flow** (`lib/features/swap/presentation/swap_bloc.dart`)
- **Bitcoin**: Uses `PrepareBitcoinSendUsecase` in `buildAndSignOnchainTransaction()` (lines 558-587)
- **Liquid**: Uses `PrepareLiquidSendUsecase` in `buildAndSignOnchainTransaction()` (lines 591-616)

## Current Usecase Structure

Both usecases (`PrepareBitcoinSendUsecase` and `PrepareLiquidSendUsecase`) are located in:
- `lib/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart`
- `lib/features/send/domain/usecases/prepare_liquid_send_usecase.dart`

They both follow the same pattern:
1. Validate inputs
2. Call repository methods to build transactions
3. Catch exceptions and wrap them in custom exception types
4. Return the result

## Retry Logic Implementation Plan

### **Option 1: Modify Usecases Directly (Recommended)**
Add retry logic directly in the `execute()` methods of both usecases:

**Advantages:**
- Centralized retry logic
- No changes needed in blocs
- Consistent retry behavior across all flows
- Easy to maintain and test

**Implementation:**
1. Add retry counter and delay logic in both usecases
2. Retry up to 2 times (3 total attempts)
3. Add exponential backoff or fixed delay between retries
4. Only retry on specific exceptions (not validation errors)

### **Option 2: Create Retry Wrapper Usecases**
Create new wrapper usecases that implement retry logic:

**Advantages:**
- Keeps original usecases unchanged
- More flexible retry configuration
- Can be reused for other usecases

**Disadvantages:**
- More complex dependency injection
- Need to update all bloc constructors
- More files to maintain

### **Option 3: Add Retry Logic in Blocs**
Add retry logic in each bloc where transactions are built:

**Disadvantages:**
- Code duplication across 4 different blocs
- Inconsistent implementation
- Harder to maintain

## Recommended Implementation Plan

I recommend **Option 1** - modifying the usecases directly. Here's the detailed plan:

### Phase 1: Create Retry Utility
1. Create a retry utility class with configurable retry attempts and delays
2. Add specific exception types that should trigger retries vs immediate failures

### Phase 2: Modify PrepareBitcoinSendUsecase
1. Add retry logic to the `execute()` method
2. Retry on network-related exceptions, not validation errors
3. Add logging for retry attempts

### Phase 3: Modify PrepareLiquidSendUsecase
1. Add identical retry logic to the `execute()` method
2. Ensure consistent behavior with Bitcoin usecase

### Phase 4: Testing
1. Test retry logic in all 4 flows (send, sell, pay, swap)
2. Verify that validation errors don't trigger retries
3. Verify that network errors trigger retries appropriately

## Files to Modify

### Core Usecases
- `lib/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart`
- `lib/features/send/domain/usecases/prepare_liquid_send_usecase.dart`

### Blocs Using These Usecases
- `lib/features/send/presentation/bloc/send_cubit.dart`
- `lib/features/sell/presentation/bloc/sell_bloc.dart`
- `lib/features/pay/presentation/pay_bloc.dart`
- `lib/features/swap/presentation/swap_bloc.dart`

### Locator Files (if creating new usecases)
- `lib/features/send/send_locator.dart`
- `lib/features/pay/pay_locator.dart`
- `lib/features/sell/sell_locator.dart`
- `lib/features/swap/swap_locator.dart`

## Implementation Details

### Retry Logic Specifications
- **Max Attempts**: 3 total attempts (2 retries)
- **Retry Delay**: 1 second between attempts
- **Retry Conditions**: Network errors, timeout errors, server errors
- **No Retry**: Validation errors, authentication errors, insufficient funds

### Exception Handling
- Log each retry attempt with attempt number
- Log final failure after all retries exhausted
- Preserve original exception type and message
- Add retry context to exception messages

### Testing Strategy
- Unit tests for retry logic in usecases
- Integration tests for each flow (send, sell, pay, swap)
- Mock network failures to test retry behavior
- Verify no retries on validation errors
