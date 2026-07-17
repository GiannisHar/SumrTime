import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'product_form.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BarProvider>(
      builder: (context, prov, _) {
        final bar = prov.bar!;
        return Column(
          children: [
            OceanHeader(
              title: 'Menu',
              subtitle: '${bar.menu.length} categories',
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: () => _showAddCategory(context, prov),
                  tooltip: 'Add category',
                ),
              ],
            ),
            Expanded(
              child: bar.menu.isEmpty
                  ? EmptyState(
                      icon: Icons.restaurant_menu_outlined,
                      title: 'No categories yet',
                      subtitle:
                          'Tap + to add your first category\n(e.g. Drinks, Food)',
                      action: ElevatedButton.icon(
                        onPressed: () => _showAddCategory(context, prov),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Category'),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: bar.menu.values
                          .map((cat) =>
                              _CategorySection(cat: cat, prov: prov))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddCategory(BuildContext context, BarProvider prov) {
    final nameCtrl = TextEditingController();
    final nameFocus = FocusNode();
    String type = 'drink';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.pebble,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'New Category',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                focusNode: nameFocus,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) async {
                  if (nameCtrl.text.isNotEmpty) {
                    await prov.addCategory(nameCtrl.text.trim(), type);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  prefixIcon: Icon(Icons.label_outline_rounded,
                      color: AppTheme.dune, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'drink',
                    label: Text('Drinks'),
                    icon: Icon(Icons.local_drink_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'food',
                    label: Text('Food'),
                    icon: Icon(Icons.fastfood_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'other',
                    label: Text('Other'),
                    icon: Icon(Icons.category_outlined, size: 16),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Add Category',
                icon: Icons.add_rounded,
                onTap: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    await prov.addCategory(nameCtrl.text.trim(), type);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────
class _CategorySection extends StatelessWidget {
  final Category cat;
  final BarProvider prov;

  const _CategorySection({required this.cat, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppGradients.seafoamGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(cat.type), color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      cat.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${cat.products.length} items',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              _IconBtn(
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.ocean,
                tooltip: 'Add product',
                onTap: () => _addProduct(context),
              ),
              const SizedBox(width: 2),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.danger,
                tooltip: 'Delete category',
                onTap: () => _deleteCategory(context),
              ),
            ],
          ),
        ),
        ...cat.products.values
            .map((prod) => _ProductTile(cat: cat, prod: prod, prov: prov)),
        if (cat.products.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: Text(
              'No products yet — tap + to add one',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  IconData _typeIcon(String type) => switch (type) {
        'drink' => Icons.local_drink_outlined,
        'food' => Icons.fastfood_outlined,
        _ => Icons.category_outlined,
      };

  void _addProduct(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductFormScreen(catId: cat.id),
    ));
  }

  void _deleteCategory(BuildContext context) {
    // Guard: category must have 0 or 1 products to be deletable.
    if (cat.products.length > 1) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Cannot delete',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          content: Text(
            '"${cat.name}" has ${cat.products.length} products. '
            'Delete its products first — a category can only be deleted '
            'when it has 1 product or less.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
            style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: Text(
          cat.products.isEmpty
              ? 'This category will be permanently deleted.'
              : 'This category and its 1 product will be permanently deleted.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              prov.deleteCategory(cat.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Product tile ──────────────────────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Category cat;
  final Product prod;
  final BarProvider prov;

  const _ProductTile(
      {required this.cat, required this.prod, required this.prov});

  Widget _fallbackIcon(bool inStock) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: inStock
            ? AppTheme.ocean.withOpacity(.08)
            : AppTheme.coral.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        inStock ? Icons.fastfood_outlined : Icons.block_rounded,
        color: inStock ? AppTheme.ocean : AppTheme.coral,
        size: 20,
      ),
    );
  }

  void _deleteProduct(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${prod.name}"?',
            style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: const Text(
          'This product will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              prov.deleteProduct(cat.id, prod.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  /// Subtitle line: price (or "from €X" when variants exist) · prep · counts.
  String _subtitle() {
    final hasVariants = prod.variants.isNotEmpty;
    final priceStr = hasVariants
        ? 'from €${prod.fromPrice.toStringAsFixed(2)}'
        : '€${prod.price.toStringAsFixed(2)}';
    final parts = <String>[
      priceStr,
      '${prod.preparationTimeMin} min',
      '${prod.ingredients.length} ingredients',
    ];
    if (hasVariants) {
      parts.add('${prod.variants.length} variants');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final inStock = prod.inStock;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inStock
              ? AppTheme.pebble
              : AppTheme.coral.withOpacity(.3),
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: prod.imageUrl != null
              ? Image.network(
                  prod.imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackIcon(inStock),
                )
              : _fallbackIcon(inStock),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                prod.name,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      decoration:
                          inStock ? null : TextDecoration.lineThrough,
                      decorationColor: AppTheme.coral,
                    ),
              ),
            ),
            if (prod.variants.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.coral.withOpacity(.3)),
                ),
                child: Text(
                  '${prod.variants.length}×',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coral,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          _subtitle(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: inStock,
              onChanged: (v) => prov.toggleStock(cat.id, prod.id, v),
              inactiveThumbColor: Colors.redAccent.withOpacity(0.7),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.dune, size: 18),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ProductFormScreen(catId: cat.id, existing: prod),
              )),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger, size: 18),
              onPressed: () => _deleteProduct(context),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button helper ──────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}