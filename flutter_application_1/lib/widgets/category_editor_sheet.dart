import 'category_artwork_catalog.dart';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../screens/app_theme.dart';
import '../services/data_service.dart';
import 'pastel_artwork.dart';

Future<CategoryModel?> showCategoryArtworkPicker(BuildContext context,
    {required DataService service, required int selected}) {
  return showModalBottomSheet<CategoryModel>(
    context: context, isScrollControlled: true, useSafeArea: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _IconPicker(service: service, selected: selected),
  );
}

const _colors = [
  Color(0xFFC1E4F3), Color(0xFFF6CCD9), Color(0xFFFFE698),
  Color(0xFFCDE7CA), Color(0xFFD8D1EF), Color(0xFFFFD4B5),
  Color(0xFFBFE5DE), Color(0xFFDFE9B6), Color(0xFFD3DCEB),
];

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({super.key, required this.service, required this.type});
  final DataService service;
  final CategoryType type;
  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final _name = TextEditingController();
  final _children = <TextEditingController>[];
  CategoryModel _icon = defaultCategories.first;
  Color _color = _colors.first;
  bool _saving = false;
  String? _error;
  bool get _thai => widget.service.currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;
  int get _number => _icon.artworkNumber ?? int.tryParse(_icon.id.replaceFirst('c', '')) ?? 1;

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _children) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final names = _children.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = widget.service.t('please_enter_category_name'));
      return;
    }
    if (names.map((s) => s.toLowerCase()).toSet().length != names.length) {
      setState(() => _error = _t('ชื่อหมวดหมู่ย่อยต้องไม่ซ้ำกัน', 'Subcategory names must be unique.'));
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final category = await widget.service.addCategory(_name.text, widget.type, _icon.icon,
        colorValue: _color.toARGB32(), artworkNumber: _number, subcategories: names);
      if (mounted) Navigator.pop(context, category);
    } catch (_) {
      if (mounted) setState(() {
        _saving = false;
        _error = _t('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง ข้อมูลยังอยู่', 'Could not save. Your changes are retained. Please try again.');
      });
    }
  }

  Future<void> _chooseIcon() async {
    FocusScope.of(context).unfocus();
    final icon = await showModalBottomSheet<CategoryModel>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _IconPicker(service: widget.service, selected: _number),
    );
    if (mounted && icon != null) setState(() => _icon = icon);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: AbsorbPointer(absorbing: _saving,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(_t('เพิ่มหมวดหมู่ของคุณ', 'Create your category'), style: AppTextStyles.heading.copyWith(fontSize: 19))),
              IconButton.filledTonal(onPressed: _saving ? null : () => Navigator.pop(context),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            Center(child: Semantics(button: true, label: widget.service.t('choose_icon'),
              child: InkWell(onTap: _chooseIcon, borderRadius: BorderRadius.circular(60),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(width: 64, height: 64,
                    decoration: BoxDecoration(color: _color.withValues(alpha: 0.5), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: PastelArtwork(categoryNumber: _number, size: 44)),
                  Positioned(right: -2, top: -2, child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                    child: Icon(Icons.edit_outlined, size: 20, color: AppColors.ink))),
                ]),
              ),
            )),
            TextButton(onPressed: _chooseIcon, child: Text(widget.service.t('choose_icon'))),
            const SizedBox(height: 8),
            SizedBox(height: 52, child: ListView.separated(
              scrollDirection: Axis.horizontal, itemCount: _colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (_, i) => Semantics(selected: _color == _colors[i],
                label: _t('สี ${i + 1}', 'Color ${i + 1}'), button: true,
                child: InkWell(onTap: () => setState(() => _color = _colors[i]),
                  borderRadius: BorderRadius.circular(26),
                  child: Container(width: 48, margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle,
                      border: Border.all(color: _color == _colors[i] ? AppColors.ink : Colors.transparent, width: 2)),
                    child: _color == _colors[i] ? Icon(Icons.check_rounded, color: AppColors.accentDeep) : null),
                ),
              ),
            )),
            const SizedBox(height: 24),
            Text(_t('ชื่อหมวดหมู่', 'Category name'), style: AppTextStyles.label),
            const SizedBox(height: 8),
            AppTextField(controller: _name, hint: widget.service.t('category_name_hint'),
              onChanged: (_) { if (_error != null) setState(() => _error = null); }),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text(_t('หมวดหมู่ย่อย (ไม่บังคับ)', 'Subcategories (optional)'), style: AppTextStyles.label)),
              IconButton.filledTonal(
                tooltip: _t('เพิ่มหมวดหมู่ย่อย', 'Add subcategory'),
                onPressed: () => setState(() => _children.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded)),
            ]),
            for (var i = 0; i < _children.length; i++)
              Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                Expanded(child: AppTextField(controller: _children[i], hint: _t('ชื่อหมวดหมู่ย่อย', 'Subcategory name'))),
                IconButton(tooltip: _t('ลบหมวดหมู่ย่อย', 'Remove subcategory'),
                  onPressed: () {
                    final removed = _children[i];
                    setState(() => _children.removeAt(i));
                    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                  }, icon: const Icon(Icons.close_rounded)),
              ])),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.danger))),
            const SizedBox(height: 26),
            FilledButton(onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.service.t('save'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ]),
        ),
      ),
    ),
  );
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.service, required this.selected});
  final DataService service;
  final int selected;
  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  final _search = TextEditingController();
  String _query = '';
  String _tab = 'all';
  bool get _thai => widget.service.currentLanguage != 'English';
  String _t(String th, String en) => _thai ? th : en;
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final custom = widget.service.categories.where((c) => c.artworkNumber != null);
    final mine = custom.map((c) => c.artworkNumber == 34 ? 33 : c.artworkNumber).toSet();
    final catalog = categoryArtworkCatalog(_thai);
    final tabs = <(String, String)>[
      ('all', _t('ทั้งหมด', 'All')), ('new', _t('มาใหม่', 'New')),
      ('mine', _t('ของฉัน', 'Mine')), ('food', _t('อาหาร', 'Food')),
      ('tech', _t('เทคโนโลยี', 'Tech')), ('travel', _t('เดินทาง', 'Travel')),
      ('life', _t('ของใช้', 'Lifestyle')), ('fashion', _t('แฟชั่น', 'Fashion')),
      ('hobby', _t('งานอดิเรก', 'Hobbies')),
    ];
    final icons = catalog.where((c) {
      final n = artworkNumberOf(c);
      final inTab = _tab == 'all' || (_tab == 'new' && n >= 100) ||
        (_tab == 'mine' && mine.contains(n)) || artworkGroup(n) == _tab;
      final names = [c.name, widget.service.categoryName(c),
        if (n >= 100) extraCategoryArtwork[n - 100].$1,
        if (n >= 100) extraCategoryArtwork[n - 100].$2,
        ...custom.where((item) => item.artworkNumber == n).map((item) => item.name)].join(' ').toLowerCase();
      return inTab && names.contains(_query.trim().toLowerCase());
    }).toList();
    return SizedBox(height: MediaQuery.sizeOf(context).height * 0.88,
      child: SafeArea(top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: CustomScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.auto_awesome_rounded, color: AppColors.ink, size: 23)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.service.t('choose_icon'), style: AppTextStyles.heading.copyWith(fontSize: 20)),
                      Text(_t('เติมความน่ารักให้หมวดหมู่ของคุณ', 'A little personality for your category'),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(context),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      style: IconButton.styleFrom(backgroundColor: AppColors.card, foregroundColor: AppColors.ink),
                      icon: const Icon(Icons.close_rounded, size: 21)),
                  ]),
                  const SizedBox(height: 20),
                  TextField(controller: _search, onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: _t('ค้นหารูป เช่น เค้ก กล้อง ดอกไม้', 'Search cake, camera, flowers'),
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      suffixIcon: _query.isEmpty ? null : IconButton(
                        tooltip: _t('ล้างการค้นหา', 'Clear search'), icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () { _search.clear(); setState(() => _query = ''); }),
                      filled: true, fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.accentDeep)),
                    )),
                  const SizedBox(height: 16),
                  Wrap(spacing: 7, runSpacing: 7, children: tabs.map((tab) => ChoiceChip(
                    label: Text(tab.$2), selected: _tab == tab.$1, showCheckmark: false,
                    onSelected: (_) => setState(() => _tab = tab.$1),
                    backgroundColor: AppColors.card, selectedColor: AppColors.accentBg,
                    side: BorderSide.none, shape: const StadiumBorder(),
                    labelStyle: TextStyle(fontFamily: appFontFamily, fontSize: 12,
                      color: _tab == tab.$1 ? AppColors.ink : AppColors.textSecondary,
                      fontWeight: _tab == tab.$1 ? FontWeight.w700 : FontWeight.w500),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList()),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Text(_t('เลือกรูปที่ใช่', 'Find your favorite'), style: AppTextStyles.label)),
                    Text('${icons.length} '+_t('รูป', 'icons'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                ]),
              )),
              if (icons.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.search_off_rounded, size: 38, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(_tab == 'mine' && _query.isEmpty
                      ? _t('ไอคอนที่บันทึกกับหมวดหมู่จะอยู่ที่นี่', 'Saved category icons will appear here')
                      : _t('ไม่พบรูป ลองค้นหาด้วยคำอื่นนะ', 'No matches. Try another search.'),
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  ]))),
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  key: const Key('category-artwork-grid'),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 88),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final icon = icons[i];
                    final number = artworkNumberOf(icon);
                    final selected = number == (widget.selected == 34 ? 33 : widget.selected);
                    return Tooltip(message: widget.service.categoryName(icon),
                      child: Semantics(button: true, selected: selected, label: widget.service.categoryName(icon),
                        child: Material(color: AppColors.card, borderRadius: BorderRadius.circular(20),
                          child: InkWell(borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context, icon),
                            child: Container(padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: selected ? AppColors.accentDeep : AppColors.border.withValues(alpha: 0.6), width: selected ? 2 : 1)),
                              child: Center(child: PastelArtwork(categoryNumber: number, size: 56))),
                          ),
                        ),
                      ),
                    );
                  }, childCount: icons.length),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
