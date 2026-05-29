/// Cloudflare Worker that receives feedback submissions.
///
/// Replace with the URL printed by `wrangler deploy` from the `worker/`
/// directory. Until set, submissions will fail with a clear error.
///
/// Override at build time with `--dart-define=FEEDBACK_ENDPOINT=https://...`.
const String kFeedbackEndpoint = String.fromEnvironment(
  'FEEDBACK_ENDPOINT',
  defaultValue: 'https://introibo-feedback.example.workers.dev/feedback',
);

/// Whether the endpoint is configured to a real URL (vs. the placeholder).
bool get feedbackEndpointConfigured =>
    !kFeedbackEndpoint.contains('example.workers.dev');
