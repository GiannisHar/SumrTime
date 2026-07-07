import 'package:flutter/foundation.dart' hide Category;
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'package:geolocator/geolocator.dart';

enum AuthState { unknown, authenticated, unauthenticated }

/// null = admin (bar owner), 'cook', 'waiter'
typedef StaffRole = String?;

class BarProvider extends ChangeNotifier {
  Bar?       _bar;
  AuthState  _authState = AuthState.unknown;
  List<Order> _orders   = [];
  bool       _loading   = false;
  String?    _error;

  // Staff session fields — null when logged in as bar owner
  StaffRole  _role       = null;
  String?    _staffName;
  String?    _staffBarId; // NEW — needed so staff can join the socket room

  Bar?        get bar       => _bar;
  AuthState   get authState => _authState;
  List<Order> get orders    => List.unmodifiable(_orders);
  bool        get loading   => _loading;
  String?     get error     => _error;
  StaffRole   get role      => _role;
  String?     get staffName => _staffName;

  bool get isAdmin  => _role == null;
  bool get isCook   => _role == 'cook';
  bool get isWaiter => _role == 'waiter';
  bool get isStaff  => _role != null;

  String? get debugStaffBarId => _staffBarId;

  // ── Boot ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Check staff session first
    final staffToken = await ApiService.getStaffToken();
    if (staffToken != null) {
      _role       = await ApiService.getStaffRole();
      _staffName  = await ApiService.getStaffName();
      _staffBarId = await ApiService.getStaffBarId();
      _authState  = AuthState.authenticated;
      notifyListeners();
      await loadOrders();
      if (_staffBarId != null) {
        _connectSocket(_staffBarId!);
      }
      return;
    }

    // Check bar owner session
    final token = await ApiService.getToken();
    if (token == null) {
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _bar       = await ApiService.getMe();
      _role      = null;
      _authState = AuthState.authenticated;
      await loadMenu();
      _connectSocket(_bar!.id);
    } catch (_) {
      await ApiService.clearToken();
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ── Bar owner auth ─────────────────────────────────────────────────────────
  Future<void> register(String name, String email, String password) async {
    _setLoading(true);
    try {
      final res = await ApiService.register(name, email, password);
      _bar       = Bar.fromJson(res['bar']);
      _role      = null;
      _authState = AuthState.authenticated;
      await loadMenu();
      _connectSocket(_bar!.id);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await ApiService.login(email, password);
      _bar       = Bar.fromJson(res['bar']);
      _role      = null;
      _authState = AuthState.authenticated;
      await loadMenu();
      _connectSocket(_bar!.id);
    } finally {
      _setLoading(false);
    }
  }

  // ── Staff PIN login ────────────────────────────────────────────────────────
  Future<void> staffLogin(String joinCode, String name, String pin) async {
    _setLoading(true);
    try {
      final res   = await ApiService.staffLogin(joinCode, name, pin);
      final staff = res['staff'] as Map<String, dynamic>;
      _role       = staff['role'] as String;
      _staffName  = staff['name'] as String;
      _staffBarId = res['bar_id'] as String?;
      _authState  = AuthState.authenticated;
      await loadOrders();
      if (_staffBarId != null) {
        _connectSocket(_staffBarId!);
      }
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    SocketService().disconnect();
    await ApiService.clearToken();
    await ApiService.clearStaffSession();
    _bar        = null;
    _orders     = [];
    _role       = null;
    _staffName  = null;
    _staffBarId = null;
    _authState  = AuthState.unauthenticated;
    notifyListeners();
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> setLocation(double lat, double lng, int radiusM) async {
    await ApiService.setLocation(lat, lng, radiusM);
    _bar!.location = BarLocation(lat: lat, lng: lng, radiusM: radiusM);
    notifyListeners();
  }



  Future<void> updateLocation(double lat, double lng) async {
  await ApiService.updateMyLocation(lat, lng);
  final existing = _bar!.location;
  _bar!.location = BarLocation(
    lat: lat,
    lng: lng,
    radiusM: existing?.radiusM ?? 0, // unchanged — server never touches this
  );
  notifyListeners();
}

  /// Save the bar's ordering radius WITHOUT changing its pinned coordinates.
  /// Used by the settings slider so dragging it actually persists.
  Future<void> saveRadiusOnly(int radiusM) async {
    final loc = _bar?.location;
    if (loc == null) {
      // No location pinned yet — nothing to attach the radius to.
      throw Exception('Set the bar location first, then adjust the radius.');
    }
    await setLocation(loc.lat, loc.lng, radiusM);
  }

  // ── Theme ──────────────────────────────────────────────────────────────────
  Future<void> updateTheme(Map<String, dynamic> theme) async {
    await ApiService.updateTheme(theme);
    _bar!.theme = BarTheme.fromJson({..._bar!.theme.toJson(), ...theme});
    notifyListeners();
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Future<void> uploadLogo(List<int> bytes, String filename) async {
    final url = await ApiService.uploadLogo(
      imageBytes: bytes,
      filename: filename,
    );
    // Merge the new logo_url into the existing theme without dropping colors.
    if (_bar != null) {
      _bar!.theme = BarTheme.fromJson({
        ..._bar!.theme.toJson(),
        'logo_url': url,
      });
      notifyListeners();
    }
  }

  // ── QR ─────────────────────────────────────────────────────────────────────
  Future<String> generateQr() async {
    final url = await ApiService.generateQr();
    _bar!.qrCodeUrl = url;
    notifyListeners();
    return url;
  }

  // ── Categories ─────────────────────────────────────────────────────────────
  Future<void> addCategory(String name, String type) async {
    final cat = await ApiService.addCategory(name, type);
    _bar!.menu[cat.id] = cat;
    notifyListeners();
  }

  Future<void> deleteCategory(String catId) async {
    await ApiService.deleteCategory(catId);
    _bar!.menu.remove(catId);
    notifyListeners();
  }

  // ── Menu ───────────────────────────────────────────────────────────────────
  Future<void> loadMenu() async {
    final menu = await ApiService.getMenu();
    _bar!.menu = menu.map((k, v) => MapEntry(k, Category.fromJson(v)));
    notifyListeners();
  }

  // ── Products ───────────────────────────────────────────────────────────────
  Future<void> addProduct(String catId, Map<String, dynamic> data) async {
    final prod = await ApiService.addProduct(catId, data);
    _bar!.menu[catId]!.products[prod.id] = prod;
    notifyListeners();
  }

  Future<void> updateProduct(
      String catId, String prodId, Map<String, dynamic> data) async {
    final prod = await ApiService.updateProduct(catId, prodId, data);
    _bar!.menu[catId]!.products[prodId] = prod;
    notifyListeners();
  }

  Future<void> deleteProduct(String catId, String prodId) async {
    await ApiService.deleteProduct(catId, prodId);
    _bar!.menu[catId]!.products.remove(prodId);
    notifyListeners();
  }

  // ── Stock ──────────────────────────────────────────────────────────────────
  Future<void> toggleStock(String catId, String prodId, bool inStock) async {
    await ApiService.setStock(prodId, inStock);
    _bar!.menu[catId]!.products[prodId]!.inStock = inStock;
    notifyListeners();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  Future<void> loadOrders() async {
    _orders = await ApiService.getOrders();
    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await ApiService.updateOrderStatus(orderId, status);
    // After cook marks ready → disappears from cook's list
    // After waiter marks delivered → disappears from waiter's list
    // In both cases just reload from server so the filter is applied correctly
    await loadOrders();
  }

  // ── Socket wiring (bar owner + staff) ────────────────────────────────────
  void _connectSocket(String barId) {
    final svc = SocketService();
    svc.connect(barId);

    // A newly paid order landed — reload so it shows up for admin, cook,
    // and waiter alike (their respective `getOrders()` calls filter server-side).
    svc.onOrderPaid((_) => loadOrders());

    svc.onNewOrder((_) => loadOrders());

    svc.onOrderStatus((orderId, status) {
      if (status == 'delivered') {
        _orders.removeWhere((o) => o.id == orderId);
        notifyListeners();
      } else {
        loadOrders();
      }
    });

    // Menu/stock listeners touch `_bar`, which only bar-owner sessions load.
    // Guard so staff sessions don't hit a null-check exception.
    if (isAdmin && _bar != null) {
      svc.onStockUpdate((productId, inStock) {
        for (final cat in _bar!.menu.values) {
          if (cat.products.containsKey(productId)) {
            cat.products[productId]!.inStock = inStock;
            notifyListeners();
            break;
          }
        }
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}