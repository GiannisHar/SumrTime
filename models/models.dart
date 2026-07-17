// ── Ingredient amount option ──────────────────────────────────────────────────
class AmountOption {
  final String label;
  final String? value; // null = word-only (e.g. "sweet"), num = literal

  /// Signed euro adjustment applied to the product's base price when this
  /// amount is selected (e.g. Large = +1.50, Small = -0.50). 0 = no change.
  /// The server re-reads this stored value when pricing an order — the copy
  /// the customer's browser sends back is display-only and never trusted.
  final double priceDelta;

  AmountOption({
    required this.label,
    this.value,
    this.priceDelta = 0,
  });

  // Amounts saved before this feature existed have no 'price_delta' key, so
  // they fall back to 0 (no price change). No migration needed.
  factory AmountOption.fromJson(Map<String, dynamic> j) => AmountOption(
        label: j['label'],
        value: j['value']?.toString(),
        priceDelta: (j['price_delta'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'price_delta': priceDelta,
      };
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

// ── Product variant ───────────────────────────────────────────────────────────
// An instance of a product with its own price and its own ingredient
// configuration (e.g. Coffee → "Single" / "Double", where each carries a
// different coffee/water amount). A product with no variants behaves exactly
// as before.
class ProductVariant {
  final String id;
  final String name;

  /// Absolute price for this variant. When set it WINS over [priceDelta] and
  /// over the product's base price. Use it for "Single €2.50 / Double €3.50".
  final double? priceOverride;

  /// Signed euro adjustment added to the product's base price when no
  /// [priceOverride] is set (e.g. Double = +€1.00). 0 = same as base.
  final double priceDelta;

  /// This variant's own ingredient list — independent of the base product's.
  final List<Ingredient> ingredients;

  ProductVariant({
    required this.id,
    required this.name,
    this.priceOverride,
    this.priceDelta = 0,
    this.ingredients = const [],
  });

  /// The effective price of this variant given the product's [basePrice].
  /// Override wins; otherwise base + delta. Never below 0.
  double effectivePrice(double basePrice) {
    final p = priceOverride ?? (basePrice + priceDelta);
    return p < 0 ? 0 : p;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
        id: j['id'],
        name: j['name'] ?? '',
        priceOverride: (j['price_override'] as num?)?.toDouble(),
        priceDelta: (j['price_delta'] as num?)?.toDouble() ?? 0,
        ingredients: (j['ingredients'] as List? ?? [])
            .map((i) => Ingredient.fromJson(i))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price_override': priceOverride,
        'price_delta': priceDelta,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
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
  List<ProductVariant> variants;
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
    this.variants = const [],
    this.tags = const [],
    this.inStock = true,
    required this.createdAt,
  });

  /// Lowest effective price across variants, or the base price when there are
  /// none. Used for the "from €X" label on the menu card.
  double get fromPrice {
    if (variants.isEmpty) return price;
    return variants
        .map((v) => v.effectivePrice(price))
        .reduce((a, b) => a < b ? a : b);
  }

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
        variants: (j['variants'] as List? ?? [])
            .map((v) => ProductVariant.fromJson(v))
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
        'variants': variants.map((v) => v.toJson()).toList(),
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
  bool acceptsCash;
  String? receiptProvider;
  String? vatNumber;

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
    this.acceptsCash = false,
    this.receiptProvider,
    this.vatNumber,
  });

  factory Bar.fromJson(Map<String, dynamic> j) => Bar(
        id: j['id'],
        name: j['name'],
        ownerEmail: j['owner_email'] ?? '',
        joinCode: j['join_code'] as String?,
        theme: BarTheme.fromJson(j['theme'] ?? {}),
        location:
            j['location'] != null ? BarLocation.fromJson(j['location']) : null,
        menu: (j['menu'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, Category.fromJson(v)),
        ),
        qrCodeUrl: j['qr_code_url'],
        createdAt: j['created_at'] ?? '',
        acceptsCash: j['accepts_cash'] as bool? ?? false,
        receiptProvider: j['receipt_provider'] as String?,
        vatNumber: j['vat_number'] as String?,
      );
}

// ── Order ─────────────────────────────────────────────────────────────────────
class OrderItem {
  final String? productId;
  final String productName;
  final String? variantName; // null = product has no variants
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<Map<String, dynamic>> customizations;
  final String notes;
  final double vatRate;

  OrderItem.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'] as String?,
        productName = j['product_name'] as String? ?? '',
        variantName = j['variant_name'] as String?,
        quantity = (j['quantity'] as num).toInt(),
        unitPrice = (j['price'] as num).toDouble(),
        lineTotal =
            (j['price'] as num).toDouble() * (j['quantity'] as num).toInt(),
        customizations = (j['customizations'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        notes = j['notes'] as String? ?? '',
        vatRate = (j['vat_rate'] as num?)?.toDouble() ?? 0.0;
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
  final String? receiptMark;  // myDATA ΜΑΡΚ (null until issued)
  final String? receiptQrUrl; // verification QR url

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