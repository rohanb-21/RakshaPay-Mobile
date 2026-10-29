import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
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
  static bool hasPin = false;

  /// Id of the signed-in user, read from the login token (its "sub" field).
  static int? get userId => _idFromToken(token);

  static int? _idFromToken(String? t) {
    if (t == null) return null;
    try {
      final parts = t.split('.');
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return int.tryParse('${(jsonDecode(payload) as Map)['sub']}');
    } catch (_) {
      return null;
    }
  }

  /// Storage key for one account's MPIN data, so every account keeps its own MPIN.
  static String _pk(String name, [int? uid]) => '${name}_${uid ?? userId}';

  static Future<void> init() async {
    token = await _secure.read(key: 'token');
    await _migrateLegacyPin();
    hasPin = userId != null && await _secure.containsKey(key: _pk('pin_hash'));
    final p = await SharedPreferences.getInstance();
    var id = p.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = 'mobile-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      await p.setString('device_id', id);
    }
    deviceId = id;
  }

  /// Older app versions stored one shared MPIN. Move it to the signed-in account.
  static Future<void> _migrateLegacyPin() async {
    final uid = userId;
    if (uid == null) return;
    final hash = await _secure.read(key: 'pin_hash');
    final salt = await _secure.read(key: 'pin_salt');
    if (hash == null || salt == null) return;
    await _secure.write(key: _pk('pin_hash', uid), value: hash);
    await _secure.write(key: _pk('pin_salt', uid), value: salt);
    await _secure.write(key: _pk('pin_fails', uid), value: '0');
    await _secure.delete(key: 'pin_hash');
    await _secure.delete(key: 'pin_salt');
    await _secure.delete(key: 'pin_fails');
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

  static Future<void> verifyOtp(int uid, String otp) async {
    final d = await _post('/api/verify-otp', {'user_id': uid, 'otp': otp});
    token = d['token'] as String;
    await _secure.write(key: 'token', value: token);
    // This account may already have an MPIN saved on this phone.
    hasPin = await _secure.containsKey(key: _pk('pin_hash'));
    if (hasPin) await _secure.write(key: _pk('pin_fails'), value: '0');
  }

  static Future<Map<String, dynamic>> me() => _get('/api/user/me', auth: true);

  static Future<Map<String, dynamic>> transfer(double amount, String recipient) =>
      _post('/api/transfer', {'amount': amount, 'recipient': recipient, 'device_id': deviceId},
          auth: true);

  // ── Sign out ────────────────────────────────────────────────
  /// Normal sign-out keeps the account's MPIN on this phone.
  /// forgetPin: true also deletes that account's MPIN (Forgot MPIN / too many wrong tries).
  static Future<void> logout({bool forgetPin = false}) async {
    final uid = userId; // read before the token is cleared
    if (forgetPin && uid != null) {
      await _secure.delete(key: _pk('pin_hash', uid));
      await _secure.delete(key: _pk('pin_salt', uid));
      await _secure.delete(key: _pk('pin_fails', uid));
    }
    token = null;
    hasPin = false;
    await _secure.delete(key: 'token');
  }

  // ── MPIN (app lock) ─────────────────────────────────────────
  static const pinLength = 4; // change to 6 for a 6-digit MPIN
  static const maxPinAttempts = 5;

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _secure.write(key: _pk('pin_salt'), value: salt);
    await _secure.write(key: _pk('pin_hash'), value: _hashPin(pin, salt));
    await _secure.write(key: _pk('pin_fails'), value: '0');
    hasPin = true;
  }

  /// Returns -1 if the MPIN is correct, otherwise the attempts left.
  /// Returns 0 when too many wrong tries happened: the user is signed out
  /// and this account's MPIN is deleted.
  static Future<int> verifyPin(String pin) async {
    final salt = await _secure.read(key: _pk('pin_salt'));
    final hash = await _secure.read(key: _pk('pin_hash'));
    if (salt == null || hash == null) {
      await logout(forgetPin: true);
      return 0;
    }
    if (_hashPin(pin, salt) == hash) {
      await _secure.write(key: _pk('pin_fails'), value: '0');
      return -1;
    }
    final fails = (int.tryParse(await _secure.read(key: _pk('pin_fails')) ?? '0') ?? 0) + 1;
    if (fails >= maxPinAttempts) {
      await logout(forgetPin: true);
      return 0;
    }
    await _secure.write(key: _pk('pin_fails'), value: '$fails');
    return maxPinAttempts - fails;
  }
}