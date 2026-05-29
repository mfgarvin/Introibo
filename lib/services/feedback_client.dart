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

  try {
    final resp = await http
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
    return FeedbackResult.fail(errMsg ?? 'Server returned ${resp.statusCode}');
  } catch (e) {
    return FeedbackResult.fail('Network error: $e');
  }
}
