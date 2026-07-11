import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/bar_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';

class ProductFormScreen extends StatefulWidget {
  final String catId;
  final Product? existing;

  const ProductFormScreen({super.key, required this.catId, this.existing});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _prepTime;
  late final TextEditingController _tags;

  final _nameFocus        = FocusNode();
  final _descriptionFocus = FocusNode();
  final _priceFocus       = FocusNode();
  final _prepTimeFocus    = FocusNode();
  final _tagsFocus        = FocusNode();

  late List<_IngredientDraft> _ingredients;
  bool _loading = false;

  // ── Image state ─────────────────────────────────────────────────────────
  File? _pickedImage;
  String? _existingImageUrl;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name        = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price       = TextEditingController(text: p?.price.toString() ?? '');
    _prepTime    = TextEditingController(
        text: p?.preparationTimeMin.toString() ?? '5');
    _tags        = TextEditingController(text: p?.tags.join(', ') ?? '');
    _ingredients = (p?.ingredients ?? [])
        .map((ing) => _IngredientDraft.fromIngredient(ing))
        .toList();
    _existingImageUrl = p?.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _prepTime.dispose();
    _tags.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _priceFocus.dispose();
    _prepTimeFocus.dispose();
    _tagsFocus.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadImageIfNeeded(String productId) async {
    if (_pickedImage == null) return _existingImageUrl;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final filename = _pickedImage!.path.split('/').last;
      final url = await ApiService.uploadProductImage(
        productId: productId,
        imageBytes: bytes,
        filename: filename,
      );
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image upload failed: $e',
              style: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return _existingImageUrl; // fall back to existing on error
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final prov = context.read<BarProvider>();

    try {
      // For new products, generate a temp ID for the image path
      final productId = widget.existing?.id ?? _uuid.v4();

      // Upload image first if one was picked
      final imageUrl = await _uploadImageIfNeeded(productId);

      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price': double.parse(_price.text.trim()),
        'preparation_time_min': int.tryParse(_prepTime.text.trim()) ?? 5,
        'tags': _tags.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'ingredients': _ingredients.map((i) => i.toJson()).toList(),
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (widget.existing != null) {
        await prov.updateProduct(widget.catId, widget.existing!.id, data);
      } else {
        await prov.addProduct(widget.catId, data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(),
              style: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: Text(
          widget.existing != null ? 'Edit Product' : 'New Product',
        ),
        flexibleSpace: Container(
          decoration:
              const BoxDecoration(gradient: AppGradients.sunsetGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Image picker ───────────────────────────────────────────
            _SectionCard(
              title: 'Product Image',
              icon: Icons.image_outlined,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.shell,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.pebble, width: 1.5),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _buildImagePreview(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.ocean,
                          side: const BorderSide(color: AppTheme.ocean),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(
                          _pickedImage != null || _existingImageUrl != null
                              ? 'Change Image'
                              : 'Pick Image',
                          style: const TextStyle(
                              fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_pickedImage != null || _existingImageUrl != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _pickedImage = null;
                          _existingImageUrl = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(
                              color: AppTheme.danger.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Remove',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Basic info ─────────────────────────────────────────────
            _SectionCard(
              title: 'Basic Info',
              icon: Icons.info_outline_rounded,
              children: [
                TextFormField(
                  controller: _name,
                  focusNode: _nameFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_descriptionFocus),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    prefixIcon: Icon(Icons.fastfood_outlined,
                        color: AppTheme.dune, size: 20),
                  ),
                  validator: (v) => v!.isNotEmpty ? null : 'Required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  focusNode: _descriptionFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_priceFocus),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes_rounded,
                        color: AppTheme.dune, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        focusNode: _priceFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_prepTimeFocus),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Price (€) *',
                          prefixIcon: Icon(Icons.euro_rounded,
                              color: AppTheme.dune, size: 20),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return n != null ? null : 'Valid price?';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _prepTime,
                        focusNode: _prepTimeFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_tagsFocus),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Prep time (min)',
                          prefixIcon: Icon(Icons.timer_outlined,
                              color: AppTheme.dune, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  focusNode: _tagsFocus,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'vegan, cold, coffee',
                    prefixIcon: Icon(Icons.label_outline_rounded,
                        color: AppTheme.dune, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Ingredients ────────────────────────────────────────────
            _SectionCard(
              title: 'Ingredients',
              icon: Icons.egg_alt_outlined,
              trailing: _AddButton(
                label: 'Add',
                onTap: _addIngredient,
              ),
              children: [
                if (_ingredients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No ingredients yet. Add some so customers can customise their order.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ..._ingredients.asMap().entries.map(
                  (e) => _IngredientEditor(
                    key: ValueKey(e.value.id),
                    draft: e.value,
                    onDelete: () =>
                        setState(() => _ingredients.removeAt(e.key)),
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_uploadingImage)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.ocean)),
                    SizedBox(width: 10),
                    Text('Uploading image…',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            PrimaryButton(
              label: widget.existing != null ? 'Save Changes' : 'Add Product',
              icon: Icons.check_rounded,
              loading: _loading || _uploadingImage,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover);
    }
    if (_existingImageUrl != null) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 40, color: AppTheme.dune.withOpacity(0.6)),
        const SizedBox(height: 8),
        Text('Tap to add image',
            style: TextStyle(
                fontFamily: 'Nunito',
                color: AppTheme.dune.withOpacity(0.8),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientDraft(id: _uuid.v4(), name: ''));
    });
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() {});
    });
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.pebble, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.ocean.withOpacity(.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.ocean, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontSize: 16)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── Small add button ──────────────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.sunYellow.withOpacity(.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.sunYellow.withOpacity(.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: AppTheme.coral),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.coral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient draft ──────────────────────────────────────────────────────────
class _IngredientDraft {
  final String id;
  String name;
  bool removable;
  List<_AmountDraft> amounts;
  int? defaultAmountIndex;

  _IngredientDraft({
    required this.id,
    required this.name,
    this.removable = true,
    List<_AmountDraft>? amounts,
    this.defaultAmountIndex,
  }) : amounts = amounts ?? [];

  factory _IngredientDraft.fromIngredient(Ingredient ing) => _IngredientDraft(
        id: ing.id,
        name: ing.name,
        removable: ing.removable,
        amounts: ing.amounts
            .map((a) =>
                _AmountDraft(label: a.label, value: a.value?.toString() ?? ''))
            .toList(),
        defaultAmountIndex: ing.defaultAmountIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'removable': removable,
        'amounts': amounts.map((a) => a.toJson()).toList(),
        'default_amount_index': defaultAmountIndex,
      };
}

class _AmountDraft {
  String label;
  String value;

  _AmountDraft({required this.label, required this.value});

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value.isNotEmpty ? num.tryParse(value) : null,
      };
}

// ── Ingredient editor row ─────────────────────────────────────────────────────
class _IngredientEditor extends StatefulWidget {
  final _IngredientDraft draft;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _IngredientEditor({
    super.key,
    required this.draft,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_IngredientEditor> createState() => _IngredientEditorState();
}

class _IngredientEditorState extends State<_IngredientEditor> {
  bool _expanded = false;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.draft.name.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.shell,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.pebble, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: d.name,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Sugar',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) {
                    d.name = v;
                    widget.onChanged();
                  },
                ),
              ),
              Tooltip(
                message: d.removable
                    ? 'Customers can remove this'
                    : 'Fixed ingredient',
                child: IconButton(
                  icon: Icon(
                    d.removable
                        ? Icons.remove_circle_outline_rounded
                        : Icons.lock_outline_rounded,
                    color: d.removable ? AppTheme.ocean : AppTheme.dune,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => d.removable = !d.removable),
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.tune_rounded,
                  color: AppTheme.dune,
                  size: 18,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: 'Amount options',
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.danger, size: 18),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.pebble),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Amount options',
                        style: TextStyle(
                          color: AppTheme.ocean,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      _AddButton(
                        label: 'Add amount',
                        onTap: () => setState(() =>
                            d.amounts.add(_AmountDraft(label: '', value: ''))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (d.amounts.isEmpty)
                    Text(
                      'No amounts — ingredient is a simple on/off toggle.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ...d.amounts.asMap().entries.map((e) => _AmountRow(
                        index: e.key,
                        draft: e.value,
                        isDefault: d.defaultAmountIndex == e.key,
                        onSetDefault: () =>
                            setState(() => d.defaultAmountIndex = e.key),
                        onDelete: () =>
                            setState(() => d.amounts.removeAt(e.key)),
                        autoFocus: e.value.label.isEmpty,
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Amount row ────────────────────────────────────────────────────────────────
class _AmountRow extends StatelessWidget {
  final int index;
  final _AmountDraft draft;
  final bool isDefault;
  final bool autoFocus;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AmountRow({
    required this.index,
    required this.draft,
    required this.isDefault,
    required this.onSetDefault,
    required this.onDelete,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelFocus = FocusNode();
    final valueFocus = FocusNode();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSetDefault,
            child: Icon(
              isDefault ? Icons.star_rounded : Icons.star_border_rounded,
              color: isDefault ? AppTheme.sunYellow : AppTheme.dune,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: draft.label,
              focusNode: labelFocus,
              autofocus: autoFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(valueFocus),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Label (e.g. Sweet)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (v) => draft.label = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: draft.value,
              focusNode: valueFocus,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Value (opt.)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => draft.value = v,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}