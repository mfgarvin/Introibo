import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/feedback_endpoint.dart';
import '../utils/app_version.dart';

/// Outcome of a feedback submission.
class FeedbackResult {
  final bool ok;
  final String? error;
  const FeedbackResult.ok() : ok = true, error = null;
  const FeedbackResult.fail(this.error) : ok = false;
}

/// What the user sees when the request never reached the Worker.
///
/// Every failure here is the same fact to someone standing in a parish hall
/// with no signal — no DNS, no route, a TLS handshake that never completed, a
/// timeout — and the raw exception was being printed inline between the
/// comment box and the Submit button ("ClientException with SocketException:
/// Failed host lookup: 'api.parishfinder.app' (OS Error: No address
/// associated with hostname, errno = 7)"). The detail goes to debugPrint,
/// where it helps someone who can act on it.
const String kUnreachableMessage =
    "Can't reach the server — are you connected to the internet?";

/// Test seam: the HTTP client a submission posts through. Production never
/// reassigns it; a test swaps in a MockClient to exercise the failure paths,
/// which are otherwise reachable only by unplugging the network.
@visibleForTesting
http.Client Function() feedbackClientFactory = http.Client.new;

/// A reply the Worker did not word itself.
///
/// The Worker answers its own errors as JSON, which passes through verbatim.
/// This is for the ones that never reach it: Cloudflare's zone-level WAF and
/// rate limiting answer with an HTML page, so the JSON decode fails and
/// without this the user was shown "Server returned 429".
String _serverErrorMessage(int status) {
  if (status == 429) {
    return 'Too many messages just now — please try again in a few minutes.';
  }
  if (status >= 500) {
    return 'Something went wrong on our end. Please try again in a moment.';
  }
  return "That didn't go through. Please try again.";
}

String _platformLabel() {
  if (kIsWeb) return 'web';
  try {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
  } catch (_) {}
  return 'unknown';
}

/// Posts a feedback submission to the Cloudflare Worker. The body shape mirrors
/// the `FeedbackBody` interface in `worker/src/index.ts`.
Future<FeedbackResult> submitFeedback({
  required String kind,
  required String body,
  String? parishName,
  String? parishId,
  String? status,
  List<String>? issueCategories,
  String? replyEmail,
}) async {
  if (!feedbackEndpointConfigured) {
    return const FeedbackResult.fail(
      'Feedback endpoint not configured yet — please try again later.',
    );
  }

  final payload = <String, dynamic>{
    'kind': kind,
    'body': body,
    if (parishName != null) 'parish_name': parishName,
    if (parishId != null) 'parish_id': parishId,
    if (status != null) 'status': status,
    if (issueCategories != null && issueCategories.isNotEmpty)
      'issue_categories': issueCategories,
    if (replyEmail != null && replyEmail.isNotEmpty) 'reply_email': replyEmail,
    'app_version': AppVersion.version,
    'build_number': AppVersion.buildNumber,
    'platform': _platformLabel(),
  };

  final client = feedbackClientFactory();
  try {
    final resp = await client
        .post(
          Uri.parse(kFeedbackEndpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) return const FeedbackResult.ok();

    String? errMsg;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['error'] is String) {
        errMsg = decoded['error'] as String;
      }
    } catch (_) {}
    return FeedbackResult.fail(errMsg ?? _serverErrorMessage(resp.statusCode));
  } catch (e) {
    // The detail is for whoever can fix it, not for the person trying to
    // report a wrong Mass time.
    debugPrint('feedback submit failed: $e');
    return const FeedbackResult.fail(kUnreachableMessage);
  } finally {
    client.close();
  }
}
