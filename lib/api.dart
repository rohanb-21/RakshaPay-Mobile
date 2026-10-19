import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Talks to the same FastAPI backend (on Render) that the website uses.
/// The backend stores everything in Supabase, so web + mobile share data.
class Api {
  // Override at build time: flutter run --dart-define=API_BASE=http://10.0.2.2:8000
  static const baseUrl = String.fromEnvironment('API_BASE',
      defaultValue: 'https://rakshapay-sim-swap-detection.onrender.com');

  static const _secure = FlutterSecureStorage();
  static String? token;
  static late String deviceId;

  static Future<void> init() async {
    token = await _secure.read(key: 'token');
    hasPin = await _secure.containsKey(key: 'pin_hash');
    final p = await SharedPreferences.getInstance();
    var id = p.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = 'mobile-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      await p.setString('device_id', id);
    }
    deviceId = id;
  }

  static Map<String, String> _headers({bool auth = false}) => {
        'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body;

    var msg = 'Request failed (${r.statusCode})';
    if (r.statusCode == 429) {
      msg = 'Too many requests. Please wait a minute.';
    } else if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      msg = d is List
          ? d.map((e) => e is Map ? (e['msg'] ?? '').toString() : e.toString()).join(', ')
          : d.toString();
    }
    throw ApiException(msg, r.statusCode);
  }

  // Render free tier can take up to a minute to wake up.
  static const _timeout = Duration(seconds: 75);

  /// Runs a request and turns any network problem into a readable message.
  static Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      final r = await call().timeout(_timeout);
      return _handle(r);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
          'Server is taking too long. Free hosting may be waking up - wait 30 seconds and try again.');
    } catch (e) {
      throw ApiException('Cannot reach server: $e');
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map body, {bool auth = false}) async {
    final d = await _send(() => http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(auth: auth), body: jsonEncode(body)));
    if (d is! Map) throw ApiException('Unexpected response from server.');
    return Map<String, dynamic>.from(d);
  }

  static Future<dynamic> _getJson(String path, {bool auth = false}) =>
      _send(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth)));

  static Future<Map<String, dynamic>> _get(String path, {bool auth = false}) async {
    final d = await _getJson(path, auth: auth);
    if (d is! Map) throw ApiException('Unexpected response from server.');
    return Map<String, dynamic>.from(d);
  }

  // ── User endpoints ─────────────────────────────────────────
  static Future<void> register(String name, String phone, String email, String password) =>
      _post('/api/register', {'name': name, 'phone': phone, 'email': email, 'password': password});

  static Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/api/login', {'email': email, 'password': password, 'device_id': deviceId});

  static Future<void> verifyOtp(int userId, String otp) async {
    final d = await _post('/api/verify-otp', {'user_id': userId, 'otp': otp});
    token = d['token'] as String;
    await _secure.write(key: 'token', value: token);
  }

  static Future<Map<String, dynamic>> me() => _get('/api/user/me', auth: true);

  static Future<Map<String, dynamic>> transfer(double amount, String recipient) =>
      _post('/api/transfer', {'amount': amount, 'recipient': recipient, 'device_id': deviceId},
          auth: true);

    static Future<void> logout() async {
    token = null;
    hasPin = false;
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'pin_hash');
    await _secure.delete(key: 'pin_salt');
    await _secure.delete(key: 'pin_fails');
  }

  // ── MPIN (app lock) ─────────────────────────────────────────
  static const pinLength = 4; // change to 6 for a 6-digit MPIN
  static const maxPinAttempts = 5;
  static bool hasPin = false;

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _secure.write(key: 'pin_salt', value: salt);
    await _secure.write(key: 'pin_hash', value: _hashPin(pin, salt));
    await _secure.write(key: 'pin_fails', value: '0');
    hasPin = true;
  }

  /// Returns -1 if the MPIN is correct, otherwise the attempts left.
  /// Returns 0 when too many wrong tries happened: the login is wiped.
  static Future<int> verifyPin(String pin) async {
    final salt = await _secure.read(key: 'pin_salt');
    final hash = await _secure.read(key: 'pin_hash');
    if (salt == null || hash == null) {
      await logout();
      return 0;
    }
    if (_hashPin(pin, salt) == hash) {
      await _secure.write(key: 'pin_fails', value: '0');
      return -1;
    }
    final fails = (int.tryParse(await _secure.read(key: 'pin_fails') ?? '0') ?? 0) + 1;
    if (fails >= maxPinAttempts) {
      await logout();
      return 0;
    }
    await _secure.write(key: 'pin_fails', value: '$fails');
    return maxPinAttempts - fails;
  }

  // ── Admin endpoints (same ones the website's admin panel uses) ──
  static Future<Map<String, dynamic>> adminStats() => _get('/api/admin/stats');

  static Future<List<Map<String, dynamic>>> adminList(String path) async {
    final d = await _getJson(path);
    if (d is! List) throw ApiException('Unexpected response from server.');
    return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> setSwap(int userId, bool swapped) => _post(
      swapped ? '/api/admin/simulate-swap' : '/api/admin/reset-swap', {'user_id': userId});
}
