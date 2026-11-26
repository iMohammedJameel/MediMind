import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../components/constants.dart';
import '../local/cache_helper.dart';

/// Single Dio instance for the whole app.
///
/// - Attaches the JWT automatically.
/// - Persists the backend's HttpOnly `refreshToken` cookie (login sets it,
///   7-day max age) so sessions survive restarts.
/// - On 401: tries `POST /auth/token/refresh` ONCE (cookie-authenticated),
///   stores the new access token, retries the original request. Only a
///   failed refresh clears the session.
class DioHelper {
  static late Dio _dio;
  static PersistCookieJar? _cookieJar;
  static Future<bool>? _refreshing;

  /// Set by main() — invoked when a 401 + failed refresh clears the session,
  /// so the user is taken to the login screen instead of being stranded on
  /// an authenticated screen that shows raw errors (the router has no way
  /// to notice the session change by itself). Kept as a callback to avoid
  /// an import cycle between this layer and the router/UI.
  static void Function()? onSessionExpired;

  static Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 60), // OCR scans are slow
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Persist cookies (refresh token) in the app-private dir. Skipped in
    // tests / unsupported environments.
    try {
      final dir = await getApplicationSupportDirectory();
      _cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
      _dio.interceptors.add(CookieManager(_cookieJar!));
    } catch (_) {
      _cookieJar = null;
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = CacheHelper.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        final isRefreshCall =
            e.requestOptions.path.contains(AppConstants.refreshPath);

        if (status == 401 && !isRefreshCall && CacheHelper.getToken() != null) {
          try {
            final refreshed = await _refreshSession();
            if (refreshed) {
              // Retry the original request with the new token.
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer ${CacheHelper.getToken()}';
              final res = await _dio.fetch(opts);
              return handler.resolve(res);
            }
          } catch (_) {
            // fall through to session clear
          }
          await CacheHelper.clearSession();
          // Route the user out of the now-dead session (no-op until main()
          // wires the callback — e.g. in unit tests).
          onSessionExpired?.call();
        }
        handler.next(e);
      },
    ));
  }

  static Dio get dio => _dio;

  /// One refresh at a time - concurrent 401s share the same attempt.
  static Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    try {
      final res = await _dio.post(AppConstants.refreshPath);
      final data = res.data is Map ? res.data : null;
      final payload = data?['data'];
      final token = payload is Map
          ? (payload['accessToken'] ?? payload['access_token'])
          : null;
      if (token is String && token.isNotEmpty) {
        await CacheHelper.setToken(token);
        return true;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  /// Pulls a readable message out of the backend error envelope — in the
  /// ACTIVE app language (the old code always preferred the Arabic field,
  /// so English users got Arabic error messages).
  static Never _throwReadable(DioException e) {
    if (kDebugMode) {
      debugPrint('DioError ${e.requestOptions.uri}: '
          '${e.response?.statusCode} ${e.response?.data} (${e.message})');
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;
    final envelopeCode = data is Map ? data['code']?.toString() : null;
    if (data is Map) {
      final messages = data['messages'];
      if (messages is Map) {
        final locale = _safeLocale();
        final msg = locale == 'en'
            ? (messages['en'] ?? messages['ar'])
            : (messages['ar'] ?? messages['en']);
        if (msg is String && msg.isNotEmpty) {
          throw ApiFailure(msg, statusCode: status, code: envelopeCode);
        }
      }
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        throw ApiFailure(error['message'] as String,
            statusCode: status, code: envelopeCode);
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      throw const ApiFailure('err.network');
    }
    throw const ApiFailure('err.unexpected');
  }

  static String _safeLocale() {
    try {
      return CacheHelper.getLocale();
    } catch (_) {
      return 'ar'; // preferences not ready (tests) — Arabic-first product.
    }
  }


  /// GET returning the inner `data` payload (or null).
  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data is Map ? res.data['data'] ?? res.data : res.data;
    } on DioException catch (e) {
      _throwReadable(e);
    }
  }

  /// POST returning the inner `data` payload (or null).
  static Future<dynamic> post(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data is Map ? res.data['data'] ?? res.data : res.data;
    } on DioException catch (e) {
      _throwReadable(e);
    }
  }

  /// PATCH returning the inner `data` payload (or null).
  static Future<dynamic> patch(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      return res.data is Map ? res.data['data'] ?? res.data : res.data;
    } on DioException catch (e) {
      _throwReadable(e);
    }
  }

  /// PUT returning the inner `data` payload (or null).
  static Future<dynamic> put(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.put(path, data: data);
      return res.data is Map ? res.data['data'] ?? res.data : res.data;
    } on DioException catch (e) {
      _throwReadable(e);
    }
  }

  /// DELETE returning the inner `data` payload (or null). Supports an
  /// optional JSON body (e.g. password re-auth for account deletion).
  static Future<dynamic> delete(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await _dio.delete(path, data: data);
      return res.data is Map ? res.data['data'] ?? res.data : res.data;
    } on DioException catch (e) {
      _throwReadable(e);
    }
  }

  /// Wipes persisted cookies (used on logout).
  static Future<void> clearCookies() async {
    await _cookieJar?.deleteAll();
  }
}
