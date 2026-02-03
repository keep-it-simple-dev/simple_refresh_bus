# Simple Refresh Bus

A lightweight event bus for cross-cubit state synchronization in Flutter BLoC applications.

## Installation

```yaml
dependencies:
  simple_refresh_bus: ^1.0.0
```

## Usage

### Subscribe to refresh signals

```dart
class ProfileGetCubit extends Cubit<ProfileGetState>
    with RefreshBusSubscriber<ProfileGetState> {

  ProfileGetCubit() : super(const ProfileGetState()) {
    onRefresh<Profile>(load);  // Reload when Profile signal received
  }

  Future<void> load() async {
    // Fetch from API...
  }
}
```

### Emit refresh signals

```dart
// Trigger reload on all listeners
RefreshBus.instance.refresh<Profile>();

// Or pass data directly (listeners receive it via onData)
RefreshBus.instance.push<Profile>(updatedProfile);
```

### Listen for data

```dart
onData<Profile>((profile) => emit(state.copyWith(profile: profile)));
```

## Testing

Override `refreshBus` to use an isolated instance:

```dart
class TestableProfileCubit extends ProfileGetCubit {
  final RefreshBus _testBus;
  TestableProfileCubit(this._testBus);

  @override
  RefreshBus get refreshBus => _testBus;
}

// In tests
final testBus = RefreshBus.custom();
final cubit = TestableProfileCubit(testBus);
testBus.refresh<Profile>();  // Triggers cubit reload
```

## License

MIT
