// Submitting feedback with no signal used to print the raw exception inline,
// between the comment box and the Submit button:
//
//   Network error: ClientException with SocketException: Failed host lookup:
//   'api.parishfinder.app' (OS Error: No address associated with hostname,
//   errno = 7), uri=https://api.parishfinder.app/feedback
//
// Someone standing in a parish hall reporting a wrong Mass time cannot act on
// any of that. These pin what they see instead — and, just as much, that the
// Worker's own wording is still allowed through.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parishfinder/services/feedback_client.dart';

Future<FeedbackResult> _submit() => submitFeedback(
      kind: 'parish_data',
      body: 'The Saturday vigil is at 4:30, not 4:00.',
      parishName: 'Saint Test Parish',
      parishId: '0001',
      status: 'issue',
    );

void _respondWith(http.Client Function() factory) =>
    feedbackClientFactory = factory;

void main() {
  tearDown(() => feedbackClientFactory = http.Client.new);

  group('cannot reach the server', () {
    test('a dead network reads as a question, not a stack trace', () async {
      _respondWith(() => MockClient((_) async {
            throw const SocketExceptionStub();
          }));

      final r = await _submit();

      expect(r.ok, isFalse);
      expect(r.error, kUnreachableMessage);
      expect(r.error, contains('connected to the internet'));
      for (final jargon in [
        'Exception',
        'errno',
        'SocketException',
        'uri=',
        'http',
      ]) {
        expect(r.error, isNot(contains(jargon)),
            reason: '"$jargon" is not something a user can act on');
      }
    });

    test('a timeout reads the same as no network', () async {
      _respondWith(() => MockClient((_) async {
            throw TimeoutException('timed out');
          }));

      expect((await _submit()).error, kUnreachableMessage);
    });
  });

  group('the server answered', () {
    test('a success is a success', () async {
      _respondWith(() => MockClient((_) async => http.Response('{"ok":true}', 200)));

      expect((await _submit()).ok, isTrue);
    });

    test("the Worker's own wording passes through untouched", () async {
      // The charset matters: http.Response encodes a String body as latin1
      // unless the content type says otherwise, and the Worker's em dash is
      // not representable there — it would throw and land in the catch.
      _respondWith(() => MockClient((_) async => http.Response(
            '{"ok":false,"error":"rate limit exceeded — try again later"}',
            429,
            headers: const {
              'content-type': 'application/json; charset=utf-8'
            },
          )));

      final r = await _submit();
      expect(r.ok, isFalse);
      expect(r.error, 'rate limit exceeded — try again later');
    });

    test('a Cloudflare rate limit is not "Server returned 429"', () async {
      // Zone-level WAF and rate limiting answer with an HTML page, so the JSON
      // decode fails and there is no Worker message to fall back on.
      _respondWith(() => MockClient(
          (_) async => http.Response('<html>rate limited</html>', 429)));

      final r = await _submit();
      expect(r.error, contains('try again in a few minutes'));
      expect(r.error, isNot(contains('429')));
    });

    test('a 500 blames us, not the user', () async {
      _respondWith(() => MockClient(
          (_) async => http.Response('<html>bad gateway</html>', 502)));

      final r = await _submit();
      expect(r.error, contains('on our end'));
      expect(r.error, isNot(contains('502')));
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() =>
      "ClientException with SocketException: Failed host lookup: "
      "'api.parishfinder.app' (OS Error: No address associated with "
      "hostname, errno = 7), uri=https://api.parishfinder.app/feedback";
}
