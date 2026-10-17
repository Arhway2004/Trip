/// Source of the current time. Injected everywhere so domain rules and tests
/// never depend on the wall clock directly.
typedef Clock = DateTime Function();
