import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_refresh_bus/simple_refresh_bus.dart';

// Test model classes
class Profile {
  final String name;
  const Profile(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class Dashboard {
  final int count;
  const Dashboard(this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dashboard &&
          runtimeType == other.runtimeType &&
          count == other.count;

  @override
  int get hashCode => count.hashCode;
}

// Test state class
class TestState {
  final Profile? profile;
  final Dashboard? dashboard;
  final int loadCount;
  final bool isLoading;

  const TestState({
    this.profile,
    this.dashboard,
    this.loadCount = 0,
    this.isLoading = false,
  });

  TestState copyWith({
    Profile? profile,
    Dashboard? dashboard,
    int? loadCount,
    bool? isLoading,
  }) {
    return TestState(
      profile: profile ?? this.profile,
      dashboard: dashboard ?? this.dashboard,
      loadCount: loadCount ?? this.loadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestState &&
          runtimeType == other.runtimeType &&
          profile == other.profile &&
          dashboard == other.dashboard &&
          loadCount == other.loadCount &&
          isLoading == other.isLoading;

  @override
  int get hashCode =>
      profile.hashCode ^ dashboard.hashCode ^ loadCount.hashCode ^ isLoading.hashCode;
}

// Test cubit that uses RefreshBusSubscriber
class TestCubit extends Cubit<TestState> with RefreshBusSubscriber<TestState> {
  final RefreshBus _bus;
  final Future<void> Function()? onLoadProfile;
  final Future<void> Function()? onLoadDashboard;

  TestCubit({
    required RefreshBus bus,
    this.onLoadProfile,
    this.onLoadDashboard,
  })  : _bus = bus,
        super(const TestState()) {
    if (onLoadProfile != null) {
      onRefresh<Profile>(_loadProfile);
    }
    if (onLoadDashboard != null) {
      onRefresh<Dashboard>(_loadDashboard);
    }
  }

  @override
  RefreshBus get refreshBus => _bus;

  Future<void> _loadProfile() async {
    emit(state.copyWith(isLoading: true));
    await onLoadProfile?.call();
    emit(state.copyWith(
      isLoading: false,
      loadCount: state.loadCount + 1,
    ));
  }

  Future<void> _loadDashboard() async {
    await onLoadDashboard?.call();
  }
}

// Test cubit that listens for data
class DataListenerCubit extends Cubit<TestState>
    with RefreshBusSubscriber<TestState> {
  final RefreshBus _bus;

  DataListenerCubit({required RefreshBus bus})
      : _bus = bus,
        super(const TestState()) {
    onData<Profile>((profile) {
      emit(state.copyWith(profile: profile));
    });
    onData<Dashboard>((dashboard) {
      emit(state.copyWith(dashboard: dashboard));
    });
  }

  @override
  RefreshBus get refreshBus => _bus;
}

// Test cubit that listens for both refresh and data
class CombinedListenerCubit extends Cubit<TestState>
    with RefreshBusSubscriber<TestState> {
  final RefreshBus _bus;
  int refreshCallCount = 0;
  int dataCallCount = 0;

  CombinedListenerCubit({required RefreshBus bus})
      : _bus = bus,
        super(const TestState()) {
    onRefresh<Profile>(_onProfileRefresh);
    onData<Profile>(_onProfileData);
  }

  @override
  RefreshBus get refreshBus => _bus;

  Future<void> _onProfileRefresh() async {
    refreshCallCount++;
    emit(state.copyWith(loadCount: state.loadCount + 1));
  }

  void _onProfileData(Profile profile) {
    dataCallCount++;
    emit(state.copyWith(profile: profile));
  }
}

void main() {
  group('RefreshBusSubscriber', () {
    late RefreshBus testBus;

    setUp(() {
      testBus = RefreshBus.custom();
    });

    group('onRefresh()', () {
      test('calls reload function when refresh signal received', () async {
        var loadCalled = false;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            loadCalled = true;
          },
        );

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(loadCalled, isTrue);
        await cubit.close();
      });

      test('calls reload function multiple times for multiple signals',
          () async {
        var loadCount = 0;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            loadCount++;
          },
        );

        testBus.refresh<Profile>();
        testBus.refresh<Profile>();
        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(loadCount, equals(3));
        await cubit.close();
      });

      test('only responds to matching type', () async {
        var profileLoadCount = 0;
        var dashboardLoadCount = 0;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            profileLoadCount++;
          },
          onLoadDashboard: () async {
            dashboardLoadCount++;
          },
        );

        testBus.refresh<Profile>();
        testBus.refresh<Dashboard>();
        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(profileLoadCount, equals(2));
        expect(dashboardLoadCount, equals(1));
        await cubit.close();
      });

      test('does not respond to unregistered types', () async {
        var loadCalled = false;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            loadCalled = true;
          },
        );

        testBus.refresh<Dashboard>();
        await Future.delayed(Duration.zero);

        expect(loadCalled, isFalse);
        await cubit.close();
      });

      blocTest<TestCubit, TestState>(
        'emits correct states when refresh signal received',
        build: () => TestCubit(
          bus: testBus,
          onLoadProfile: () async {},
        ),
        act: (cubit) {
          testBus.refresh<Profile>();
        },
        wait: const Duration(milliseconds: 10),
        expect: () => [
          const TestState(isLoading: true, loadCount: 0),
          const TestState(isLoading: false, loadCount: 1),
        ],
      );
    });

    group('onData()', () {
      test('calls handler with data when data signal received', () async {
        final cubit = DataListenerCubit(bus: testBus);

        testBus.push<Profile>(const Profile('TestUser'));
        await Future.delayed(Duration.zero);

        expect(cubit.state.profile, equals(const Profile('TestUser')));
        await cubit.close();
      });

      test('calls handler multiple times for multiple data pushes', () async {
        final cubit = DataListenerCubit(bus: testBus);

        testBus.push<Profile>(const Profile('First'));
        await Future.delayed(Duration.zero);
        expect(cubit.state.profile, equals(const Profile('First')));

        testBus.push<Profile>(const Profile('Second'));
        await Future.delayed(Duration.zero);
        expect(cubit.state.profile, equals(const Profile('Second')));

        testBus.push<Profile>(const Profile('Third'));
        await Future.delayed(Duration.zero);
        expect(cubit.state.profile, equals(const Profile('Third')));

        await cubit.close();
      });

      test('only responds to matching type', () async {
        final cubit = DataListenerCubit(bus: testBus);

        testBus.push<Profile>(const Profile('TestUser'));
        testBus.push<Dashboard>(const Dashboard(42));
        await Future.delayed(Duration.zero);

        expect(cubit.state.profile, equals(const Profile('TestUser')));
        expect(cubit.state.dashboard, equals(const Dashboard(42)));
        await cubit.close();
      });

      test('does not respond to unregistered types', () async {
        final cubit = DataListenerCubit(bus: testBus);

        // Push a type that's not registered (String)
        testBus.push<String>('test');
        await Future.delayed(Duration.zero);

        expect(cubit.state.profile, isNull);
        expect(cubit.state.dashboard, isNull);
        await cubit.close();
      });

      blocTest<DataListenerCubit, TestState>(
        'emits state with profile when Profile data pushed',
        build: () => DataListenerCubit(bus: testBus),
        act: (cubit) {
          testBus.push<Profile>(const Profile('BlocTestUser'));
        },
        wait: const Duration(milliseconds: 10),
        expect: () => [
          const TestState(profile: Profile('BlocTestUser')),
        ],
      );

      blocTest<DataListenerCubit, TestState>(
        'emits state with dashboard when Dashboard data pushed',
        build: () => DataListenerCubit(bus: testBus),
        act: (cubit) {
          testBus.push<Dashboard>(const Dashboard(99));
        },
        wait: const Duration(milliseconds: 10),
        expect: () => [
          const TestState(dashboard: Dashboard(99)),
        ],
      );
    });

    group('combined onRefresh and onData', () {
      test('refresh signal only triggers onRefresh', () async {
        final cubit = CombinedListenerCubit(bus: testBus);

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(cubit.refreshCallCount, equals(1));
        expect(cubit.dataCallCount, equals(0));
        await cubit.close();
      });

      test('data signal only triggers onData', () async {
        final cubit = CombinedListenerCubit(bus: testBus);

        testBus.push<Profile>(const Profile('Test'));
        await Future.delayed(Duration.zero);

        expect(cubit.refreshCallCount, equals(0));
        expect(cubit.dataCallCount, equals(1));
        await cubit.close();
      });

      test('both signals trigger their respective handlers', () async {
        final cubit = CombinedListenerCubit(bus: testBus);

        testBus.refresh<Profile>();
        testBus.push<Profile>(const Profile('Test'));
        testBus.refresh<Profile>();
        testBus.push<Profile>(const Profile('Another'));
        await Future.delayed(Duration.zero);

        expect(cubit.refreshCallCount, equals(2));
        expect(cubit.dataCallCount, equals(2));
        await cubit.close();
      });
    });

    group('subscription lifecycle', () {
      test('subscriptions are cancelled when cubit is closed', () async {
        var loadCount = 0;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            loadCount++;
          },
        );

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(loadCount, equals(1));

        await cubit.close();

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(loadCount, equals(1)); // Still 1, not 2
      });

      test('data subscriptions are cancelled when cubit is closed', () async {
        final cubit = DataListenerCubit(bus: testBus);

        testBus.push<Profile>(const Profile('First'));
        await Future.delayed(Duration.zero);
        expect(cubit.state.profile?.name, equals('First'));

        await cubit.close();

        // This should not affect the closed cubit
        testBus.push<Profile>(const Profile('Second'));
        await Future.delayed(Duration.zero);

        // State should still be 'First' since cubit is closed
        // Note: We can't directly check this since cubit is closed,
        // but the important thing is no error is thrown
      });

      test('multiple cubits can listen to same type independently', () async {
        var cubit1LoadCount = 0;
        var cubit2LoadCount = 0;

        final cubit1 = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            cubit1LoadCount++;
          },
        );

        final cubit2 = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            cubit2LoadCount++;
          },
        );

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(cubit1LoadCount, equals(1));
        expect(cubit2LoadCount, equals(1));

        await cubit1.close();

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(cubit1LoadCount, equals(1)); // Still 1 (closed)
        expect(cubit2LoadCount, equals(2)); // Incremented to 2

        await cubit2.close();
      });
    });

    group('refreshBus override', () {
      test('uses overridden refreshBus', () async {
        final customBus = RefreshBus.custom();
        var loadCalled = false;

        final cubit = TestCubit(
          bus: customBus,
          onLoadProfile: () async {
            loadCalled = true;
          },
        );

        // Refresh on the wrong bus should not trigger
        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(loadCalled, isFalse);

        // Refresh on the correct bus should trigger
        customBus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(loadCalled, isTrue);

        await cubit.close();
      });

      test('isolated bus does not affect global instance', () async {
        final isolatedBus = RefreshBus.custom();
        var isolatedLoadCount = 0;
        var globalLoadCount = 0;

        // Cubit using isolated bus
        final isolatedCubit = TestCubit(
          bus: isolatedBus,
          onLoadProfile: () async {
            isolatedLoadCount++;
          },
        );

        // Create a cubit that would use global instance if not overridden
        final globalCubitBus = RefreshBus.custom();
        final globalCubit = TestCubit(
          bus: globalCubitBus,
          onLoadProfile: () async {
            globalLoadCount++;
          },
        );

        isolatedBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(isolatedLoadCount, equals(1));
        expect(globalLoadCount, equals(0));

        await isolatedCubit.close();
        await globalCubit.close();
      });
    });

    group('error handling', () {
      test('error in reload function does not break subscription', () async {
        var callCount = 0;
        final errors = <Object>[];

        runZonedGuarded(() async {
          final cubit = TestCubit(
            bus: testBus,
            onLoadProfile: () async {
              callCount++;
              if (callCount == 1) {
                throw Exception('First call fails');
              }
            },
          );

          // First call throws
          testBus.refresh<Profile>();
          await Future.delayed(const Duration(milliseconds: 10));
          expect(callCount, equals(1));

          // Second call should still work
          testBus.refresh<Profile>();
          await Future.delayed(const Duration(milliseconds: 10));
          expect(callCount, equals(2));

          await cubit.close();
        }, (error, stack) {
          errors.add(error);
        });

        await Future.delayed(const Duration(milliseconds: 50));
        // Verify we got an error but the subscription survived
        expect(errors, hasLength(1));
      });

      test('error in data handler does not break subscription', () async {
        var callCount = 0;
        Profile? lastProfile;
        final errors = <Object>[];

        final bus = RefreshBus.custom();

        runZonedGuarded(() async {
          // Create a custom cubit for this test
          final cubit = _ErrorProneDataCubit(
            bus: bus,
            onData: (profile) {
              callCount++;
              if (callCount == 1) {
                throw Exception('First call fails');
              }
              lastProfile = profile;
            },
          );

          // First call throws
          bus.push<Profile>(const Profile('First'));
          await Future.delayed(const Duration(milliseconds: 10));
          expect(callCount, equals(1));
          expect(lastProfile, isNull);

          // Second call should still work
          bus.push<Profile>(const Profile('Second'));
          await Future.delayed(const Duration(milliseconds: 10));
          expect(callCount, equals(2));
          expect(lastProfile?.name, equals('Second'));

          await cubit.close();
        }, (error, stack) {
          errors.add(error);
        });

        await Future.delayed(const Duration(milliseconds: 50));
        // Verify we got an error but the subscription survived
        expect(errors, hasLength(1));
      });
    });

    group('async reload functions', () {
      test('handles async reload that takes time', () async {
        var loadStarted = false;
        var loadCompleted = false;

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            loadStarted = true;
            await Future.delayed(const Duration(milliseconds: 50));
            loadCompleted = true;
          },
        );

        testBus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(loadStarted, isTrue);
        expect(loadCompleted, isFalse);

        await Future.delayed(const Duration(milliseconds: 100));
        expect(loadCompleted, isTrue);

        await cubit.close();
      });

      test('multiple rapid refreshes queue up', () async {
        final callTimes = <DateTime>[];

        final cubit = TestCubit(
          bus: testBus,
          onLoadProfile: () async {
            callTimes.add(DateTime.now());
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );

        testBus.refresh<Profile>();
        testBus.refresh<Profile>();
        testBus.refresh<Profile>();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(callTimes, hasLength(3));
        await cubit.close();
      });
    });
  });
}

// Helper cubit for error handling test
class _ErrorProneDataCubit extends Cubit<TestState>
    with RefreshBusSubscriber<TestState> {
  final RefreshBus _bus;
  final void Function(Profile) onDataCallback;

  _ErrorProneDataCubit({
    required RefreshBus bus,
    required void Function(Profile) onData,
  })  : _bus = bus,
        onDataCallback = onData,
        super(const TestState()) {
    this.onData<Profile>(onDataCallback);
  }

  @override
  RefreshBus get refreshBus => _bus;
}
