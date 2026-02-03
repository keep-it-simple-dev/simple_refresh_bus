# 1.0.0

- feat: initial release
- feat: `RefreshBus` singleton for cross-cubit communication
- feat: `refresh<T>()` method to emit refresh signals
- feat: `push<T>()` method to pass data directly
- feat: `RefreshBusSubscriber` mixin for cubits
- feat: `onRefresh<T>()` to listen for refresh signals
- feat: `onData<T>()` to listen for data updates
- feat: automatic subscription cleanup on cubit close
- feat: `RefreshBus.custom()` factory for testing isolation
