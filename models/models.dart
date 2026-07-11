// ── Ingredient amount option ──────────────────────────────────────────────────
class AmountOption {
  final String label;
  final num? value; // null = word-only (e.g. "sweet"), num = literal

  AmountOption({required this.label, this.value});

  factory AmountOption.fromJson(Map<String, dynamic> j) =>
      AmountOption(label: j['label'], value: j['value']);

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

// ── Ingredient ────────────────────────────────────────────────────────────────
class Ingredient {
  final String id;
  final String name;
  final List<AmountOption> amounts;
  final int? defaultAmountIndex;
  final bool removable;

  Ingredient({
    required this.id,
    required this.name,
    this.amounts = const [],
    this.defaultAmountIndex,
    this.removable = true,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'],
        name: j['name'],
        amounts: (j['amounts'] as List? ?? [])
            .map((a) => AmountOption.fromJson(a))
            .toList(),
        defaultAmountIndex: j['default_amount_index'],
        removable: j['removable'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amounts': amounts.map((a) => a.toJson()).toList(),
        'default_amount_index': defaultAmountIndex,
        'removable': removable,
      };
}

// ── Product ───────────────────────────────────────────────────────────────────
class Product {
  final String id;
  String name;
  String description;
  double price;
  int preparationTimeMin;
  String? imageUrl;
  List<Ingredient> ingredients;
  List<String> tags;
  bool inStock;
  final String createdAt;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.preparationTimeMin = 5,
    this.imageUrl,
    this.ingredients = const [],
    this.tags = const [],
    this.inStock = true,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        price: (j['price'] as num).toDouble(),
        preparationTimeMin: j['preparation_time_min'] ?? 5,
        imageUrl: j['image_url'],
        ingredients: (j['ingredients'] as List? ?? [])
            .map((i) => Ingredient.fromJson(i))
            .toList(),
        tags: List<String>.from(j['tags'] ?? []),
        inStock: j['in_stock'] ?? true,
        createdAt: j['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'preparation_time_min': preparationTimeMin,
        'image_url': imageUrl,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'tags': tags,
      };
}

// ── Category ──────────────────────────────────────────────────────────────────
class Category {
  final String id;
  String name;
  String type; // food | drink | other
  Map<String, Product> products;
  final String createdAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.products = const {},
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        type: j['type'] ?? 'other',
        products: (j['products'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, Product.fromJson(v)),
        ),
        createdAt: j['created_at'] ?? '',
      );
}

// ── Theme ─────────────────────────────────────────────────────────────────────
class BarTheme {
  String primaryColor;
  String secondaryColor;
  String backgroundColor;
  String? logoUrl;
  String? backgroundImageUrl;
  String font;

  BarTheme({
    this.primaryColor = '#0077B6',
    this.secondaryColor = '#00B4D8',
    this.backgroundColor = '#FFFFFF',
    this.logoUrl,
    this.backgroundImageUrl,
    this.font = 'Poppins',
  });

  factory BarTheme.fromJson(Map<String, dynamic> j) => BarTheme(
        primaryColor: j['primary_color'] ?? '#0077B6',
        secondaryColor: j['secondary_color'] ?? '#00B4D8',
        backgroundColor: j['background_color'] ?? '#FFFFFF',
        logoUrl: j['logo_url'],
        backgroundImageUrl: j['background_image_url'],
        font: j['font'] ?? 'Poppins',
      );

  Map<String, dynamic> toJson() => {
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'background_color': backgroundColor,
        'logo_url': logoUrl,
        'background_image_url': backgroundImageUrl,
        'font': font,
      };
}

// ── Location ──────────────────────────────────────────────────────────────────
class BarLocation {
  final double lat;
  final double lng;
  final int radiusM;

  BarLocation({required this.lat, required this.lng, this.radiusM = 500});

  factory BarLocation.fromJson(Map<String, dynamic> j) => BarLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        radiusM: j['radius_m'] ?? 500,
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'radius_m': radiusM};
}

// ── Bar ───────────────────────────────────────────────────────────────────────
// ── In models.dart, find the Bar class and make these two changes ─────────────

// 1. Add joinCode field to Bar class:
class Bar {
  final String id;
  final String name;
  final String ownerEmail;
  final String? joinCode;
  BarTheme theme;
  BarLocation? location;
  Map<String, Category> menu;
  String? qrCodeUrl;
  final String createdAt;
  bool acceptsCash;          // ← NEW
  String? receiptProvider;   // ← NEW
  String? vatNumber;         // ← NEW

  Bar({
    required this.id,
    required this.name,
    required this.ownerEmail,
    this.joinCode,
    required this.theme,
    this.location,
    this.menu = const {},
    this.qrCodeUrl,
    required this.createdAt,
    this.acceptsCash = false,   // ← NEW
    this.receiptProvider,       // ← NEW
    this.vatNumber,             // ← NEW
  });

  factory Bar.fromJson(Map<String, dynamic> j) => Bar(
        id: j['id'],
        name: j['name'],
        ownerEmail: j['owner_email'] ?? '',
        joinCode: j['join_code'] as String?,
        theme: BarTheme.fromJson(j['theme'] ?? {}),
        location: j['location'] != null ? BarLocation.fromJson(j['location']) : null,
        menu: (j['menu'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, Category.fromJson(v)),
        ),
        qrCodeUrl: j['qr_code_url'],
        createdAt: j['created_at'] ?? '',
        acceptsCash: j['accepts_cash'] as bool? ?? false,     // ← NEW
        receiptProvider: j['receipt_provider'] as String?,     // ← NEW
        vatNumber: j['vat_number'] as String?,                 // ← NEW
      );
}

// ── Order ─────────────────────────────────────────────────────────────────────
class OrderItem {
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<Map<String, dynamic>> customizations;
  final String notes;

  OrderItem.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'] as String?,
        productName = j['product_name'] as String? ?? '',
        quantity = (j['quantity'] as num).toInt(),
        unitPrice = (j['price'] as num).toDouble(),
        lineTotal = (j['price'] as num).toDouble() * (j['quantity'] as num).toInt(),
        customizations = (j['customizations'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        notes = j['notes'] as String? ?? '';
}
class Order {
  final String id;
  final String barId;
  final List<OrderItem> items;
  final double total;
  String status;
  final String paymentStatus;
  final String createdAt;
  final int? umbrellaNumber;
  final String paymentMethod; // 'card' | 'cash'
  final String? receiptMark;   // ← NEW: myDATA ΜΑΡΚ (null until issued)
  final String? receiptQrUrl;  // ← NEW: verification QR url

  Order.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        barId = j['bar_id'],
        items = (j['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
        total = (j['total'] as num).toDouble(),
        status = j['status'],
        paymentStatus = j['payment_status'],
        createdAt = j['created_at'],
        umbrellaNumber = (j['umbrella_number'] as num?)?.toInt(),
        paymentMethod = j['payment_method'] as String? ?? 'card',
        receiptMark = j['receipt_mark'] as String?,
        receiptQrUrl = j['receipt_qr_url'] as String?;
}
