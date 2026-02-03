# Simple Refresh Bus

A lightweight event bus for cross-cubit state synchronization in Flutter BLoC applications.

## The Problem

When one cubit updates data, other cubits displaying that data become stale:

```dart
// ProfileUpdateCubit successfully updates the profile
// But ProfileGetCubit still shows old data!
// And DashboardCubit's profile summary is outdated too!
```

## The Solution

Simple Refresh Bus provides a zero-config event bus that lets cubits communicate:

```dart
// After successful update
RefreshBus.instance.refresh<Profile>();  // Signal: "Profile changed!"

// ProfileGetCubit and DashboardCubit both react and reload
```

## Features

- **Zero Configuration** - Uses global singleton, no DI setup required
- **Two Signal Types** - Refresh signals (trigger reload) or data signals (pass data directly)
- **Type-Safe** - Generic types ensure compile-time safety
- **Auto Cleanup** - Subscriptions cancelled automatically when cubits close
- **Testable** - Create isolated instances for unit tests

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  simple_refresh_bus: ^1.0.0
  flutter_bloc: ^9.0.0
```

---

## Quick Start

### 1. Add the mixin to your cubit

```dart
class ProfileGetCubit extends Cubit<ProfileGetState>
    with RefreshBusSubscriber<ProfileGetState> {

  ProfileGetCubit(this._repo) : super(const ProfileGetState()) {
    onRefresh<Profile>(load);  // Reload when Profile refresh signal received
  }

  Future<void> load() async {
    // Fetch from API...
  }
}
```

### 2. Emit refresh signals when data changes

```dart
class ProfileUpdateCubit extends Cubit<ProfileUpdateState> {

  Future<void> submit(ProfileData data) async {
    final result = await _repo.updateProfile(data);

    result.fold(
      (failure) => emit(state.copyWith(status: Status.failure)),
      (success) {
        emit(state.copyWith(status: Status.success));
        RefreshBus.instance.refresh<Profile>();  // Notify listeners!
      },
    );
  }
}
```

That's it! `ProfileGetCubit` will automatically reload when the update succeeds.

---

## Advanced Usage

### Passing Data Directly

If your update response already contains the new data, avoid a redundant API call:

```dart
// Instead of triggering a reload...
RefreshBus.instance.refresh<Profile>();

// Pass the data directly!
RefreshBus.instance.push<Profile>(updatedProfile);
```

Listen for data in your cubit:

```dart
class ProfileGetCubit extends Cubit<ProfileGetState>
    with RefreshBusSubscriber<ProfileGetState> {

  ProfileGetCubit(this._repo) : super(const ProfileGetState()) {
    // Handle refresh signals - reload from API
    onRefresh<Profile>(load);

    // Handle data signals - use data directly (no API call!)
    onData<Profile>((profile) => emit(state.copyWith(
      status: ProfileGetStatus.success,
      profile: profile,
    )));
  }
}
```

### Multiple Cubits, Same Signal

Different cubits can react differently to the same signal:

```dart
// ProfileGetCubit - uses the data directly
onData<Profile>((profile) => emit(state.copyWith(profile: profile)));

// DashboardCubit - needs to reload its own data
onRefresh<Profile>(loadDashboard);

// NotificationsCubit - also reloads
onRefresh<Profile>(loadNotifications);
```

When you call `RefreshBus.instance.push<Profile>(profile)`:
- `ProfileGetCubit` uses the profile directly (no API call)
- `DashboardCubit` reloads dashboard data (makes API call)
- `NotificationsCubit` reloads notifications (makes API call)

---

## Testing

Create isolated `RefreshBus` instances for tests:

```dart
class TestableProfileCubit extends Cubit<ProfileGetState>
    with RefreshBusSubscriber<ProfileGetState> {

  final RefreshBus _testBus;

  TestableProfileCubit(this._repo, this._testBus) : super(const ProfileGetState()) {
    onRefresh<Profile>(load);
  }

  @override
  RefreshBus get refreshBus => _testBus;  // Use test instance
}
```

In your tests:

```dart
void main() {
  group('ProfileGetCubit', () {
    late RefreshBus testBus;
    late MockProfileRepository mockRepo;
    late TestableProfileCubit cubit;

    setUp(() {
      testBus = RefreshBus.custom();  // Isolated instance
      mockRepo = MockProfileRepository();
      cubit = TestableProfileCubit(mockRepo, testBus);
    });

    test('reloads when refresh signal received', () async {
      when(() => mockRepo.getProfile()).thenAnswer(
        (_) async => Right(ProfileResponse(data: testProfile)),
      );

      testBus.refresh<Profile>();
      await Future.delayed(Duration.zero);

      verify(() => mockRepo.getProfile()).called(1);
    });

    test('uses data directly when pushed', () async {
      testBus.push<Profile>(testProfile);
      await Future.delayed(Duration.zero);

      expect(cubit.state.profile, equals(testProfile));
      verifyNever(() => mockRepo.getProfile());  // No API call!
    });
  });
}
```

---

## API Reference

### RefreshBus

```dart
// Global singleton - use this by default
RefreshBus.instance

// Create isolated instance (for testing)
RefreshBus.custom()

// Emit a refresh signal - triggers onRefresh<T> listeners
void refresh<T extends Object>()

// Push data - triggers onData<T> listeners
void push<T extends Object>(T data)

// Low-level stream access (advanced use)
Stream<Refresh<T>> onRefreshStream<T extends Object>()
Stream<T> onDataStream<T extends Object>()
```

### RefreshBusSubscriber Mixin

```dart
// Listen for refresh signals
void onRefresh<T extends Object>(Future<void> Function() reload)

// Listen for data
void onData<T extends Object>(void Function(T data) handler)

// Override for testing (defaults to RefreshBus.instance)
RefreshBus get refreshBus
```

---

## Flow Diagrams

### Refresh Signal Flow
```
ProfileUpdateCubit.submit() → success
                │
                ▼
    RefreshBus.instance.refresh<Profile>()
                │
        ┌───────┴───────┐
        ▼               ▼
ProfileGetCubit    DashboardCubit
onRefresh()        onRefresh()
calls load()       calls loadDashboard()
```

### Data Signal Flow
```
ProfileUpdateCubit.submit() → success with profile data
                │
                ▼
    RefreshBus.instance.push<Profile>(profile)
                │
        ┌───────┴───────┐
        ▼               ▼
ProfileGetCubit    DashboardCubit
onData()           onRefresh()
uses data directly reloads from API
(no API call)      (makes API call)
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.
