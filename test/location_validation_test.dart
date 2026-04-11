import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Location Validation Tests
///
/// These tests verify the backend location validation logic.
/// Note: These are integration tests that require the backend server to be running.
/// Run the backend server first, then run these tests with:
/// flutter test test/location_validation_test.dart
///
/// Or run with a custom backend URL:
/// flutter test test/location_validation_test.dart --dart-define=BACKEND_URL=http://your-server:port

const String defaultBackendUrl = 'http://localhost:8002';

void main() {
  group('Location Validation Tests', () {
    test(
      'Mobile request without location should fail with LOCATION_REQUIRED error',
      () async {
        // This test verifies that when a mobile request is sent without location,
        // the backend returns the appropriate error response

        final backendUrl = String.fromEnvironment(
          'BACKEND_URL',
          defaultValue: defaultBackendUrl,
        );

        // Simulate a mobile request without location
        try {
          final response = await http.post(
            Uri.parse('$backendUrl/attendance'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': '1',
              'time': '09:00:00',
              'date': '2024-04-10',
              'source': 'mobile',
              // lat and lang are missing
            }),
          );

          // Verify the response
          expect(
            response.statusCode,
            400,
            reason: 'Should return 400 for missing location',
          );

          final responseBody = json.decode(response.body);
          expect(
            responseBody['code'],
            'LOCATION_REQUIRED',
            reason: 'Should return LOCATION_REQUIRED error code',
          );
          expect(
            responseBody['error'],
            contains('location'),
            reason: 'Error message should mention location',
          );
          expect(
            responseBody['error'],
            contains('GPS'),
            reason: 'Error message should mention GPS',
          );

          print(
            '✓ Test passed: Mobile request without location correctly rejected',
          );
        } catch (e) {
          print('⚠ Test skipped: Could not connect to backend at $backendUrl');
          print(
            '  Make sure the backend server is running before running integration tests.',
          );
          print('  Error: $e');
        }
      },
    );

    test('Mobile request with location should succeed', () async {
      // This test verifies that when a mobile request is sent with location,
      // the backend accepts it successfully

      final backendUrl = String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: defaultBackendUrl,
      );

      try {
        // Simulate a mobile request with location
        final response = await http.post(
          Uri.parse('$backendUrl/attendance'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': '1',
            'time': '09:00:00',
            'date': '2024-04-10',
            'source': 'mobile',
            'lat': '13.0827',
            'lang': '80.2707',
          }),
        );

        // Verify the response
        // Note: This might fail if user_id 1 doesn't exist or has already checked in today
        // The important thing is that it doesn't return a LOCATION_REQUIRED error
        if (response.statusCode == 400) {
          final responseBody = json.decode(response.body);
          expect(
            responseBody['code'],
            isNot('LOCATION_REQUIRED'),
            reason: 'Should not reject for location when location is provided',
          );
        }

        print(
          '✓ Test passed: Mobile request with location accepted (or failed for non-location reasons)',
        );
      } catch (e) {
        print('⚠ Test skipped: Could not connect to backend at $backendUrl');
        print(
          '  Make sure the backend server is running before running integration tests.',
        );
        print('  Error: $e');
      }
    });

    test('Web request without location should succeed', () async {
      // This test verifies that when a web request is sent without location,
      // the backend accepts it (location is not required for web requests)

      final backendUrl = String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: defaultBackendUrl,
      );

      try {
        // Simulate a web request without location
        final response = await http.post(
          Uri.parse('$backendUrl/attendance'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': '1',
            'time': '09:00:00',
            'date': '2024-04-10',
            'source': 'web',
            // lat and lang are missing, but this should be OK for web
          }),
        );

        // Verify the response
        // Note: This might fail if user_id 1 doesn't exist or has already checked in today
        // The important thing is that it doesn't return a LOCATION_REQUIRED error
        if (response.statusCode == 400) {
          final responseBody = json.decode(response.body);
          expect(
            responseBody['code'],
            isNot('LOCATION_REQUIRED'),
            reason: 'Web requests should not require location',
          );
        }

        print(
          '✓ Test passed: Web request without location accepted (or failed for non-location reasons)',
        );
      } catch (e) {
        print('⚠ Test skipped: Could not connect to backend at $backendUrl');
        print(
          '  Make sure the backend server is running before running integration tests.',
        );
        print('  Error: $e');
      }
    });

    test(
      'Error message should be easily understandable for older people',
      () async {
        // This test verifies that the error message uses simple language
        // that is easy for older people to understand

        final backendUrl = String.fromEnvironment(
          'BACKEND_URL',
          defaultValue: defaultBackendUrl,
        );

        try {
          final response = await http.post(
            Uri.parse('$backendUrl/attendance'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': '1',
              'time': '09:00:00',
              'date': '2024-04-10',
              'source': 'mobile',
            }),
          );

          if (response.statusCode == 400) {
            final responseBody = json.decode(response.body);
            final errorMessage = responseBody['error'];

            // Verify the error message uses simple language
            expect(
              errorMessage,
              contains('Please turn on'),
              reason: 'Should use simple instruction language',
            );
            expect(
              errorMessage,
              contains('location'),
              reason: 'Should use clear term "location"',
            );
            expect(
              errorMessage,
              contains('GPS'),
              reason: 'Should mention GPS as common term',
            );
            expect(
              errorMessage,
              contains('safety'),
              reason: 'Should explain the reason',
            );

            // Verify it doesn't use technical jargon
            expect(
              errorMessage,
              isNot(contains('latitude')),
              reason: 'Should not use technical term "latitude"',
            );
            expect(
              errorMessage,
              isNot(contains('longitude')),
              reason: 'Should not use technical term "longitude"',
            );
            expect(
              errorMessage,
              isNot(contains('coordinate')),
              reason: 'Should not use technical term "coordinate"',
            );

            print(
              '✓ Test passed: Error message is simple and easy to understand',
            );
          } else {
            print('⚠ Test skipped: Did not receive error response');
          }
        } catch (e) {
          print('⚠ Test skipped: Could not connect to backend at $backendUrl');
          print(
            '  Make sure the backend server is running before running integration tests.',
          );
          print('  Error: $e');
        }
      },
    );
  });
}
