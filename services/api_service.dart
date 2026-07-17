import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // for rootNavigatorKey — adjust path if needed

class ApiService {
  //static const String baseUrl = "http://192.168.1.3:8080";
  static const String baseUrl = "https://sumrtimeserv.onrender.com";

  static const _storage    = FlutterSecureStorage();
  static const _tokenKey   = 'bar_jwt';
  static const _staffTokenKey = 'staff_jwt';
  static const _staffRoleKey  = 'staff_role';
  static const _staffNameKey  = 'staff_name';
  static const _staffIdKey    = 'staff_id';
  static const _staffBarIdKey = 'staff_bar_id';

  static bool _loggingOut = false;

  // ── Session expiry ─────────────────────────────────────────────────────────
  /// Public so the socket layer can also trigger it on an Unauthorized event.
static Future<void> handleSessionExpired() async {
    if (_loggingOut) return;
    _loggingOut = true;
    await clearToken();
    await clearStaffSession();
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      // Pop any pushed screens back down to _Root...
      nav.popUntil((route) => route.isFirst);
      ScaffoldMessenger.maybeOf(nav.context)?.showSnackBar(
        const SnackBar(content: Text('Session expired — please log in again')),
      );
    }
    // ...and flip authState so _Root swaps Dashboard → AuthScreen.
    onSessionExpired?.call();
    _loggingOut = false;
  }

  /// Wired up by BarProvider so an expired session flips authState.
  static void Function()? onSessionExpired;

  // ── Bar token management ───────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // ── Staff token management ─────────────────────────────────────────────────
  static Future<void> saveStaffSession(
      Map<String, dynamic> staff, String token, String barId) async {
    await _storage.write(key: _staffTokenKey, value: token);
    await _storage.write(key: _staffRoleKey,  value: staff['role'] as String);
    await _storage.write(key: _staffNameKey,  value: staff['name'] as String);
    await _storage.write(key: _staffIdKey,    value: staff['id']   as String);
    await _storage.write(key: _staffBarIdKey, value: barId);
  }

  static Future<String?> getStaffToken() => _storage.read(key: _staffTokenKey);
  static Future<String?> getStaffRole()  => _storage.read(key: _staffRoleKey);
  static Future<String?> getStaffName()  => _storage.read(key: _staffNameKey);
  static Future<String?> getStaffBarId() => _storage.read(key: _staffBarIdKey);

  static Future<void> clearStaffSession() async {
    await _storage.delete(key: _staffTokenKey);
    await _storage.delete(key: _staffRoleKey);
    await _storage.delete(key: _staffNameKey);
    await _storage.delete(key: _staffIdKey);
    await _storage.delete(key: _staffBarIdKey);
  }

  /// Returns true if a staff session is active (not a bar-owner session).
  static Future<bool> isStaffSession() async {
    final staffToken = await getStaffToken();
    return staffToken != null;
  }

  // ── Auth headers — uses staff token if active, bar token otherwise ─────────
  static Future<Map<String, String>> _authHeaders() async {
    final staffToken = await getStaffToken();
    final barToken   = await getToken();
    final token = staffToken ?? barToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Generic request helper ─────────────────────────────────────────────────
  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri     = Uri.parse('$baseUrl$path');
    final headers = auth
        ? await _authHeaders()
        : <String, String>{'Content-Type': 'application/json'};

    http.Response response;
    final encoded = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unknown method $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body);
    } else {
      // JWT expired/invalid → force logout. Skip login/register endpoints,
      // where 401 just means wrong credentials.
      if (response.statusCode == 401 &&
          !path.contains('/login') &&
          !path.contains('/register')) {
        await handleSessionExpired();
        throw ApiException(401, 'Session expired');
      }
      try {
        final err = jsonDecode(response.body);
        throw ApiException(
          response.statusCode,
          err['message'] ?? err['reason'] ?? err['text'] ?? 'Unknown error',
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(response.statusCode, response.body);
      }
    }
  }

  // ── Bar auth ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await _request('POST', '/api/bars/register',
        body: {'name': name, 'email': email, 'password': password},
        auth: false) as Map<String, dynamic>;
    await saveToken(res['token']);
    return res;
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await _request('POST', '/api/bars/login',
        body: {'email': email, 'password': password},
        auth: false) as Map<String, dynamic>;
    await saveToken(res['token']);
    return res;
  }

  static Future<Bar> getMe() async {
    final res = await _request('GET', '/api/bars/me') as Map<String, dynamic>;
    return Bar.fromJson(res);
  }

  // ── Staff auth ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> staffLogin(
      String joinCode, String name, String pin) async {
    final res = await _request('POST', '/api/staff/login',
        body: {'join_code': joinCode, 'name': name, 'pin': pin},
        auth: false) as Map<String, dynamic>;
    await saveStaffSession(
      res['staff'] as Map<String, dynamic>,
      res['token'] as String,
      res['bar_id'] as String,
    );
    return res;
  }

  // ── Staff management (admin only) ──────────────────────────────────────────
  static Future<List<dynamic>> getStaff() async {
    final res = await _request('GET', '/api/bars/me/staff') as List;
    return res;
  }

  static Future<Map<String, dynamic>> addStaff(
      String name, String pin, String role) async {
    final res = await _request('POST', '/api/bars/me/staff',
        body: {'name': name, 'pin': pin, 'role': role}) as Map<String, dynamic>;
    return res;
  }

  static Future<void> deleteStaff(String staffId) =>
      _request('DELETE', '/api/bars/me/staff/$staffId');

  // ── Bar settings ───────────────────────────────────────────────────────────
  static Future<void> updateTheme(Map<String, dynamic> theme) =>
      _request('PUT', '/api/bars/me/theme', body: theme);

  static Future<void> setLocation(double lat, double lng, int radiusM) =>
      _request('PUT', '/api/bars/me/location',
          body: {'lat': lat, 'lng': lng, 'radius_m': radiusM});

  static Future<String> generateQr() async {
    final res =
        await _request('POST', '/api/bars/me/qr') as Map<String, dynamic>;
    return res['qr_code_url'] as String;
  }

  // ── Menu — categories ──────────────────────────────────────────────────────
  static Future<Category> addCategory(String name, String type) async {
    final res = await _request('POST', '/api/bars/me/menu/categories',
        body: {'name': name, 'type': type}) as Map<String, dynamic>;
    return Category.fromJson(res);
  }

  static Future<void> updateCategory(String catId, String name, String type) =>
      _request('PUT', '/api/bars/me/menu/categories/$catId',
          body: {'name': name, 'type': type});

  static Future<void> deleteCategory(String catId) =>
      _request('DELETE', '/api/bars/me/menu/categories/$catId');

  // ── Menu — products ────────────────────────────────────────────────────────
  static Future<Product> addProduct(
      String catId, Map<String, dynamic> productData) async {
    final res = await _request(
        'POST', '/api/bars/me/menu/categories/$catId/products',
        body: productData) as Map<String, dynamic>;
    return Product.fromJson(res);
  }

  static Future<Product> updateProduct(String catId, String prodId,
      Map<String, dynamic> productData) async {
    final res = await _request(
        'PUT', '/api/bars/me/menu/categories/$catId/products/$prodId',
        body: productData) as Map<String, dynamic>;
    return Product.fromJson(res);
  }

  static Future<void> deleteProduct(String catId, String prodId) =>
      _request('DELETE', '/api/bars/me/menu/categories/$catId/products/$prodId');

  // ── Stock ──────────────────────────────────────────────────────────────────
  static Future<void> setStock(String prodId, bool inStock) =>
      _request('PUT', '/api/bars/me/products/$prodId/stock',
          body: {'in_stock': inStock});

  // ── Orders ─────────────────────────────────────────────────────────────────
  static Future<List<Order>> getOrders() async {
    final res = await _request('GET', '/api/bars/me/orders') as List;
    return res.map((o) => Order.fromJson(o)).toList();
  }

  static Future<void> updateOrderStatus(String orderId, String status) =>
      _request('PUT', '/api/bars/me/orders/$orderId/status',
          body: {'status': status});

        
  /// Marks a cash order as collected (cash_due → paid).
/// Backend emits order_paid + issues the receipt.
static Future<Order> collectCash(String orderId) async {
  final res = await _request(
      'PUT', '/api/bars/me/orders/$orderId/collect-cash')
      as Map<String, dynamic>;
  return Order.fromJson(res);
}

  // ── QR Codes ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getQrCodes() async {
    final res =
        await _request('GET', '/api/bars/me/qr') as Map<String, dynamic>;
    return res;
  }

  static Future<Map<String, dynamic>> createQrRange(int from, int to) async {
    final res = await _request('POST', '/api/bars/me/qr/range',
        body: {'from': from, 'to': to}) as Map<String, dynamic>;
    return res;
  }

  static Future<void> deleteQrCode(int number) =>
      _request('DELETE', '/api/bars/me/qr/$number');

  static Future<void> deleteAllQrCodes() =>
      _request('DELETE', '/api/bars/me/qr');

  static Future<Map<String, dynamic>> getMenu() async {
    final res =
        await _request('GET', '/api/bars/me/menu') as Map<String, dynamic>;
    return res;
  }

  // ── Stripe ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStripeStatus() async {
    final res = await _request('GET', '/api/bars/me/stripe/status')
        as Map<String, dynamic>;
    return res;
  }

  static Future<Map<String, dynamic>> createStripeConnectLink() async {
    final res = await _request('POST', '/api/bars/me/stripe/connect')
        as Map<String, dynamic>;
    return res;
  }

  // ── Image upload ───────────────────────────────────────────────────────────
  static Future<String> uploadProductImage({
    required String productId,
    required List<int> imageBytes,
    required String filename,
  }) async {
    final token  = await getStaffToken() ?? await getToken();
    final uri    = Uri.parse('$baseUrl/api/bars/me/products/$productId/image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('image', imageBytes,
          filename: filename));
    final response = await request.send();
    final body    = jsonDecode(await response.stream.bytesToString());
    if (response.statusCode == 401) {
      await handleSessionExpired();
      throw ApiException(401, 'Session expired');
    }
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, body['reason'] ?? 'Upload failed');
    }
    return body['url'] as String;
  }

  static Future<String> uploadLogo({
    required List<int> imageBytes,
    required String filename,
  }) async {
    final token   = await getStaffToken() ?? await getToken();
    final uri     = Uri.parse('$baseUrl/api/bars/me/logo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('image', imageBytes,
          filename: filename));
    final response = await request.send();
    final body     = jsonDecode(await response.stream.bytesToString());
    if (response.statusCode == 401) {
      await handleSessionExpired();
      throw ApiException(401, 'Session expired');
    }
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, body['reason'] ?? 'Upload failed');
    }
    return body['url'] as String;
  }

  // Now goes through _request so it gets 401 handling for free.
  static Future<void> updateMyLocation(double lat, double lng) =>
      _request('PUT', '/api/bars/me/location', body: {'lat': lat, 'lng': lng});

  // ── Umbrella radius ────────────────────────────────────────────────────────

  /// Change ONE umbrella's ordering radius without re-pinning its coordinates.
  static Future<Map<String, dynamic>> setUmbrellaRadius(
      int number, int radiusM) async {
    final res = await _request('PUT', '/api/bars/me/qr/$number/radius',
        body: {'radius_m': radiusM}) as Map<String, dynamic>;
    return res;
  }

  /// The bar's default umbrella radius (inherited by newly-created umbrellas).
  static Future<int> getDefaultUmbrellaRadius() async {
    final res = await _request('GET', '/api/bars/me/qr/default-radius')
        as Map<String, dynamic>;
    return (res['default_umbrella_radius_m'] as num).toInt();
  }

  /// Set the bar's default umbrella radius. If [applyToAll] is true, also
  /// overwrites every existing umbrella's radius with this value.
  static Future<Map<String, dynamic>> setDefaultUmbrellaRadius(
      int radiusM, {bool applyToAll = false}) async {
    final res = await _request('PUT', '/api/bars/me/qr/default-radius',
        body: {'radius_m': radiusM, 'apply_to_all': applyToAll})
        as Map<String, dynamic>;
    return res;
  }

  static Future<List<Map<String, dynamic>>> getUmbrellaPositions() async {
    final res = await _request('GET', '/api/bars/me/qr/positions')
        as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(res['positions'] as List);
  }



  static Future<void> setAcceptsCash(bool accepts) =>
    _request('PUT', '/api/bars/me/cash', body: {'accepts_cash': accepts});

static Future<void> setReceiptProvider(String? provider, String? vat,
        Map<String, String>? credentials) =>
    _request('PUT', '/api/bars/me/receipts', body: {
      'provider': provider,
      'vat_number': vat,
      'credentials': credentials,
    });
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}