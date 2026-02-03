/// Signal that data of type [T] should be refreshed.
///
/// This is a marker class used by [RefreshBus] to signal that data
/// of a specific type has changed and listeners should reload.
///
/// Example:
/// ```dart
/// // In repository after successful update
/// RefreshBus.instance.refresh<Profile>();
///
/// // In cubit
/// onRefresh<Profile>(load);
/// ```
class Refresh<T extends Object> {
  const Refresh();
}
