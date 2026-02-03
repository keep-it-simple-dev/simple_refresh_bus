import 'dart:async';

import 'package:simple_refresh_bus/src/refresh.dart';

/// Event bus for cross-cubit state synchronization.
///
/// Uses a global singleton - no DI required:
/// ```dart
/// RefreshBus.instance.refresh<Profile>();
/// RefreshBus.instance.push<Profile>(newProfile);
/// ```
///
/// Two types of signals:
/// - **refresh()** - Signal only, triggers `onRefresh` listeners to reload
/// - **push()** - Data signal, triggers `onData` listeners with actual data
///
/// This allows efficient state sync:
/// - Use `push()` when you have the data (avoids redundant API calls)
/// - Use `refresh()` when you just know data changed but don't have it
class RefreshBus {
  /// Global singleton instance. Use this by default.
  static final RefreshBus instance = RefreshBus._();

  /// Private constructor for singleton.
  RefreshBus._();

  /// Create a custom instance (for testing, isolation, etc.)
  factory RefreshBus.custom() => RefreshBus._();

  final _refreshController = StreamController<Object>.broadcast();
  final _dataController = StreamController<Object>.broadcast();

  /// Emit a refresh signal for type [T].
  ///
  /// Triggers `onRefresh<T>` listeners, which typically reload from API.
  ///
  /// Example:
  /// ```dart
  /// // After profile update when response doesn't include new data
  /// RefreshBus.instance.refresh<Profile>();
  /// ```
  void refresh<T extends Object>() => _refreshController.add(Refresh<T>());

  /// Push data of type [T].
  ///
  /// Triggers `onData<T>` listeners with the actual data.
  /// Use this when you already have the updated data to avoid
  /// redundant API calls.
  ///
  /// Example:
  /// ```dart
  /// // After profile update when response includes the new profile
  /// RefreshBus.instance.push<Profile>(updatedProfile);
  /// ```
  void push<T extends Object>(T data) => _dataController.add(data);

  /// Stream of refresh signals for type [T].
  Stream<Refresh<T>> onRefreshStream<T extends Object>() =>
      _refreshController.stream.where((e) => e is Refresh<T>).cast<Refresh<T>>();

  /// Stream of data for type [T].
  Stream<T> onDataStream<T extends Object>() =>
      _dataController.stream.where((e) => e is T).cast<T>();
}
