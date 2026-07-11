import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/umbrella_locator_dialog.dart';
import '../../services/receipt_printer.dart';

// Light purple palette for cash orders
const _cashPurple      = Color(0xFF9575CD); // accents, borders, badge text
const _cashPurpleLight = Color(0xFFF3EEFB); // card background tint
const _cashPurpleDark  = Color(0xFF6A4FA3); // stronger text on light purple

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarProvider>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BarProvider>(
      builder: (context, prov, _) {
        return Column(
          children: [
            OceanHeader(
              title: prov.isCook
                  ? 'Kitchen'
                  : prov.isWaiter
                      ? 'Delivery'
                      : 'Orders',
              subtitle: prov.isStaff
                  ? '${prov.staffName ?? 'Staff'} · ${prov.orders.length} orders'
                  : '${prov.orders.length} total',
              actions: [
                if (prov.isStaff)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: () => prov.logout(),
                    tooltip: 'Log out',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: prov.loadOrders,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            Expanded(
              child: prov.orders.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No orders yet',
                      subtitle:
                          'New orders will appear here in real-time\nonce customers scan your QR code',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: prov.orders.length,
                      itemBuilder: (ctx, i) =>
                          _OrderCard(order: prov.orders[i], prov: prov),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final BarProvider prov;

  const _OrderCard({required this.order, required this.prov});

  @override
  Widget build(BuildContext context) {
    final isPaid  = order.paymentStatus == 'paid';
    final isCash  = order.paymentMethod == 'cash';
    final cashDue = isCash && order.paymentStatus == 'cash_due';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Cash orders get a light purple card so they stand out instantly
        color: isCash ? _cashPurpleLight : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCash
              ? _cashPurple.withOpacity(0.45)
              : isPaid
                  ? AppTheme.seafoam.withOpacity(0.4)
                  : AppTheme.pebble,
          width: (isCash || isPaid) ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCash ? _cashPurple : AppTheme.textPrimary)
                .withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (isCash)
                          _Badge(
                            label: cashDue ? '💵 Cash due' : '💵 Cash paid',
                            color: cashDue ? _cashPurpleDark : AppTheme.seafoam,
                            bg: cashDue
                                ? _cashPurple.withOpacity(0.14)
                                : AppTheme.seafoam.withOpacity(0.12),
                            border: cashDue
                                ? _cashPurple.withOpacity(0.35)
                                : AppTheme.seafoam.withOpacity(0.3),
                          )
                        else if (isPaid)
                          _Badge(
                            label: '💳 Paid',
                            color: AppTheme.seafoam,
                            bg: AppTheme.seafoam.withOpacity(0.12),
                            border: AppTheme.seafoam.withOpacity(0.3),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.items.length} items · €${order.total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (order.umbrellaNumber != null)
                          Row(
                            children: [
                              Text(
                                '🏖 Table #${order.umbrellaNumber}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (!prov.isCook) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => showUmbrellaLocatorDialog(
                                      context, order.umbrellaNumber!),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.map_outlined,
                                        size: 16, color: AppTheme.ocean),
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...order.items.map((item) => _OrderItemRow(item: item)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _StatusActions(order: order, prov: prov, role: prov.role),
          ],
        ),
      ),
    );
  }
}

// ── Small payment badge ───────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final Color border;

  const _Badge({
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ── Single item row with expandable customizations ────────────────────────────
class _OrderItemRow extends StatefulWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  State<_OrderItemRow> createState() => _OrderItemRowState();
}

class _OrderItemRowState extends State<_OrderItemRow> {
  bool _expanded = false;

  List<Map<String, dynamic>> get _custs => widget.item.customizations
      .where((e) =>
          e['removed'] == true ||
          (e['amount'] != null && (e['amount'] as String).isNotEmpty))
      .toList();

  String get _notes => widget.item.notes.trim();

  // First 5 words of note for collapsed preview
  String get _notesPreview {
    final words = _notes.split(RegExp(r'\s+'));
    if (words.length <= 5) return _notes;
    return '${words.take(5).join(' ')}…';
  }

  bool get _hasDetails => _custs.isNotEmpty || _notes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main item row ────────────────────────────────────────────────
          Row(
              children: [
                // Quantity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.ocean.withOpacity(.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.item.quantity}×',
                    style: const TextStyle(
                      color: AppTheme.ocean,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Product name
                Expanded(
                  child: Text(
                    widget.item.productName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                // Line total
                Text(
                  '€${widget.item.lineTotal.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: AppTheme.ocean),
                ),
                // Chevron — only if there's something to show
                if (_hasDetails) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),

          // ── Collapsed preview line ───────────────────────────────────────
          if (_hasDetails && !_expanded) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                _buildPreviewLine(),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // ── Expanded detail panel ────────────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 38),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.ocean.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.ocean.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customizations
                  ..._custs.map((c) => _CustomizationRow(c: c)),
                  // Notes — full text when expanded
                  if (_notes.isNotEmpty) ...[
                    if (_custs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppTheme.ocean.withOpacity(0.1)),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _notes,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5D4037),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String _buildPreviewLine() {
    final parts = <String>[];
    for (final c in _custs.take(2)) {
      final name = c['name'] as String? ?? '';
      if (c['removed'] == true) {
        parts.add('✕ $name');
      } else if (c['amount'] != null) {
        parts.add('$name: ${c['amount']}');
      }
    }
    if (_custs.length > 2) parts.add('+${_custs.length - 2} more');
    if (_notes.isNotEmpty) parts.add('📝 $_notesPreview');
    return parts.join(' · ');
  }
}

// ── Single customization row inside expanded panel ────────────────────────────
class _CustomizationRow extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CustomizationRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final name = c['name'] as String? ?? '';
    final removed = c['removed'] == true;
    final amount = c['amount'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            removed ? '✕' : '•',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: removed
                  ? const Color(0xFFE53935).withOpacity(0.8)
                  : AppTheme.ocean.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: removed
                  ? AppTheme.textSecondary.withOpacity(0.5)
                  : AppTheme.textPrimary,
              decoration: removed ? TextDecoration.lineThrough : null,
            ),
          ),
          if (!removed && amount != null && amount.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.ocean.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                amount,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ocean,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status actions ────────────────────────────────────────────────────────────
class _StatusActions extends StatelessWidget {
  final Order order;
  final BarProvider prov;
  final String? role; // null = admin

  const _StatusActions({
    required this.order,
    required this.prov,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final allNext = _nextStatuses(order.status);

    // Filter by role:
    // cook   → can only press 'ready'
    // waiter → can only press 'delivered'
    // admin  → sees all
    final visible = allNext.where((s) {
      if (role == 'cook')   return s == 'ready';
      if (role == 'waiter') return s == 'delivered';
      return true;
    }).toList();

    final showPrint = order.receiptMark != null && !prov.isCook;

    if (visible.isEmpty && !showPrint) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ── Print receipt — only when the πάροχος issued one ──────────────
        if (showPrint)
  OutlinedButton.icon(
    onPressed: () async {
      final ok = await ReceiptPrinter.printReceipt(
        order,
        barName: prov.bar?.name,
        vatNumber: prov.bar?.vatNumber,
      );
      if (!ok && context.mounted) {
        showReceiptPreview(context, order,
            barName: prov.bar?.name, vatNumber: prov.bar?.vatNumber);
      }
    },
    style: OutlinedButton.styleFrom(
      foregroundColor: AppTheme.ocean,
      backgroundColor: AppTheme.ocean.withOpacity(.06),
      side: BorderSide(color: AppTheme.ocean.withOpacity(.4), width: 1.2),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    icon: const Icon(Icons.print_rounded, size: 16),
    label: const Text('Print receipt 🧾',
        style: TextStyle(
            fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
  ),

        // ── Status buttons ─────────────────────────────────────────────────
        ...visible.map((s) {
          final isCashDelivery = s == 'delivered' &&
              order.paymentMethod == 'cash' &&
              order.paymentStatus == 'cash_due';

          final (color, label, icon) = isCashDelivery
              ? (_cashPurpleDark, 'Delivered · collect €${order.total.toStringAsFixed(2)}',
                 Icons.payments_rounded)
              : _statusMeta(s);

          return OutlinedButton.icon(
            onPressed: () {
              if (isCashDelivery) {
                _confirmCashCollection(context);
              } else {
                prov.updateOrderStatus(order.id, s);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              backgroundColor: color.withOpacity(.06),
              side: BorderSide(color: color.withOpacity(.4), width: 1.2),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: Icon(icon, size: 16),
            label: Text(label,
                style: const TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          );
        }),
      ],
    );
  }

  /// Cash order delivery: confirm the money was actually collected.
  /// On confirm → collect-cash (flips cash_due → paid, backend issues the
  /// receipt) → then mark delivered.
  Future<void> _confirmCashCollection(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Text('💵', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Cash collected?',
                  style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Text(
          'Confirm you collected €${order.total.toStringAsFixed(2)} in cash '
          'for Table #${order.umbrellaNumber ?? '—'}.\n\n'
          'This marks the order as paid & delivered and issues the receipt.',
          style: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not yet',
                style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cashPurpleDark),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Collected €${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
  final updated = await prov.collectCashAndDeliver(order.id);
  debugPrint('collect done: mark=${updated?.receiptMark}');
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('💵 Cash collected — order delivered')),
  );
  if (updated != null && updated.receiptMark != null) {
    final printed = await ReceiptPrinter.printReceipt(
      updated,
      barName: prov.bar?.name,
      vatNumber: prov.bar?.vatNumber,
    );
    if (!printed && context.mounted) {
      // No printer (emulator / Windows / phone) — show preview instead
      showReceiptPreview(context, updated,
          barName: prov.bar?.name, vatNumber: prov.bar?.vatNumber);
    }
  }
} catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  List<String> _nextStatuses(String current) => switch (current) {
        'pending'  => ['ready'],
        'ready'    => ['delivered'],
        _          => [],
      };

  (Color, String, IconData) _statusMeta(String s) => switch (s) {
        'ready'     => (AppTheme.seafoam, 'Ready!', Icons.done_all),
        'delivered' => (AppTheme.dune, 'Delivered', Icons.delivery_dining),
        _           => (AppTheme.textSecondary, s, Icons.circle_outlined),
      };
}