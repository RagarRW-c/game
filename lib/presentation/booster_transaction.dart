/// Owns one screen's booster payment and synchronous engine application.
/// Tile input remains independent. A stale paid action restores its resource.
class BoosterTransaction {
  bool _busy = false;
  Future<void> Function()? _pendingRefund;

  Future<bool> run({
    required bool free,
    required Future<bool> Function() pay,
    required Future<void> Function() refund,
    required bool Function() valid,
    required bool Function() apply,
    required void Function(Object, StackTrace) onError,
  }) async {
    if (_busy) return false;
    _busy = true;
    try {
      final recovery = _pendingRefund;
      if (recovery != null) {
        await recovery();
        _pendingRefund = null;
        return false; // Resource snapshots must be refreshed before another use.
      }
      if (!valid()) return false;
      if (!free && !await pay()) return false;
      // No await between final validation and the authoritative engine action.
      if (valid() && apply()) return true;
      if (!free) {
        _pendingRefund = refund;
        await refund();
        _pendingRefund = null;
      }
      return false;
    } catch (error, stack) {
      // Never automatically repeat a payment with an ambiguous commit outcome.
      onError(error, stack);
      return false;
    } finally {
      // Keep same-turn duplicate callbacks inside this activation, including
      // free uses. This yields a microtask, not animation or wall-clock time.
      await Future<void>.value();
      _busy = false;
    }
  }
}
