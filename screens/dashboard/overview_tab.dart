import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BarProvider>(
      builder: (context, prov, _) {
        final bar = prov.bar!;
        final totalProducts =
            bar.menu.values.fold(0, (s, c) => s + c.products.length);
        final outOfStock = bar.menu.values.fold(
            0,
            (s, c) =>
                s + c.products.values.where((p) => !p.inStock).length);
        final pendingOrders =
            prov.orders.where((o) => o.status == 'pending').length;

        return CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _BeachHeader(
                barName: bar.name,
                hasLocation: bar.location != null,
                onLogout: prov.logout,
              ),
            ),

            // ── Compact stat row (4 small cards) ────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    _MiniStatCard(
                      label: 'Products',
                      value: totalProducts.toString(),
                      icon: Icons.fastfood_outlined,
                      color: AppTheme.ocean,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatCard(
                      label: 'Categories',
                      value: bar.menu.length.toString(),
                      icon: Icons.category_outlined,
                      color: AppTheme.surf,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatCard(
                      label: 'No Stock',
                      value: outOfStock.toString(),
                      icon: Icons.remove_shopping_cart_outlined,
                      color: outOfStock > 0 ? AppTheme.coral : AppTheme.seafoam,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatCard(
                      label: 'Pending',
                      value: pendingOrders.toString(),
                      icon: Icons.pending_actions_outlined,
                      color: pendingOrders > 0
                          ? AppTheme.sunYellow
                          : AppTheme.dune,
                    ),
                  ],
                ),
              ),
            ),

            // ── Out of stock ─────────────────────────────────────────────
            if (outOfStock > 0) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'OUT OF STOCK'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final outItems = bar.menu.values
                        .expand((c) => c.products.entries
                            .where((e) => !e.value.inStock)
                            .map((e) => (c, e.value)))
                        .toList();
                    if (i >= outItems.length) return null;
                    final (cat, prod) = outItems[i];
                    return _OutOfStockTile(
                      catName: cat.name,
                      prodName: prod.name,
                      onRestock: () => prov.toggleStock(cat.id, prod.id, true),
                    );
                  },
                  childCount: outOfStock,
                ),
              ),
            ],

            // ── Recent orders ────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'RECENT ORDERS'),
            ),
            if (prov.orders.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  subtitle: 'Orders will appear here in real-time',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i >= prov.orders.take(5).length) return null;
                    final order = prov.orders[i];
                    return _OrderTile(order: order);
                  },
                  childCount: prov.orders.take(5).length,
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        );
      },
    );
  }
}

// ── Mini stat card (compact, equal width) ─────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.pebble, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Beach header ──────────────────────────────────────────────────────────────
class _BeachHeader extends StatelessWidget {
  final String barName;
  final bool hasLocation;
  final VoidCallback onLogout;

  const _BeachHeader({
    required this.barName,
    required this.hasLocation,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.sunsetGradient),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('☀️ ', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        barName,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLocation ? Icons.location_on : Icons.location_off,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasLocation ? 'Location set' : 'No location set',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }
}

// ── Out-of-stock tile ─────────────────────────────────────────────────────────
class _OutOfStockTile extends StatelessWidget {
  final String catName;
  final String prodName;
  final VoidCallback onRestock;

  const _OutOfStockTile({
    required this.catName,
    required this.prodName,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.coral.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.block, color: AppTheme.coral, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prodName, style: Theme.of(context).textTheme.bodyLarge),
                Text(catName, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton(
            onPressed: onRestock,
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.seafoam,
                textStyle: const TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}

// ── Order tile ────────────────────────────────────────────────────────────────
class _OrderTile extends StatelessWidget {
  final dynamic order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.pebble, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                    '${order.items.length} items · €${order.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          StatusChip(status: order.status),
        ],
      ),
    );
  }
}