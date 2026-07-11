import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

typedef StockUpdateCallback = void Function(String productId, bool inStock);
typedef NewOrderCallback = void Function(Map<String, dynamic> order);
typedef OrderStatusCallback = void Function(String orderId, String status);
typedef UmbrellaStatusCallback = void Function(String umbrellaId, bool busy);
typedef OrderPaidCallback = void Function(Map<String, dynamic> order);
typedef ConnectedCallback = void Function();

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _connected = false;

  // Registered listeners
  final List<StockUpdateCallback> _stockListeners = [];
  final List<NewOrderCallback> _orderListeners = [];
  final List<OrderStatusCallback> _statusListeners = [];
  final List<UmbrellaStatusCallback> _umbrellaListeners = [];
  final List<OrderPaidCallback> _orderPaidListeners = [];
  final List<ConnectedCallback> _connectedListeners = [];

  bool get isConnected => _connected;

  Future<void> connect(String barId) async {
    if (_connected) return;

    final token =
        await ApiService.getStaffToken() ?? await ApiService.getToken();

    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          // No setReconnectionAttempts — default is infinite retries with
          // backoff. A fixed cap (e.g. 10) means one bad Wi-Fi patch and the
          // socket silently dies for the rest of the session.
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth({'token': token ?? ''}) // JWT in the handshake
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _connected = true;
      // Fires on initial connect AND every reconnect. Rooms are
      // per-connection server-side, so always re-join here.
      _socket!.emit('join_bar_room', {'bar_id': barId});
      print('[socket] connected — joined bar:$barId');

      // Let the provider resync (refetch orders/menu) so nothing
      // missed while disconnected is lost.
      for (final cb in _connectedListeners) {
        cb();
      }
    });

    _socket!.on('error', (data) {
      print('[socket] server error: $data');
      // Server denies join_bar_room when the handshake JWT is expired or
      // invalid — happens on reconnect after the token dies. Kick to login.
      if (data is Map && data['reason'] == 'Unauthorized') {
        ApiService.handleSessionExpired();
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      print('[socket] disconnected');
    });

    _socket!.onConnectError((err) => print('[socket] connect error: $err'));

    // ── Incoming events ──────────────────────────────────────────────────────
    _socket!.on('order_paid', (data) {
      final order = Map<String, dynamic>.from(data);
      for (final cb in _orderPaidListeners) {
        cb(order);
      }
    });

    _socket!.on('stock_update', (data) {
      final productId = data['product_id'] as String;
      final inStock = data['in_stock'] as bool;
      for (final cb in _stockListeners) {
        cb(productId, inStock);
      }
    });

    _socket!.on('new_order', (data) {
      final order = Map<String, dynamic>.from(data['order']);
      for (final cb in _orderListeners) {
        cb(order);
      }
    });

    _socket!.on('order_status', (data) {
      final orderId = data['order_id'] as String;
      final status = data['status'] as String;
      for (final cb in _statusListeners) {
        cb(orderId, status);
      }
    });

    _socket!.on('umbrella_status', (data) {
      final umbrellaId = data['umbrella_id'] as String;
      final busy = data['busy'] as bool;
      for (final cb in _umbrellaListeners) {
        cb(umbrellaId, busy);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose(); // kill reconnection timers so a logged-out socket
    _socket = null;     // doesn't keep retrying in the background
    _connected = false;
    _stockListeners.clear();
    _orderListeners.clear();
    _statusListeners.clear();
    _umbrellaListeners.clear();
    _orderPaidListeners.clear();
    _connectedListeners.clear();
  }

  // ── Listener registration ──────────────────────────────────────────────────
  void onConnected(ConnectedCallback cb) => _connectedListeners.add(cb);
  void onStockUpdate(StockUpdateCallback cb) => _stockListeners.add(cb);
  void onNewOrder(NewOrderCallback cb) => _orderListeners.add(cb);
  void onOrderStatus(OrderStatusCallback cb) => _statusListeners.add(cb);
  void onUmbrellaStatus(UmbrellaStatusCallback cb) =>
      _umbrellaListeners.add(cb);
  void onOrderPaid(OrderPaidCallback cb) => _orderPaidListeners.add(cb);

  void removeConnectedListener(ConnectedCallback cb) =>
      _connectedListeners.remove(cb);
  void removeStockListener(StockUpdateCallback cb) =>
      _stockListeners.remove(cb);
  void removeOrderListener(NewOrderCallback cb) => _orderListeners.remove(cb);
  void removeStatusListener(OrderStatusCallback cb) =>
      _statusListeners.remove(cb);
  void removeUmbrellaListener(UmbrellaStatusCallback cb) =>
      _umbrellaListeners.remove(cb);
}