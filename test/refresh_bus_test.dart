import 'package:flutter_test/flutter_test.dart';
import 'package:simple_refresh_bus/simple_refresh_bus.dart';

// Test model classes
class Profile {
  final String name;
  const Profile(this.name);
}

class Dashboard {
  final int count;
  const Dashboard(this.count);
}

void main() {
  group('RefreshBus', () {
    group('singleton', () {
      test('instance returns the same instance', () {
        final instance1 = RefreshBus.instance;
        final instance2 = RefreshBus.instance;
        expect(identical(instance1, instance2), isTrue);
      });

      test('custom() creates a new isolated instance', () {
        final custom = RefreshBus.custom();
        expect(identical(custom, RefreshBus.instance), isFalse);
      });

      test('custom instances are independent', () {
        final custom1 = RefreshBus.custom();
        final custom2 = RefreshBus.custom();
        expect(identical(custom1, custom2), isFalse);
      });
    });

    group('refresh()', () {
      late RefreshBus bus;

      setUp(() {
        bus = RefreshBus.custom();
      });

      test('emits Refresh<T> signal', () async {
        final signals = <Refresh<Profile>>[];
        bus.onRefreshStream<Profile>().listen(signals.add);

        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(signals, hasLength(1));
        expect(signals.first, isA<Refresh<Profile>>());
      });

      test('emits multiple signals in order', () async {
        final signals = <Refresh<Profile>>[];
        bus.onRefreshStream<Profile>().listen(signals.add);

        bus.refresh<Profile>();
        bus.refresh<Profile>();
        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(signals, hasLength(3));
      });

      test('different types emit independent signals', () async {
        final profileSignals = <Refresh<Profile>>[];
        final dashboardSignals = <Refresh<Dashboard>>[];

        bus.onRefreshStream<Profile>().listen(profileSignals.add);
        bus.onRefreshStream<Dashboard>().listen(dashboardSignals.add);

        bus.refresh<Profile>();
        bus.refresh<Dashboard>();
        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(profileSignals, hasLength(2));
        expect(dashboardSignals, hasLength(1));
      });

      test('only matching type receives signal', () async {
        final profileSignals = <Refresh<Profile>>[];
        bus.onRefreshStream<Profile>().listen(profileSignals.add);

        bus.refresh<Dashboard>();
        await Future.delayed(Duration.zero);

        expect(profileSignals, isEmpty);
      });
    });

    group('push()', () {
      late RefreshBus bus;

      setUp(() {
        bus = RefreshBus.custom();
      });

      test('emits data of type T', () async {
        final dataList = <Profile>[];
        bus.onDataStream<Profile>().listen(dataList.add);

        const profile = Profile('Test');
        bus.push<Profile>(profile);
        await Future.delayed(Duration.zero);

        expect(dataList, hasLength(1));
        expect(dataList.first.name, equals('Test'));
      });

      test('emits multiple data items in order', () async {
        final dataList = <Profile>[];
        bus.onDataStream<Profile>().listen(dataList.add);

        bus.push<Profile>(const Profile('First'));
        bus.push<Profile>(const Profile('Second'));
        bus.push<Profile>(const Profile('Third'));
        await Future.delayed(Duration.zero);

        expect(dataList, hasLength(3));
        expect(dataList[0].name, equals('First'));
        expect(dataList[1].name, equals('Second'));
        expect(dataList[2].name, equals('Third'));
      });

      test('different types emit independent data', () async {
        final profileData = <Profile>[];
        final dashboardData = <Dashboard>[];

        bus.onDataStream<Profile>().listen(profileData.add);
        bus.onDataStream<Dashboard>().listen(dashboardData.add);

        bus.push<Profile>(const Profile('Test'));
        bus.push<Dashboard>(const Dashboard(42));
        bus.push<Profile>(const Profile('Another'));
        await Future.delayed(Duration.zero);

        expect(profileData, hasLength(2));
        expect(dashboardData, hasLength(1));
        expect(dashboardData.first.count, equals(42));
      });

      test('only matching type receives data', () async {
        final profileData = <Profile>[];
        bus.onDataStream<Profile>().listen(profileData.add);

        bus.push<Dashboard>(const Dashboard(42));
        await Future.delayed(Duration.zero);

        expect(profileData, isEmpty);
      });
    });

    group('onRefreshStream()', () {
      late RefreshBus bus;

      setUp(() {
        bus = RefreshBus.custom();
      });

      test('returns a broadcast stream', () {
        final stream = bus.onRefreshStream<Profile>();
        expect(stream.isBroadcast, isTrue);
      });

      test('multiple listeners receive the same signal', () async {
        final listener1 = <Refresh<Profile>>[];
        final listener2 = <Refresh<Profile>>[];

        bus.onRefreshStream<Profile>().listen(listener1.add);
        bus.onRefreshStream<Profile>().listen(listener2.add);

        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(listener1, hasLength(1));
        expect(listener2, hasLength(1));
      });

      test('filters by exact type', () async {
        final signals = <Object>[];
        bus.onRefreshStream<Profile>().listen(signals.add);

        bus.refresh<Profile>();
        bus.refresh<Dashboard>();
        await Future.delayed(Duration.zero);

        expect(signals, hasLength(1));
        expect(signals.first, isA<Refresh<Profile>>());
      });
    });

    group('onDataStream()', () {
      late RefreshBus bus;

      setUp(() {
        bus = RefreshBus.custom();
      });

      test('returns a broadcast stream', () {
        final stream = bus.onDataStream<Profile>();
        expect(stream.isBroadcast, isTrue);
      });

      test('multiple listeners receive the same data', () async {
        final listener1 = <Profile>[];
        final listener2 = <Profile>[];

        bus.onDataStream<Profile>().listen(listener1.add);
        bus.onDataStream<Profile>().listen(listener2.add);

        bus.push<Profile>(const Profile('Shared'));
        await Future.delayed(Duration.zero);

        expect(listener1, hasLength(1));
        expect(listener2, hasLength(1));
        expect(listener1.first.name, equals('Shared'));
        expect(listener2.first.name, equals('Shared'));
      });

      test('filters by exact type', () async {
        final data = <Object>[];
        bus.onDataStream<Profile>().listen(data.add);

        bus.push<Profile>(const Profile('Test'));
        bus.push<Dashboard>(const Dashboard(42));
        await Future.delayed(Duration.zero);

        expect(data, hasLength(1));
        expect(data.first, isA<Profile>());
      });
    });

    group('isolation', () {
      test('custom instances do not share signals', () async {
        final bus1 = RefreshBus.custom();
        final bus2 = RefreshBus.custom();

        final signals1 = <Refresh<Profile>>[];
        final signals2 = <Refresh<Profile>>[];

        bus1.onRefreshStream<Profile>().listen(signals1.add);
        bus2.onRefreshStream<Profile>().listen(signals2.add);

        bus1.refresh<Profile>();
        await Future.delayed(Duration.zero);

        expect(signals1, hasLength(1));
        expect(signals2, isEmpty);
      });

      test('custom instances do not share data', () async {
        final bus1 = RefreshBus.custom();
        final bus2 = RefreshBus.custom();

        final data1 = <Profile>[];
        final data2 = <Profile>[];

        bus1.onDataStream<Profile>().listen(data1.add);
        bus2.onDataStream<Profile>().listen(data2.add);

        bus1.push<Profile>(const Profile('Bus1'));
        await Future.delayed(Duration.zero);

        expect(data1, hasLength(1));
        expect(data2, isEmpty);
      });

      test('refresh and data streams are independent', () async {
        final bus = RefreshBus.custom();

        final refreshSignals = <Refresh<Profile>>[];
        final dataSignals = <Profile>[];

        bus.onRefreshStream<Profile>().listen(refreshSignals.add);
        bus.onDataStream<Profile>().listen(dataSignals.add);

        bus.refresh<Profile>();
        bus.push<Profile>(const Profile('Test'));
        await Future.delayed(Duration.zero);

        expect(refreshSignals, hasLength(1));
        expect(dataSignals, hasLength(1));
      });
    });

    group('subscription cancellation', () {
      test('cancelled subscription does not receive signals', () async {
        final bus = RefreshBus.custom();
        final signals = <Refresh<Profile>>[];

        final subscription = bus.onRefreshStream<Profile>().listen(signals.add);

        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(signals, hasLength(1));

        await subscription.cancel();

        bus.refresh<Profile>();
        await Future.delayed(Duration.zero);
        expect(signals, hasLength(1)); // Still 1, not 2
      });

      test('cancelled subscription does not receive data', () async {
        final bus = RefreshBus.custom();
        final data = <Profile>[];

        final subscription = bus.onDataStream<Profile>().listen(data.add);

        bus.push<Profile>(const Profile('First'));
        await Future.delayed(Duration.zero);
        expect(data, hasLength(1));

        await subscription.cancel();

        bus.push<Profile>(const Profile('Second'));
        await Future.delayed(Duration.zero);
        expect(data, hasLength(1)); // Still 1, not 2
      });
    });
  });
}
