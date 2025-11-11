# getIndexRateHistory API Specification

## API Endpoint

**Method:** `POST`  
**Path:** `{baseURL}/public/price`  
**RPC Method:** `getIndexRateHistory`

## Request Format

JSON-RPC 2.0 format:

```json
{
  "id": "<random_string>",
  "jsonrpc": "2.0",
  "method": "getIndexRateHistory",
  "params": {
    "element": {
      "fromCurrency": "USD",
      "toCurrency": "BTC",
      "fromDate": "1704067200000",
      "toDate": "1735689600000",
      "interval": "day"
    }
  }
}
```

## Request Type Specification

**ListRatePayload:**
- `fromCurrency` (required): `RateCurrency` enum - string value
- `toCurrency` (required): `RateCurrency` enum - string value
- `fromDate` (optional): `DateTime` - sent as milliseconds since epoch (string). Defaults to 1 year ago if not provided
- `toDate` (optional): `DateTime` - sent as milliseconds since epoch (string). Defaults to current time if not provided
- `interval` (optional): `RateTimelineInterval` enum - string value. Defaults to `"day"` if not provided

**RateCurrency enum values:**
- `"USD"`, `"CAD"`, `"INR"`, `"EUR"`, `"MXN"`, `"BTC"`, `"CRC"`, `"ARS"`, `"LBTC"`, `"LNBTC"`

**RateTimelineInterval enum values:**
- `"fifteen"`, `"hour"`, `"day"`, `"week"`

## Response Format

JSON-RPC 2.0 response with result wrapped in `result.element`:

```json
{
  "result": {
    "element": {
      "fromCurrency": "USD",
      "toCurrency": "BTC",
      "precision": 2,
      "interval": "day",
      "rates": [
        {
          "fromCurrency": "USD",
          "toCurrency": "BTC",
          "marketPrice": 12345678,
          "price": 12345678,
          "priceCurrency": "USD",
          "precision": 2,
          "indexPrice": 12345678,
          "userPrice": 12345678,
          "createdAt": "2024-01-01T00:00:00Z"
        }
      ]
    }
  }
}
```

## Response Type Specification

**RateHistoryModel:**
- `fromCurrency` (optional): `RateCurrency` enum (string)
- `toCurrency` (optional): `RateCurrency` enum (string)
- `precision` (optional): `int`
- `interval` (optional): `RateTimelineInterval` enum (string)
- `rates` (optional): `List<Rate>` - array of Rate objects

**Rate object:**
- `fromCurrency` (optional): `RateCurrency` enum (string)
- `toCurrency` (optional): `RateCurrency` enum (string)
- `marketPrice` (optional): `int` - price value (needs to be divided by 10^precision for actual value)
- `price` (optional): `int` - price value (needs to be divided by 10^precision for actual value)
- `priceCurrency` (optional): `string`
- `precision` (optional): `int` - decimal precision
- `indexPrice` (optional): `int` - index price value (needs to be divided by 10^precision for actual value)
- `userPrice` (optional): `int` - user price value (needs to be divided by 10^precision for actual value)
- `createdAt` (optional): `string` - ISO 8601 date string

**Note:** Price values (`marketPrice`, `price`, `indexPrice`, `userPrice`) are stored as integers and need to be divided by `10^precision` to get the actual decimal value. For example, if `indexPrice` is `12345678` and `precision` is `2`, the actual price is `123456.78`.

