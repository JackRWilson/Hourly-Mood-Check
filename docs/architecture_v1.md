# Hourly Mood Check — V1 Architecture & Implementation Guide

> **Version 1 (MVP) — milestone-gated development**
> Do not advance to the next milestone until the current gate passes.

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [V1 Development Roadmap](#2-v1-development-roadmap)
3. [Garmin Connect IQ Project Structure](#3-garmin-connect-iq-project-structure)
4. [Flutter Project Structure](#4-flutter-project-structure)
5. [SQLite Schema](#5-sqlite-schema)
6. [Garmin-to-Phone Sync Design](#6-garmin-to-phone-sync-design)
7. [Monkey C Implementation](#7-monkey-c-implementation)
8. [Flutter Implementation](#8-flutter-implementation)
9. [Testing Strategy](#9-testing-strategy)
10. [Recommended Folder Structure](#10-recommended-folder-structure)

---

## 1. System Architecture

### High-level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Garmin Watch                            │
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │   Scheduler │───▶│  Mood Prompt │───▶│  Local Store  │  │
│  │ (Background)│    │     UI       │    │ (Object Store)│  │
│  └─────────────┘    └──────────────┘    └──────┬────────┘  │
│                                                │           │
└────────────────────────────────────────────────┼───────────┘
                                                 │ BLE / Companion API
┌────────────────────────────────────────────────┼───────────┐
│                  Flutter Mobile App            │           │
│                                                ▼           │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │   Home /    │    │  Repository  │    │   SQLite DB   │  │
│  │  Graph View │◀───│    Layer     │◀───│  (local only) │  │
│  └─────────────┘    └──────────────┘    └───────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Core Design Principles

- **Offline-first**: all data lives on device; sync is best-effort
- **Repository pattern**: UI never talks to storage directly
- **Interface-driven**: every integration point is an abstract interface, enabling future cloud sync, additional platforms, etc.
- **Single source of truth**: SQLite is the authoritative store on mobile; Garmin Object Store is the authoritative store on watch

### Extension Points (V1 architecture only — not implemented)

| Future Feature | Extension Point |
|---|---|
| Cloud sync | `SyncRepository` interface — swap local-only impl for remote |
| Mood notes | `MoodEntry.notes` field — already in schema as nullable |
| Analytics | `AnalyticsService` interface in domain layer |
| Garmin health data | `HealthMetricRepository` interface |
| Multiple scales | `MoodScale` interface — 7-point scale is one implementation |
| Missed prompts | `PromptTrackingService` — scheduler emits events, service records misses |

---

## 2. V1 Development Roadmap

### Milestone 1 — Garmin Prompt

**Goal**: Watch shows the mood prompt at 1 min before the hour and accepts input.

**Gate**: Tap through all 7 mood options on device/simulator; each logs to debug console with correct integer value.

Implementation checklist:
- [ ] Create Connect IQ project with WatchApp type
- [ ] Implement `BackgroundService` with time check logic (minute == 59)
- [ ] Build `MoodPickerView` — scrollable 7-item list
- [ ] Wire up selection → debug `System.println` output
- [ ] Test on simulator at synthetic time 9:59

---

### Milestone 2 — Storage

**Gate**: Select a mood, kill and reopen the app, and the entry is still present in Object Store on watch AND in SQLite on phone.

Implementation checklist:
- [ ] Define `MoodEntry` model (id, timestamp, moodScore)
- [ ] Implement `GarminMoodStore` using `Application.Storage`
- [ ] Create Flutter SQLite schema and migration runner
- [ ] Implement `LocalMoodRepository` (Flutter)
- [ ] Unit test: insert → fetch → verify round-trip

---

### Milestone 3 — Sync

**Gate**: Select mood on watch → entry appears in Flutter app's database within 30 seconds, without manual action.

Implementation checklist:
- [ ] Implement `GarminCommunicationDelegate` on watch side
- [ ] Implement `FlutterGarminBridge` service using `device_garmin` package
- [ ] Define sync message schema (JSON over BLE)
- [ ] Handle duplicate detection on Flutter side (by timestamp)
- [ ] Test with real watch or Connect IQ simulator + Garmin Connect app

---

### Milestone 4 — Graph

**Gate**: App shows a line chart for today with correct entries plotted; Y-axis spans -3 to +3; X-axis shows hourly labels.

Implementation checklist:
- [ ] Integrate `fl_chart` package
- [ ] Build `DailyMoodChart` widget
- [ ] Build `DayPickerBar` for navigating dates
- [ ] Display daily average badge
- [ ] Render "no data" empty state

---

### Milestone 5 — Settings

**Gate**: Change start hour to 10 and end hour to 6 PM; confirm watch stops prompting at 9:59 and starts at 10:59 with no prompts outside window.

Implementation checklist:
- [ ] `Settings` model (startHour, endHour)
- [ ] Settings screen in Flutter with time pickers
- [ ] Persist settings to SQLite and sync to watch
- [ ] Watch background service reads settings before showing prompt
- [ ] Settings survive app restart

---

## 3. Garmin Connect IQ Project Structure

```
hourly-mood-watch/
├── manifest.xml                  # App metadata, permissions, targets
├── resources/
│   ├── strings/
│   │   └── strings.xml           # "How have you been feeling..."
│   ├── layouts/
│   │   ├── mood_picker.xml       # Scrollable list layout
│   │   └── confirmation.xml      # "Saved!" feedback layout
│   └── menus/
│       └── mood_menu.xml         # Alternative menu approach
├── source/
│   ├── HourlyMoodApp.mc          # App entry point
│   ├── background/
│   │   └── BackgroundService.mc  # Hourly time check
│   ├── ui/
│   │   ├── MoodPickerView.mc     # Primary selection UI
│   │   └── ConfirmationView.mc   # Post-selection feedback
│   ├── data/
│   │   ├── MoodEntry.mc          # Data model
│   │   └── GarminMoodStore.mc    # Object Store persistence
│   ├── sync/
│   │   └── PhoneSyncDelegate.mc  # BLE communication
│   └── settings/
│       └── WatchSettings.mc      # startHour / endHour access
└── tests/
    └── MoodStoreTest.mc
```

### manifest.xml (key sections)

```xml
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
  <iq:application id="YOUR-UUID-HERE" name="HourlyMood"
    launchType="background" minApiLevel="3.2.0"
    type="watchApp">
    <iq:products>
      <iq:product id="fenix7"/>
      <iq:product id="vivoactive4"/>
      <!-- Add target devices here -->
    </iq:products>
    <iq:permissions>
      <iq:uses-permission id="Background"/>
      <iq:uses-permission id="Communications"/>
    </iq:permissions>
    <iq:languages>
      <iq:language id="eng"/>
    </iq:languages>
  </iq:application>
</iq:manifest>
```

---

## 4. Flutter Project Structure

```
hourly_mood_flutter/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp + routing
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── mood_scale.dart           # Mood labels + int values
│   │   ├── errors/
│   │   │   └── failures.dart             # Typed failure classes
│   │   └── extensions/
│   │       └── datetime_extensions.dart
│   │
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── mood_entry.dart           # Pure Dart entity
│   │   │   └── settings.dart
│   │   ├── repositories/
│   │   │   ├── mood_repository.dart      # Abstract interface
│   │   │   └── settings_repository.dart  # Abstract interface
│   │   └── usecases/
│   │       ├── get_entries_for_day.dart
│   │       ├── save_mood_entry.dart
│   │       └── get_daily_average.dart
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local_mood_datasource.dart      # SQLite impl
│   │   │   └── garmin_bridge_datasource.dart   # BLE bridge
│   │   ├── models/
│   │   │   ├── mood_entry_model.dart    # JSON + DB row mapping
│   │   │   └── settings_model.dart
│   │   └── repositories/
│   │       ├── mood_repository_impl.dart
│   │       └── settings_repository_impl.dart
│   │
│   ├── presentation/
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   ├── home_cubit.dart
│   │   │   └── home_state.dart
│   │   ├── graph/
│   │   │   ├── daily_mood_chart.dart     # fl_chart widget
│   │   │   └── day_picker_bar.dart
│   │   ├── history/
│   │   │   └── daily_history_list.dart
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── settings_cubit.dart
│   │
│   └── injection/
│       └── service_locator.dart          # get_it registration
│
└── test/
    ├── domain/
    │   └── usecases/
    │       └── get_entries_for_day_test.dart
    ├── data/
    │   └── repositories/
    │       └── mood_repository_impl_test.dart
    └── presentation/
        └── home/
            └── home_cubit_test.dart
```

### pubspec.yaml dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  # State management
  flutter_bloc: ^8.1.0
  equatable: ^2.0.0
  # Storage
  sqflite: ^2.3.0
  path: ^1.9.0
  # Charts
  fl_chart: ^0.66.0
  # DI
  get_it: ^7.6.0
  # Garmin bridge
  # NOTE: No official Dart SDK exists; use platform channel or
  # community package e.g. flutter_garmin_health (verify licensing)
  # Date/time helpers
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.0
  mocktail: ^1.0.0
```

---

## 5. SQLite Schema

```sql
-- V1 schema (migration version 1)
CREATE TABLE IF NOT EXISTS mood_entries (
    id          TEXT PRIMARY KEY,        -- UUID v4
    timestamp   INTEGER NOT NULL,        -- Unix epoch milliseconds
    mood_score  INTEGER NOT NULL         -- -3 to +3
    -- Future: notes TEXT
    -- Future: source TEXT DEFAULT 'garmin'
    -- Future: synced_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_mood_entries_timestamp
    ON mood_entries(timestamp);

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL
);

-- Seed defaults
INSERT OR IGNORE INTO settings (key, value) VALUES ('start_hour', '9');
INSERT OR IGNORE INTO settings (key, value) VALUES ('end_hour',   '21');
```

### Dart schema migration runner

```dart
const int _dbVersion = 1;
const String _dbName = 'hourly_mood.db';

Future<Database> openAppDatabase() async {
  final path = join(await getDatabasesPath(), _dbName);
  return openDatabase(
    path,
    version: _dbVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS mood_entries (
      id         TEXT PRIMARY KEY,
      timestamp  INTEGER NOT NULL,
      mood_score INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_ts ON mood_entries(timestamp)',
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
  await db.insert('settings', {'key': 'start_hour', 'value': '9'});
  await db.insert('settings', {'key': 'end_hour',   'value': '21'});
}

Future<void> _onUpgrade(Database db, int old, int newV) async {
  // Add migrations here in future versions
  // e.g. if (old < 2) await db.execute('ALTER TABLE mood_entries ADD COLUMN notes TEXT');
}
```

---

## 6. Garmin-to-Phone Sync Design

### Message Schema

All messages are JSON transmitted over Garmin's `Communications.transmitMessage()`.

```json
{
  "type": "mood_entry",
  "version": 1,
  "payload": {
    "id": "uuid-v4-string",
    "timestamp": 1718000000000,
    "mood_score": 2
  }
}

{
  "type": "settings_request",
  "version": 1
}

{
  "type": "settings_response",
  "version": 1,
  "payload": {
    "start_hour": 9,
    "end_hour": 21
  }
}
```

### Sync Flow

```
Watch                           Phone
  │                               │
  │── mood_entry ────────────────▶│
  │                               │  save to SQLite
  │                               │  check duplicate by id
  │◀── ack ───────────────────────│
  │                               │
  │── settings_request ──────────▶│
  │◀── settings_response ─────────│
  │  update Object Store           │
```

### Reliability Strategy

- **Pending queue**: watch stores unsynced entries in Object Store; retries on next connect
- **Deduplication**: Flutter side checks `id` before inserting; silently skips duplicates
- **No guaranteed delivery in V1**: if entry is lost, it is lost — acceptable for MVP
- **Future**: add `synced_at` column + retry queue on phone side

---

## 7. Monkey C Implementation

### BackgroundService.mc

```monkeyc
using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Communications as Comm;

(:background)
class BackgroundService extends Sys.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
        var clockTime = Sys.getClockTime();
        var settings  = App.getApp().getProperty("settings");
        var startHour = (settings != null) ? settings["startHour"] : 9;
        var endHour   = (settings != null) ? settings["endHour"]   : 21;

        // Fire at minute 59, within the configured window
        if (clockTime.min == 59
                && clockTime.hour >= startHour
                && clockTime.hour < endHour) {
            Bg.requestApplicationWake("mood_prompt");
        }
    }
}
```

### HourlyMoodApp.mc

```monkeyc
using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Background as Bg;

class HourlyMoodApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // Register background temporal event every minute
        Bg.registerForTemporalEvent(new Time.Duration(60));
    }

    function onStop(state) {
        Bg.deleteTemporalEvent();
    }

    function getInitialView() {
        return [new MoodPickerView(), new MoodPickerDelegate()];
    }

    // Called when background service requests wake
    function onBackgroundData(data) {
        if (data.equals("mood_prompt")) {
            Ui.pushView(
                new MoodPickerView(),
                new MoodPickerDelegate(),
                Ui.SLIDE_UP
            );
        }
    }
}
```

### MoodPickerView.mc

```monkeyc
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class MoodPickerView extends Ui.View {

    const MOOD_OPTIONS = [
        { "label" => "Very Good",     "score" =>  3 },
        { "label" => "Good",          "score" =>  2 },
        { "label" => "Slightly Good", "score" =>  1 },
        { "label" => "Neutral",       "score" =>  0 },
        { "label" => "Slightly Bad",  "score" => -1 },
        { "label" => "Bad",           "score" => -2 },
        { "label" => "Very Bad",      "score" => -3 },
    ];

    var mSelectedIndex = 3; // Default: Neutral

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // Header
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2, 20,
            Gfx.FONT_TINY,
            "How have you been\nfeeling this last hour?",
            Gfx.TEXT_JUSTIFY_CENTER
        );

        // Render visible options (3 at a time, centred)
        var startIdx = (mSelectedIndex - 1).clamp(0, MOOD_OPTIONS.size() - 1);
        var yPos = 80;
        for (var i = startIdx; i < startIdx + 3 && i < MOOD_OPTIONS.size(); i++) {
            var option = MOOD_OPTIONS[i];
            var isSelected = (i == mSelectedIndex);
            dc.setColor(
                isSelected ? Gfx.COLOR_BLUE : Gfx.COLOR_LT_GRAY,
                Gfx.COLOR_TRANSPARENT
            );
            dc.drawText(
                dc.getWidth() / 2, yPos,
                isSelected ? Gfx.FONT_MEDIUM : Gfx.FONT_SMALL,
                option["label"],
                Gfx.TEXT_JUSTIFY_CENTER
            );
            yPos += 40;
        }
    }

    function scrollUp() {
        if (mSelectedIndex > 0) {
            mSelectedIndex -= 1;
            Ui.requestUpdate();
        }
    }

    function scrollDown() {
        if (mSelectedIndex < MOOD_OPTIONS.size() - 1) {
            mSelectedIndex += 1;
            Ui.requestUpdate();
        }
    }

    function getSelectedEntry() {
        return MOOD_OPTIONS[mSelectedIndex];
    }
}
```

### MoodPickerDelegate.mc

```monkeyc
using Toybox.WatchUi as Ui;

class MoodPickerDelegate extends Ui.BehaviorDelegate {

    var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onNextPage() {
        mView.scrollDown();
        return true;
    }

    function onPreviousPage() {
        mView.scrollUp();
        return true;
    }

    function onSelect() {
        var entry = mView.getSelectedEntry();
        GarminMoodStore.saveMoodEntry(entry["score"]);
        PhoneSyncDelegate.syncEntry(entry["score"]);
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }
}
```

### GarminMoodStore.mc

```monkeyc
using Toybox.Application as App;
using Toybox.Time as Time;

module GarminMoodStore {

    const ENTRIES_KEY = "mood_entries";
    const MAX_STORED  = 72; // 3 days of hourly entries

    function saveMoodEntry(score as Number) as Void {
        var entries = App.Storage.getValue(ENTRIES_KEY);
        if (entries == null) { entries = []; }

        var entry = {
            "id"         => generateId(),
            "timestamp"  => Time.now().value() * 1000, // ms
            "mood_score" => score
        };

        entries.add(entry);

        // Trim oldest entries beyond max
        if (entries.size() > MAX_STORED) {
            entries = entries.slice(entries.size() - MAX_STORED, null);
        }
        App.Storage.setValue(ENTRIES_KEY, entries);
    }

    function getPendingEntries() as Array {
        var entries = App.Storage.getValue(ENTRIES_KEY);
        return entries != null ? entries : [];
    }

    function clearSyncedEntries(syncedIds as Array) as Void {
        var entries = App.Storage.getValue(ENTRIES_KEY);
        if (entries == null) { return; }
        var remaining = entries.select(method(:isNotSynced).bind(syncedIds));
        App.Storage.setValue(ENTRIES_KEY, remaining);
    }

    // Simple id: timestamp-based (sufficient for V1 dedup)
    hidden function generateId() as String {
        return Time.now().value().toString()
               + "_"
               + Math.rand().toString();
    }
}
```

### PhoneSyncDelegate.mc

```monkeyc
using Toybox.Communications as Comm;
using Toybox.Time as Time;

module PhoneSyncDelegate {

    function syncEntry(score as Number) as Void {
        var message = {
            "type"    => "mood_entry",
            "version" => 1,
            "payload" => {
                "id"         => Time.now().value().toString(),
                "timestamp"  => Time.now().value() * 1000,
                "mood_score" => score
            }
        };

        Comm.transmitMessage(
            message,
            { :channel => Comm.CHANNEL_TYPE_NO_REPLY },
            method(:onTransmitComplete)
        );
    }

    function onTransmitComplete(responseCode, data) {
        if (responseCode != 200) {
            // Entry remains in Object Store for later retry
            System.println("Sync failed: " + responseCode);
        }
    }
}
```

---

## 8. Flutter Implementation

### Domain Entities

```dart
// lib/domain/entities/mood_entry.dart
import 'package:equatable/equatable.dart';

class MoodEntry extends Equatable {
  final String id;
  final DateTime timestamp;
  final int moodScore; // -3 to +3

  const MoodEntry({
    required this.id,
    required this.timestamp,
    required this.moodScore,
  });

  // Future: add notes, source, syncedAt without breaking existing code
  @override
  List<Object?> get props => [id, timestamp, moodScore];
}

// lib/domain/entities/settings.dart
class AppSettings extends Equatable {
  final int startHour; // 0-23
  final int endHour;   // 0-23

  const AppSettings({
    required this.startHour,
    required this.endHour,
  });

  const AppSettings.defaults() : startHour = 9, endHour = 21;

  @override
  List<Object?> get props => [startHour, endHour];
}
```

### Repository Interface

```dart
// lib/domain/repositories/mood_repository.dart
import '../entities/mood_entry.dart';

abstract interface class MoodRepository {
  Future<void> saveMoodEntry(MoodEntry entry);
  Future<List<MoodEntry>> getEntriesForDay(DateTime day);
  Future<double?> getDailyAverage(DateTime day);

  // Extension point: cloud sync, export, etc.
  // Future<void> syncToCloud();
}
```

### Use Cases

```dart
// lib/domain/usecases/get_entries_for_day.dart
class GetEntriesForDay {
  final MoodRepository _repository;
  GetEntriesForDay(this._repository);

  Future<List<MoodEntry>> call(DateTime day) =>
      _repository.getEntriesForDay(day);
}

// lib/domain/usecases/get_daily_average.dart
class GetDailyAverage {
  final MoodRepository _repository;
  GetDailyAverage(this._repository);

  Future<double?> call(DateTime day) =>
      _repository.getDailyAverage(day);
}
```

### Local Data Source

```dart
// lib/data/datasources/local_mood_datasource.dart
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/mood_entry_model.dart';

class LocalMoodDatasource {
  final Database _db;
  const LocalMoodDatasource(this._db);

  Future<void> insert(MoodEntryModel entry) async {
    await _db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // dedup by id
    );
  }

  Future<List<MoodEntryModel>> getForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end   = start.add(const Duration(days: 1));

    final rows = await _db.query(
      'mood_entries',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MoodEntryModel.fromMap).toList();
  }

  Future<double?> averageForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end   = start.add(const Duration(days: 1));

    final result = await _db.rawQuery(
      'SELECT AVG(mood_score) as avg FROM mood_entries '
      'WHERE timestamp >= ? AND timestamp < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    final avg = result.first['avg'];
    return avg != null ? (avg as num).toDouble() : null;
  }
}
```

### Model

```dart
// lib/data/models/mood_entry_model.dart
import '../../domain/entities/mood_entry.dart';

class MoodEntryModel extends MoodEntry {
  const MoodEntryModel({
    required super.id,
    required super.timestamp,
    required super.moodScore,
  });

  factory MoodEntryModel.fromMap(Map<String, dynamic> map) =>
      MoodEntryModel(
        id:        map['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        moodScore: map['mood_score'] as int,
      );

  Map<String, dynamic> toMap() => {
    'id':         id,
    'timestamp':  timestamp.millisecondsSinceEpoch,
    'mood_score': moodScore,
  };

  factory MoodEntryModel.fromEntity(MoodEntry e) =>
      MoodEntryModel(id: e.id, timestamp: e.timestamp, moodScore: e.moodScore);
}
```

### Garmin Bridge (platform channel wrapper)

```dart
// lib/data/datasources/garmin_bridge_datasource.dart
import 'package:flutter/services.dart';
import '../models/mood_entry_model.dart';
import 'dart:convert';

class GarminBridgeDatasource {
  static const _channel = MethodChannel('com.yourapp.garmin_bridge');

  GarminBridgeDatasource() {
    _channel.setMethodCallHandler(_handleIncomingMessage);
  }

  // Callback invoked when watch sends a mood entry
  void Function(MoodEntryModel)? onEntryReceived;

  Future<dynamic> _handleIncomingMessage(MethodCall call) async {
    if (call.method == 'onMoodEntry') {
      final map = Map<String, dynamic>.from(
          jsonDecode(call.arguments as String) as Map);
      final entry = MoodEntryModel.fromMap(map['payload'] as Map<String, dynamic>);
      onEntryReceived?.call(entry);
    }
  }
}
```

### Home Cubit

```dart
// lib/presentation/home/home_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/usecases/get_entries_for_day.dart';
import '../../domain/usecases/get_daily_average.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final GetEntriesForDay _getEntries;
  final GetDailyAverage  _getAverage;

  HomeCubit(this._getEntries, this._getAverage)
      : super(HomeState.initial());

  Future<void> loadDay(DateTime day) async {
    emit(state.copyWith(status: HomeStatus.loading, selectedDay: day));
    final entries = await _getEntries(day);
    final average = await _getAverage(day);
    emit(state.copyWith(
      status:  HomeStatus.loaded,
      entries: entries,
      average: average,
    ));
  }

  void goToPreviousDay() => loadDay(
      state.selectedDay.subtract(const Duration(days: 1)));

  void goToNextDay() {
    final next = state.selectedDay.add(const Duration(days: 1));
    if (!next.isAfter(DateTime.now())) loadDay(next);
  }
}
```

### Daily Mood Chart Widget

```dart
// lib/presentation/graph/daily_mood_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/mood_entry.dart';
import '../../core/constants/mood_scale.dart';

class DailyMoodChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const DailyMoodChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No entries for this day'));
    }

    final spots = entries.map((e) => FlSpot(
      e.timestamp.hour.toDouble() + e.timestamp.minute / 60.0,
      e.moodScore.toDouble(),
    )).toList();

    return LineChart(
      LineChartData(
        minX: 0, maxX: 24,
        minY: -3, maxY: 3,
        gridData: FlGridData(
          drawHorizontalLine: true,
          horizontalInterval: 1,
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(
                MoodScale.labelForScore(value.toInt()),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: true),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: 0, color: Colors.grey.shade300, strokeWidth: 1),
          ],
        ),
      ),
    );
  }
}
```

### Mood Scale Constants

```dart
// lib/core/constants/mood_scale.dart
class MoodScale {
  static const List<MoodOption> options = [
    MoodOption(label: 'Very Good',     score:  3),
    MoodOption(label: 'Good',          score:  2),
    MoodOption(label: 'Slightly Good', score:  1),
    MoodOption(label: 'Neutral',       score:  0),
    MoodOption(label: 'Slightly Bad',  score: -1),
    MoodOption(label: 'Bad',           score: -2),
    MoodOption(label: 'Very Bad',      score: -3),
  ];

  static String labelForScore(int score) {
    return options
        .firstWhere((o) => o.score == score,
            orElse: () => const MoodOption(label: '', score: 0))
        .label;
  }
}

class MoodOption {
  final String label;
  final int score;
  const MoodOption({required this.label, required this.score});
}
```

---

## 9. Testing Strategy

### Garmin Watch (Monkey C)

| Test | Type | How |
|---|---|---|
| BackgroundService fires at minute 59 | Unit | Mock `Sys.getClockTime()`, assert `requestApplicationWake` called |
| BackgroundService respects window | Unit | Test with hours outside start/end — assert no wake |
| MoodPickerView renders correct labels | Manual | Connect IQ simulator |
| Selection saves correct score | Unit | Mock `App.Storage`, verify stored value |
| Sync message format | Unit | Assert JSON shape matches schema |

### Flutter

| Test | Type | Tool |
|---|---|---|
| `GetEntriesForDay` returns correct filtered list | Unit | `mocktail` |
| `LocalMoodDatasource.insert` deduplicates by id | Integration | In-memory SQLite |
| `HomeCubit` emits loading then loaded states | Unit | `bloc_test` |
| `DailyMoodChart` renders spots at correct x positions | Widget | `flutter_test` |
| Settings persist across cold restart | Integration | `sqflite` + app lifecycle |

### End-to-End (milestone 3+)

1. Flash watch app to physical device
2. Manually trigger background service
3. Confirm entry appears in Flutter app database within 30 s
4. Kill Flutter app, reopen — entry still present

---

## 10. Recommended Folder Structure (full repo)

```
hourly-mood-check/
├── README.md
├── .gitignore
│
├── watch/                              # Garmin Connect IQ
│   └── hourly-mood-watch/
│       ├── manifest.xml
│       ├── resources/
│       └── source/
│           ├── HourlyMoodApp.mc
│           ├── background/
│           ├── ui/
│           ├── data/
│           ├── sync/
│           └── settings/
│
├── mobile/                             # Flutter
│   └── hourly_mood_flutter/
│       ├── pubspec.yaml
│       ├── lib/
│       │   ├── core/
│       │   ├── domain/
│       │   ├── data/
│       │   ├── presentation/
│       │   └── injection/
│       └── test/
│
├── docs/
│   ├── architecture.md                 # This document
│   ├── sync-protocol.md
│   └── adr/                            # Architecture Decision Records
│       ├── 001-offline-first.md
│       └── 002-repository-pattern.md
│
└── scripts/
    ├── build-watch.sh
    └── build-mobile.sh
```

---

## Appendix A — Mood Score Reference

| Label | Score | Use in chart |
|---|---|---|
| Very Good | +3 | Top of Y-axis |
| Good | +2 | |
| Slightly Good | +1 | |
| Neutral | 0 | Zero line |
| Slightly Bad | -1 | |
| Bad | -2 | |
| Very Bad | -3 | Bottom of Y-axis |

## Appendix B — BLE Reliability Notes

Garmin's `Communications.transmitMessage()` is best-effort. For V1 this is acceptable — a missed sync is not catastrophic. Future versions should add:

1. Pending queue on watch (already designed into `GarminMoodStore`)
2. ACK-based retry: watch retransmits any entry not acknowledged within 60 s
3. Full sync on connect: phone requests all entries > last known timestamp on app open

## Appendix C — Battery Efficiency

- Background service wakes once per minute (required for minute-59 check) — this is the minimum Connect IQ allows
- On-device processing is minimal: one time comparison, no sensors
- BLE transmission is short (< 200 bytes per entry)
- Future: move to `registerForTemporalEvent(Duration(minutes: 1))` with an early-exit if minute != 59 — already the design
