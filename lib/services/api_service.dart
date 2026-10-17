import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/payroll_month_data.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  /// Runtime-mutable base URL — can be changed from Dev Settings on the login screen.
  static String baseUrl = _savedOrDefault();
  static final storage = GetStorage();
  static Dio? _dio;

  static String _savedOrDefault() {
    final stored = GetStorage().read<String>('dev_base_url');
    if (stored != null && stored.isNotEmpty) return stored;

    final defaultIp = dotenv.env['DEFAULT_SERVER_IP'] ?? '103.160.163.70';
    final defaultPort = dotenv.env['DEFAULT_SERVER_PORT'] ?? '8002';
    return 'http://$defaultIp:$defaultPort';
  }

  static Future<Map<String, dynamic>> checkVersion(String version) async {
    try {
      final response = await _client().get(
        '$baseUrl/app/version-check',
        queryParameters: {'version': version},
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {
        'allowed': false,
        'unreachable': true,
        'message': 'Unable to reach server. Please check your network or server configuration.',
      };
    } catch (e) {
      print('❌ Version check failed: $e');
      return {
        'allowed': false,
        'unreachable': true,
        'message': 'Unable to reach server. Please check your network or server configuration.',
      };
    }
  }

  static Dio _client() {
    _dio ??= Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        validateStatus: (code) => true, // Handle all status codes manually in _postWithRetry
      ),
    );
    return _dio!;
  }

  static Future<Response<dynamic>> _postWithRetry({
    required String url,
    required FormData data,
    void Function(int sent, int total)? onSendProgress,
    int maxRetries = 5,
    Duration baseDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final res = await _client().post(
          url,
          data: data,
          onSendProgress: onSendProgress,
        );
        if (res.statusCode != null &&
            res.statusCode! >= 200 &&
            res.statusCode! < 300) {
          return res;
        }
        if (res.statusCode != null &&
            res.statusCode! >= 500 &&
            attempt < maxRetries) {
          final wait = baseDelay * (1 << attempt);
          await Future.delayed(wait);
          attempt++;
          continue;
        }
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      } on DioException catch (e) {
        final isNetwork =
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (!isNetwork || attempt >= maxRetries) rethrow;
        final results = await Connectivity().checkConnectivity();
        final online = results.any((r) => r != ConnectivityResult.none);
        if (!online) {
          final stream = Connectivity().onConnectivityChanged;
          final completer = Completer<void>();
          late StreamSubscription sub;
          sub = stream.listen((rs) {
            if (rs.any((r) => r != ConnectivityResult.none)) {
              sub.cancel();
              completer.complete();
            }
          });
          await completer.future.timeout(
            const Duration(minutes: 2),
            onTimeout: () async {
              await sub.cancel();
              return;
            },
          );
        } else {
          final wait = baseDelay * (1 << attempt);
          await Future.delayed(wait);
        }
        attempt++;
        continue;
      }
    }
  }

  // Login endpoint - Use dedicated login endpoint for secure authentication
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get all users; pass date (YYYY-MM-DD) to include each user's attendance_count for that day
  static Future<List<dynamic>> getUsers({String? date}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/users',
      ).replace(queryParameters: date != null ? {'date': date} : null);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load users');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get users whose birthday is today
  static Future<List<dynamic>> getBirthdays() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/birthdays'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load birthdays');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user profile by ID
  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load user profile');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }


  static Future<List<dynamic>> getUsersOnly({String? date, String? employeeType}) async {
    try {
      final queryParams = {
        'users_only': 'true',
        if (date != null) 'date': date,
        if (employeeType != null) 'employee_type': employeeType,
      };

      final uri = Uri.parse(
        '$baseUrl/users',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load users');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all attendance records
  static Future<List<dynamic>> getAttendance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load attendance records');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all sites
  static Future<List<dynamic>> getSites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sites'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load sites');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get permissions for a user (with pagination & month filter)
  static Future<Map<String, dynamic>> getPermissions(
    int userId, {
    String? month,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null && month.isNotEmpty) queryParams['month'] = month;
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/permissions/$userId').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return {'data': decoded, 'total': decoded.length};
        } else if (decoded is Map<String, dynamic>) {
          return {
            'data': decoded['data'] as List<dynamic>? ?? [],
            'total': decoded['total'] ?? (decoded['data'] as List<dynamic>? ?? []).length,
          };
        }
      }
      throw Exception('Failed to load permissions');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Request a permission
  static Future<Map<String, dynamic>> requestPermission(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/permissions/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to request permission');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create attendance record with image upload (Dio — real-time progress)
  static Future<Map<String, dynamic>> createAttendance(
    Map<String, dynamic> attendanceData,
    String imagePath, {
    String? lat,
    String? lang,
    String? site,
    void Function(int sent, int total)? onProgress,
    int maxRetries =
        0, // Set to 0 for non-idempotent operations to prevent duplicate uploads
  }) async {
    try {
      final formData = FormData.fromMap({
        'user_id': attendanceData['user_id'].toString(),
        'time': attendanceData['time'],
        'date': attendanceData['date'],
        'source': 'mobile',
        if (lat != null) 'lat': lat,
        if (lang != null) 'lang': lang,
        if (site != null) 'site': site,
        if (imagePath.isNotEmpty)
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: 'attendance.png',
          ),
      });

      final response = await _postWithRetry(
        url: '$baseUrl/attendance',
        data: formData,
        onSendProgress: (sent, total) => onProgress?.call(sent, total),
        maxRetries: maxRetries,
      );

      if (response.statusCode == 201)
        return response.data as Map<String, dynamic>;
      throw Exception('Failed to create attendance record: ${response.data}');
    } on DioException catch (e) {
      String errorMessage = 'Upload failed';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          errorMessage = data['error'] ?? data['message'] ?? data['msg'] ?? e.message ?? 'Unknown server error';
        } else {
          errorMessage = data.toString();
        }
      } else {
        errorMessage = e.message ?? 'Connection failed';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Bulk attendance — one image, multiple user IDs (Dio — real-time progress).
  static Future<Map<String, dynamic>> createBulkAttendance({
    required List<int> userIds,
    required String time,
    required String date,
    required String imagePath,
    String? lat,
    String? lang,
    String? site,
    void Function(int sent, int total)? onProgress,
    int maxRetries =
        0, // Set to 0 for non-idempotent operations to prevent duplicate uploads
  }) async {
    try {
      final formData = FormData.fromMap({
        'user_ids': json.encode(userIds),
        'time': time,
        'date': date,
        'source': 'mobile',
        if (lat != null) 'lat': lat,
        if (lang != null) 'lang': lang,
        if (site != null) 'site': site,
        if (imagePath.isNotEmpty)
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: 'attendance.png',
          ),
      });

      final response = await _postWithRetry(
        url: '$baseUrl/attendance/bulk',
        data: formData,
        onSendProgress: (sent, total) => onProgress?.call(sent, total),
        maxRetries: maxRetries,
      );

      if (response.statusCode == 201)
        return response.data as Map<String, dynamic>;
      throw Exception('Bulk attendance failed: ${response.data}');
    } on DioException catch (e) {
      String errorMessage = 'Bulk upload failed';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          errorMessage = data['error'] ?? data['message'] ?? data['msg'] ?? e.message ?? 'Unknown server error';
        } else {
          errorMessage = data.toString();
        }
      } else {
        errorMessage = e.message ?? 'Connection failed';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get today's attendance records for current user
  static Future<List<dynamic>> getTodaysAttendance(int userId) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // We fetch all records for the user without date filter to see the full context
      // The backend already orders by created_at DESC
      final endpointUrl = '$baseUrl/attendance?userid=$userId';
      print('📡 Frontend calling status-aware endpoint: $endpointUrl');

      final response = await http.get(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> allRecords = json.decode(response.body);

        if (allRecords.isEmpty) return [];

        final todayRecords = allRecords.where((r) => r['date'] == dateStr).toList();
        final yesterdayRecords = allRecords.where((r) => r['date'] == yesterdayStr).toList();

        // ── Status-Aware Recent Shift Retrieval ──
        
        // 1. If today has records, use them
        if (todayRecords.isNotEmpty) {
          todayRecords.sort((a, b) => (a['s_no'] ?? 0).compareTo(b['s_no'] ?? 0));
          return todayRecords;
        }

        // 2. If today is empty, check for an ACTIVE overnight shift from yesterday
        final openYesterday = yesterdayRecords.where((r) => r['s_no'] == 1).toList();
        final closedYesterday = yesterdayRecords.any((r) => r['s_no'] == 2);

        if (openYesterday.isNotEmpty && !closedYesterday) {
          print('🌙 Overnight shift detected: Showing active check-in from yesterday.');
          return openYesterday;
        }

        // 3. If today is empty, check if we COMPLETED an overnight shift recently (today)
        final completedOvernightToday = allRecords.where((r) {
          if (r['s_no'] != 2 || r['is_overnight'] != 1) return false;
          try {
            final createdAt = DateTime.parse(r['created_at']).toLocal();
            return createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
          } catch (_) { return false; }
        }).toList();

        if (completedOvernightToday.isNotEmpty) {
          final checkout = completedOvernightToday.first;
          final checkin = yesterdayRecords.firstWhere((r) => r['s_no'] == 1, orElse: () => null);
          if (checkin != null) {
            print('✅ Recently completed overnight shift found. Showing in status card.');
            return [checkin, checkout]..sort((a, b) => (a['s_no'] as int).compareTo(b['s_no'] as int));
          }
        }

        return [];

      } else {
        throw Exception('Failed to load attendance records');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get attendance summary for all dates for current user
  static Future<List<dynamic>> getAttendanceSummary(int userId) async {
    try {
      final endpointUrl = '$baseUrl/attendance/summary/$userId';
      print('📡 Frontend calling summary endpoint: $endpointUrl');

      final response = await http.get(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Summary response status: ${response.statusCode}');
      print('📡 Summary response body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> summaryData = json.decode(response.body);
        print('📊 Attendance summary data: $summaryData');
        return summaryData;
      } else {
        throw Exception('Failed to load attendance summary');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all users' attendance grouped by date (admin view)
  // Optional date range filter and pagination
  static Future<dynamic> getAdminAttendance({
    String? startDate,
    String? endDate,
    int limit = 20,
    int offset = 0,
    String? search,
    String? employeeType,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (employeeType != null && employeeType.isNotEmpty) queryParams['employee_type'] = employeeType;

      final uri = Uri.parse(
        '$baseUrl/admin/attendance',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      print('📡 Admin attendance endpoint: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Admin attendance response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load admin attendance: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ── Groupings ────────────────────────────────────────────────────────────

  /// Get all groupings, optionally filtered by date
  static Future<List<dynamic>> getGroupings({String? date}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/groupings',
      ).replace(queryParameters: date != null ? {'date': date} : null);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load groupings: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Add employees under a manager for a specific date
  static Future<Map<String, dynamic>> createGroupings({
    required int managerId,
    required List<int> employeeIds,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groupings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'manager_id': managerId,
          'employee_ids': employeeIds,
          'date': date,
        }),
      );
      if (response.statusCode == 201) return json.decode(response.body);
      throw Exception('Failed to create groupings: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Delete a single grouping row by id
  static Future<void> deleteGrouping(int groupingId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groupings/$groupingId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete grouping: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Delete all groupings for a manager on a specific date
  static Future<void> deleteManagerGroupings({
    required int managerId,
    required String date,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/groupings/manager/$managerId',
      ).replace(queryParameters: {'date': date});
      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete groupings: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get all users (reused from existing getUsers, but typed for groupings)
  static Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load users: ${response.body}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Update user profile (username, role, and optionally pfp)
  static Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String username,
    required String role,
    String? password,
    String? imagePath,
    void Function(int sent, int total)? onProgress,
    int maxRetries = 5,
  }) async {
    try {
      final formData = FormData.fromMap({
        'username': username,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
        if (imagePath != null && imagePath.isNotEmpty)
          'pfp': await MultipartFile.fromFile(
            imagePath,
            filename: 'pfp_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
      });

      Response response;
      int attempt = 0;
      while (true) {
        try {
          response = await _client().put(
            '$baseUrl/users/$userId',
            data: formData,
            onSendProgress: (sent, total) => onProgress?.call(sent, total),
          );
          break;
        } on DioException catch (e) {
          final isNetwork =
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout;
          if (!isNetwork || attempt >= maxRetries) rethrow;
          final results = await Connectivity().checkConnectivity();
          final online = results.any((r) => r != ConnectivityResult.none);
          if (!online) {
            final stream = Connectivity().onConnectivityChanged;
            final completer = Completer<void>();
            late StreamSubscription sub;
            sub = stream.listen((rs) {
              if (rs.any((r) => r != ConnectivityResult.none)) {
                sub.cancel();
                completer.complete();
              }
            });
            await completer.future.timeout(
              const Duration(minutes: 2),
              onTimeout: () async {
                await sub.cancel();
                return;
              },
            );
          } else {
            final wait = Duration(seconds: 1) * (1 << attempt);
            await Future.delayed(wait);
          }
          attempt++;
        }
      }

      if (response.statusCode == 200)
        return response.data as Map<String, dynamic>;
      throw Exception('Failed to update profile: ${response.data}');
    } on DioException catch (e) {
      throw Exception('Update failed: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get admin monthly summary for selected users
  static Future<Map<String, dynamic>> getAdminMonthlySummary(
    List<int> userIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['user_ids'] = json.encode(userIds);

      if (startDate != null) {
        queryParams['start_date'] =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      }
      if (endDate != null) {
        queryParams['end_date'] =
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      }

      final uri = Uri.parse(
        '$baseUrl/admin/monthly-summary',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      print('📡 Frontend calling admin monthly summary: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Admin monthly summary response status: ${response.statusCode}');
      print('📡 Admin monthly summary response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> summaryData = json.decode(response.body);
        print('📊 Admin monthly summary data: $summaryData');
        return summaryData;
      } else {
        throw Exception('Failed to load admin monthly summary');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get monthly total hours worked and OT for current month
  static Future<Map<String, dynamic>> getMonthlyAttendance(
    int userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['start_date'] =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      }
      if (endDate != null) {
        queryParams['end_date'] =
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      }

      final uri = Uri.parse(
        '$baseUrl/attendance/monthly/$userId',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      print('📡 Frontend calling monthly endpoint: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Monthly response status: ${response.statusCode}');
      print('📡 Monthly response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> monthlyData = json.decode(response.body);
        print('📊 Monthly attendance data: $monthlyData');
        return monthlyData;
      } else {
        throw Exception('Failed to load monthly attendance');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get monthly summary for payroll (matches web dashboard)
  static Future<Map<String, dynamic>> getMonthlySummary(
    int userId, {
    String? yearMonth, // Format: YYYY-MM
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['user_id'] = userId.toString();
      if (yearMonth != null) {
        queryParams['year_month'] = yearMonth;
      }

      final uri = Uri.parse(
        '$baseUrl/monthly-summary',
      ).replace(queryParameters: queryParams);

      print('📡 Frontend calling monthly summary: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Monthly summary response status: ${response.statusCode}');
      print('📡 Monthly summary response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> summaryData = json.decode(response.body);
        print('📊 Monthly summary data: $summaryData');
        return summaryData;
      } else if (response.statusCode == 404) {
        // Return empty data structure for 404 (no monthly record found)
        print('📊 No monthly record found, returning empty data');
        return {
          'attendance': {
            'total_complete_days': 0,
            'total_days_present': 0,
            'total_sunday_days': 0,
          },
          'formatted': {
            'total_regular': '0h 0m',
            'total_overtime': '0h 0m',
            'total_weekday_ot': '0h 0m',
            'total_sunday_ot': '0h 0m',
          },
          'days': [],
        };
      } else {
        throw Exception('Failed to load monthly summary');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get monthly performance
  static Future<Map<String, dynamic>> getMonthlyPerformance(
    int userId, {
    String? yearMonth,
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['user_id'] = userId.toString();
      if (yearMonth != null) {
        queryParams['year_month'] = yearMonth;
      }
      final uri = Uri.parse(
        '$baseUrl/monthly-performance',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Get dashboard stats for admin
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Dashboard stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        Map<String, dynamic> statsData = json.decode(response.body);
        print('📊 Dashboard stats data: $statsData');
        return statsData;
      } else {
        throw Exception('Failed to load dashboard stats');
      }
    } catch (e) {
      print('❌ Error fetching dashboard stats: $e');
      throw e;
    }
  }

  // Get active sites for today
  static Future<List<dynamic>> getActiveSites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sites/active'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Active sites response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> sitesData = json.decode(response.body);
        print('📊 Active sites data: $sitesData');
        return sitesData;
      } else {
        throw Exception('Failed to load active sites');
      }
    } catch (e) {
      print('❌ Error fetching active sites: $e');
      throw e;
    }
  }

  // Get daily breakdown for payroll (matches web dashboard)
  static Future<Map<String, dynamic>> getDailyBreakdown(
    int userId, {
    String? yearMonth, // Format: YYYY-MM
  }) async {
    try {
      final queryParams = <String, String>{};
      queryParams['user_id'] = userId.toString();
      if (yearMonth != null) {
        queryParams['year_month'] = yearMonth;
      }

      final uri = Uri.parse(
        '$baseUrl/daily-breakdown',
      ).replace(queryParameters: queryParams);

      print('📡 Frontend calling daily breakdown: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Daily breakdown response status: ${response.statusCode}');
      print('📡 Daily breakdown response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> breakdownData = json.decode(response.body);
        print('📊 Daily breakdown data: $breakdownData');
        return breakdownData;
      } else if (response.statusCode == 404) {
        // Return empty data structure for 404 (no daily records found)
        print('📊 No daily breakdown found, returning empty data');
        return {'days': []};
      } else {
        throw Exception('Failed to load daily breakdown');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all holidays
  static Future<List<dynamic>> getHolidays() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/holidays'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load holidays');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get OT Leaderboard
  static Future<Map<String, dynamic>> getLeaderboard({
    int? userId,
    String? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) queryParams['userId'] = userId.toString();
      if (month != null) queryParams['month'] = month;

      final uri = Uri.parse(
        '$baseUrl/employees/ot-leaderboard',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load leaderboard');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get Long Absentees
  static Future<Map<String, dynamic>> getLongAbsentees({
    int page = 1,
    int limit = 15,
    String? search,
    int minDays = 4,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'min_days': minDays.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$baseUrl/employees/long-absents',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load long absentees');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get employee by ID
  static Future<Map<String, dynamic>?> getEmployeeById(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load employee: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ── Vehicle Admin Endpoints ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminVehicleOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/vehicles/overview'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load vehicle overview');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAdminTrips({
    int? userId,
    int? vehicleId,
    int page = 1,
    int limit = 30,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        if (userId != null) 'userId': userId.toString(),
        if (vehicleId != null) 'vehicleId': vehicleId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      final uri = Uri.parse(
        '$baseUrl/admin/vehicles/trips',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load admin trips');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAdminFuel({
    int? userId,
    int? vehicleId,
    int page = 1,
    int limit = 30,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        if (userId != null) 'userId': userId.toString(),
        if (vehicleId != null) 'vehicleId': vehicleId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      final uri = Uri.parse(
        '$baseUrl/admin/vehicles/fuel',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load admin fuel logs');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ── Leave (EL/CL) APIs ──────────────────────────────────────────────────

  /// Get cumulative EL/CL balance for a user
  static Future<Map<String, dynamic>> getLeaveBalance(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave/balance/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load leave balance');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get blocked days (Sundays + holidays) for a month (YYYY-MM)
  static Future<Map<String, dynamic>> getLeaveCalendar(String month) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/leave/calendar',
      ).replace(queryParameters: {'month': month});
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load leave calendar');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Submit a leave request
  static Future<Map<String, dynamic>> submitLeaveRequest({
    required int userId,
    required String fromDate,
    required String toDate,
    required double elDays,
    required double clDays,
    required double lopDays,
    String? reason,
    int? approverId,
    String session = 'full',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/leave/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'from_date': fromDate,
          'to_date': toDate,
          'el_days': elDays,
          'cl_days': clDays,
          'lop_days': lopDays,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (approverId != null) 'approver_id': approverId,
          'session': session,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201) return data;
      throw Exception(data['error'] ?? 'Failed to submit leave request');
    } catch (e) {
      rethrow;
    }
  }

  /// Get leave requests for the logged-in employee (with pagination and month filter)
  static Future<Map<String, dynamic>> getMyLeaveRequests(
    int userId, {
    String? month,
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final queryParams = {
        'user_id': userId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        if (month != null && month.isNotEmpty) 'month': month,
      };
      final uri = Uri.parse(
        '$baseUrl/leave/requests',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'data': data['data'] as List<dynamic>,
          'total': data['total'] ?? (data['data'] as List<dynamic>).length,
        };
      }
      throw Exception('Failed to load leave requests');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Update a pending leave request
  static Future<Map<String, dynamic>> updateLeaveRequest({
    required int requestId,
    required String fromDate,
    required String toDate,
    required double elDays,
    required double clDays,
    required double lopDays,
    String? reason,
    String session = 'full',
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/leave/requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'from_date': fromDate,
          'to_date': toDate,
          'el_days': elDays,
          'cl_days': clDays,
          'lop_days': lopDays,
          'reason': reason,
          'session': session,
        }),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception(
        json.decode(response.body)['error'] ?? 'Failed to update leave request',
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Delete a pending leave request
  static Future<Map<String, dynamic>> deleteLeaveRequest(int requestId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/leave/requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception(
        json.decode(response.body)['error'] ?? 'Failed to delete leave request',
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get all employees and their assigned approvers
  static Future<List<dynamic>> getHierarchy() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/hierarchy'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      }
      throw Exception('Failed to load hierarchy');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Assign one or more approvers to an employee
  static Future<Map<String, dynamic>> assignApprovers(int employeeId, List<int> approverIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/assign-approvers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_ids': [employeeId],
          'approver_ids': approverIds,
        }),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to assign approvers');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Bulk assign the same group of approvers to multiple employees
  static Future<Map<String, dynamic>> bulkAssignApprovers(List<int> employeeIds, List<int> approverIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/assign-approvers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_ids': employeeIds,
          'approver_ids': approverIds,
        }),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to bulk assign approvers');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get users who can be approvers (admins/managers)
  static Future<List<dynamic>> getPotentialApprovers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/potential-approvers'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      }
      throw Exception('Failed to load potential approvers');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get fixed approvers assigned to an employee
  static Future<List<dynamic>> getUserApprovers(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/approvers'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      }
      throw Exception('Failed to load user approvers');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get leave requests for Admin/Manager view
  static Future<List<dynamic>> getAdminLeaveRequests({
    String? status,
    int? userId,
    int? approverId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        if (status != null) 'status': status,
        if (userId != null) 'user_id': userId.toString(),
        if (approverId != null) 'approver_id': approverId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = Uri.parse(
        '$baseUrl/leave/requests',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      }
      throw Exception('Failed to load admin leave requests');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get permission requests for Admin/Manager view
  static Future<List<dynamic>> getAdminPermissionRequests({
    String? status,
    int? approverId,
  }) async {
    try {
      final queryParams = {
        if (status != null) 'status': status,
        if (approverId != null) 'approver_id': approverId.toString(),
      };
      final uri = Uri.parse(
        '$baseUrl/permissions/admin/all',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      throw Exception('Failed to load admin permission requests');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Approve or reject a leave request
  static Future<Map<String, dynamic>> reviewLeaveRequest({
    required int requestId,
    required String status,
    required int reviewedBy,
    String? adminNote,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/leave/review/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'reviewed_by': reviewedBy,
          if (adminNote != null) 'admin_note': adminNote,
        }),
      );
      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse server response: ${response.body}');
        }
      }
      
      String errorMsg = 'Failed to review leave request';
      try {
        if (response.body.trim().startsWith('{')) {
          final data = json.decode(response.body);
          errorMsg = data['error'] ?? errorMsg;
        } else if (response.body.contains('<!DOCTYPE html>')) {
          errorMsg = 'Server error (HTML). The endpoint might be incorrect or the server crashed.';
        }
      } catch (_) {
        errorMsg = 'Server returned status ${response.statusCode}';
      }
      
      throw Exception(errorMsg);
    } catch (e) {
      if (e is Exception && !e.toString().contains('Network error:')) throw e;
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> reviewPermissionRequest({
    required int requestId,
    required String status,
    required int reviewedBy,
    String? adminNote,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/permissions/review/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'reviewed_by': reviewedBy,
          if (adminNote != null) 'admin_note': adminNote,
        }),
      );
      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse server response: ${response.body}');
        }
      }
      
      String errorMsg = 'Failed to review permission request';
      try {
        if (response.body.trim().startsWith('{')) {
          final data = json.decode(response.body);
          errorMsg = data['error'] ?? errorMsg;
        } else if (response.body.contains('<!DOCTYPE html>')) {
          errorMsg = 'Server error (HTML). The endpoint might be incorrect or the server crashed.';
        }
      } catch (_) {
        errorMsg = 'Server returned status ${response.statusCode}';
      }
      
      throw Exception(errorMsg);
    } catch (e) {
      if (e is Exception && !e.toString().contains('Network error:')) throw e;
      throw Exception('Network error: $e');
    }
  }

  // ── Fetch payroll data for the last 3 months (current + 2 prior) ────────────
  static Future<List<PayrollMonthData>> getPayrollThreeMonths(int userId) async {
    final now = DateTime.now();
    final months = List.generate(3, (i) {
      final dt = DateTime(now.year, now.month - i, 1);
      final ym = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      // Display label e.g. "Aug 2026"
      const monthNames = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final label = '${monthNames[dt.month]} ${dt.year}';
      return (yearMonth: ym, label: label);
    });

    final results = await Future.wait(months.map((m) async {
      try {
        final summary = await getMonthlySummary(userId, yearMonth: m.yearMonth);
        final daily = await getDailyBreakdown(userId, yearMonth: m.yearMonth);
        final days = (daily['days'] as List? ?? [])
            .map((d) => d as Map<String, dynamic>)
            .toList();
        final hasSummaryData = summary['attendance'] != null;
        return PayrollMonthData(
          yearMonth: m.yearMonth,
          displayLabel: m.label,
          summary: summary,
          days: days,
          isEmpty: !hasSummaryData || days.isEmpty,
        );
      } catch (_) {
        return PayrollMonthData(
          yearMonth: m.yearMonth,
          displayLabel: m.label,
          summary: {},
          days: [],
          isEmpty: true,
        );
      }
    }));

    return results;
  }

  // ── Payslip methods (admin-uploaded Excel payslips) ──────────────────────

  /// Returns list of uploaded months for a given username.
  /// GET /payslip/list?username=MEPL001
  static Future<List<Map<String, dynamic>>> getPayslipList(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payslip/list').replace(queryParameters: {'username': username}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final months = data['months'];
        if (months is List) {
          return months.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getPayslipList error: $e');
      return [];
    }
  }

  /// Returns the full payslip record for a given username + month.
  /// GET /payslip/my?username=MEPL001&month_key=2026-05
  static Future<Map<String, dynamic>?> getPayslip(String username, String monthKey) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payslip/my')
            .replace(queryParameters: {'username': username, 'month_key': monthKey}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['payslip'] ?? {});
      }
      return null;
    } catch (e) {
      print('getPayslip error: $e');
      return null;
    }
  }

  /// Returns the user record directly from users table or /employees endpoint
  /// GET /users/by-username?username=MEPL001
  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/by-username')
            .replace(queryParameters: {'username': username}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user'] != null) {
          return Map<String, dynamic>.from(data['user']);
        }
      }
    } catch (e) {
      print('getUserByUsername /users/by-username error: $e');
    }

    // Fallback: Query /employees?search=username
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees').replace(queryParameters: {'search': username}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data is List) ? data : (data['data'] as List? ?? []);
        final uUpper = username.toUpperCase().trim();
        final match = list.firstWhere(
          (x) => x['username']?.toString().toUpperCase() == uUpper ||
                 x['employee_id']?.toString() == username ||
                 x['employee_no']?.toString() == username,
          orElse: () => list.isNotEmpty ? list.first : null,
        );
        if (match != null) {
          return Map<String, dynamic>.from(match);
        }
      }
    } catch (e) {
      print('getUserByUsername /employees fallback error: $e');
    }

    return null;
  }

  /// Fetches current dynamic company seal image URL
  /// GET /company-settings/seal
  static Future<String?> getCompanySeal() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/company-settings/seal'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['seal_url'] != null) {
          return data['seal_url'].toString();
        }
      }
      return null;
    } catch (e) {
      print('getCompanySeal error: $e');
      return null;
    }
  }
}
