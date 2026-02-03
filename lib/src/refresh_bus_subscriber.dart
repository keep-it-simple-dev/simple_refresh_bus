import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_refresh_bus/src/refresh_bus.dart';

/// Mixin for Cubits and Blocs to subscribe to [RefreshBus] events.
///
/// Uses [RefreshBus.instance] by default - zero configuration needed!
/// Subscriptions are automatically cancelled when the cubit/bloc is closed.
///
/// Example with Cubit:
/// ```dart
/// class ProfileGetCubit extends Cubit<ProfileGetState> with RefreshBusSubscriber {
///   ProfileGetCubit(this._repo) : super(const ProfileGetState()) {
///     // Listen for refresh signals - will reload from API
///     onRefresh<Profile>(load);
///
///     // Listen for actual data - will use it directly (no API call)
///     onData<Profile>((profile) => emit(state.copyWith(
///       status: ProfileGetStatus.success,
///       profile: profile,
///     )));
///   }
/// }
/// ```
///
/// Example with Bloc:
/// ```dart
/// class ProfileBloc extends Bloc<ProfileEvent, ProfileState> with RefreshBusSubscriber {
///   ProfileBloc() : super(const ProfileState()) {
///     on<ProfileLoadRequested>(_onLoadRequested);
///     onRefresh<Profile>(() async => add(ProfileLoadRequested()));
///   }
/// }
/// ```
mixin RefreshBusSubscriber<State> on BlocBase<State> {
  final List<StreamSubscription<dynamic>> _refreshBusSubscriptions = [];

  /// The [RefreshBus] instance. Override for testing or custom instances.
  /// Defaults to the global singleton.
  RefreshBus get refreshBus => RefreshBus.instance;

  /// Listen for refresh signals of type [T].
  ///
  /// Called when `RefreshBus.instance.refresh<T>()` is invoked.
  /// Typically used to trigger a reload from the API.
  ///
  /// Example:
  /// ```dart
  /// onRefresh<Profile>(load);
  /// ```
  void onRefresh<T extends Object>(Future<void> Function() reload) {
    _refreshBusSubscriptions.add(
      refreshBus.onRefreshStream<T>().listen((_) => reload()),
    );
  }

  /// Listen for data of type [T].
  ///
  /// Called when `RefreshBus.instance.push<T>(data)` is invoked.
  /// Use this to directly update state without making an API call.
  ///
  /// Example:
  /// ```dart
  /// onData<Profile>((profile) => emit(state.copyWith(profile: profile)));
  /// ```
  void onData<T extends Object>(void Function(T data) handler) {
    _refreshBusSubscriptions.add(
      refreshBus.onDataStream<T>().listen(handler),
    );
  }

  @override
  Future<void> close() {
    for (final sub in _refreshBusSubscriptions) {
      sub.cancel();
    }
    return super.close();
  }
}
