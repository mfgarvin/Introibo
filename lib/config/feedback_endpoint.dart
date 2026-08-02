/// Cloudflare Worker that receives feedback submissions.
///
/// Served from our own zone so that Cloudflare's zone-scoped WAF and
/// rate-limiting rules can reach it — they cannot be applied to a `workers.dev`
/// hostname. The Worker's old `introibo-feedback.mfgarvin.workers.dev` route was
/// retired 2026-08-02, so this is now the only endpoint; beta APKs built before
/// then cannot submit feedback (the app surfaces a clear error on failure).
///
/// Override at build time with `--dart-define=FEEDBACK_ENDPOINT=https://...`.
const String kFeedbackEndpoint = String.fromEnvironment(
  'FEEDBACK_ENDPOINT',
  defaultValue: 'https://api.parishfinder.app/feedback',
);

/// Whether the endpoint is configured to a real URL (vs. the placeholder).
bool get feedbackEndpointConfigured =>
    !kFeedbackEndpoint.contains('example.workers.dev');
