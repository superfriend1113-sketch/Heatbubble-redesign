# Cloud Storage Strategy for HeatBubble

## Problem
Storing every temperature reading in Firestore is expensive and inefficient:
- ~5,000-10,000 readings per day per user
- 1 million users = 5-10 billion writes/day = Very expensive
- Large datasets slow down queries
- Unnecessary data accumulation

## Solution: Hybrid Storage Strategy

### 1. Local Storage (Isar - Free & Fast)
- Store ALL readings locally on device
- Unlimited storage
- Instant access
- Works offline
- No cost

### 2. Cloud Storage (Firestore - Optimized)

#### A. Individual Readings (Last 7 Days Only)
- Sync only recent readings (7 days)
- Allows detailed analysis of recent data
- Auto-cleanup old readings
- ~50-100 readings per user in cloud

**Cost**: ~100 writes/day per user = $0.0001/day per user

#### B. Aggregated Data (Forever)
- Hourly summaries: avg, min, max, count
- Daily summaries: avg, min, max, count
- Much smaller dataset
- Perfect for charts and trends
- Historical data preserved

**Cost**: ~24 hourly + 1 daily = 25 writes/day per user = $0.000025/day per user

### Total Cost Comparison

**Old Approach (All Readings)**:
- 10,000 writes/day per user
- 1M users = $1,080/day = $32,400/month

**New Approach (Smart Sync)**:
- 125 writes/day per user
- 1M users = $13.50/day = $405/month

**Savings: 98.75% reduction in costs!**

## Implementation

### SmartSyncService Features

1. **Automatic Aggregation**
   - Groups readings by hour/day
   - Calculates statistics (avg, min, max)
   - Uploads compact summaries

2. **Selective Sync**
   - Only syncs last 7 days of individual readings
   - Syncs all aggregates (tiny data)
   - Auto-cleanup old cloud data

3. **Efficient Queries**
   - Fast hourly/daily chart data retrieval
   - No need to query thousands of documents
   - Pre-calculated statistics

4. **Offline-First**
   - All data available locally
   - Sync happens in background
   - No internet required for app to work

## Usage

### Replace Old Sync
```dart
// OLD (expensive)
await _firestore.saveReading(userId: userId, reading: reading);

// NEW (smart)
await SmartSyncService().smartSync();
```

### Get Chart Data
```dart
// Hourly data for premium charts
final hourlyData = await SmartSyncService().getHourlyChartData(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);

// Daily data for trends
final dailyData = await SmartSyncService().getDailyChartData(
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);
```

## Firestore Structure

```
users/{userId}/
  ├── profile (1 document)
  ├── hourly_aggregates/
  │   ├── 2026-03-26-14 (avg: 36.5, min: 36.2, max: 36.8, count: 450)
  │   ├── 2026-03-26-15 (avg: 36.6, min: 36.3, max: 36.9, count: 450)
  │   └── ...
  └── daily_aggregates/
      ├── 2026-03-26 (avg: 36.5, min: 35.8, max: 37.2, count: 10800)
      ├── 2026-03-27 (avg: 36.4, min: 35.9, max: 37.0, count: 10800)
      └── ...

readings/ (only last 7 days)
  ├── {readingId1} (userId, temp, timestamp)
  ├── {readingId2} (userId, temp, timestamp)
  └── ... (~700 readings per user max)
```

## Benefits

1. **Cost Savings**: 98.75% reduction in Firestore costs
2. **Performance**: Faster queries with pre-aggregated data
3. **Scalability**: Can handle millions of users
4. **Offline-First**: App works without internet
5. **Historical Data**: Keep trends forever (cheap)
6. **Detailed Recent Data**: Last 7 days available for analysis

## Migration

To migrate existing code:

1. Replace `FirebaseSyncService` with `SmartSyncService`
2. Update sync calls in `home_screen.dart`
3. Use aggregated data for charts
4. Keep local Isar storage as primary source

## Future Enhancements

1. **Compression**: Further reduce data size
2. **Batch Uploads**: Upload multiple hours at once
3. **Smart Scheduling**: Sync only on WiFi
4. **Data Export**: Allow users to download full history
5. **Cloud Functions**: Server-side aggregation for even lower costs
