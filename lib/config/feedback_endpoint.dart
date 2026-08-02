/// Cloudflare Worker that receives feedback submissions.
///
/// Served from our own zone so that Cloudflare's zone-scoped WAF and
/// rate-limiting rules can reach it — they cannot be applied to a `workers.dev`
/// hostname. The same Worker still answers on
/// `https://introibo-feedback.mfgarvin.workers.dev/feedback`, which is what
/// already-installed beta APKs point at; that route stays enabled until no beta
/// installs remain in the wild (see `worker/wrangler.toml`).
///
/// Override at build time with `--dart-define=FEEDBACK_ENDPOINT=https://...`.
const String kFeedbackEndpoint = String.fromEnvironment(
  'FEEDBACK_ENDPOINT',
  defaultValue: 'https://api.parishfinder.app/feedback',
);

/// Whether the endpoint is configured to a real URL (vs. the placeholder).
bool get feedbackEndpointConfigured =>
    !kFeedbackEndpoint.contains('example.workers.dev');
