import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../screens/app_theme.dart';

Future<CategoryModel?> showReceiptCategoryPicker(
  BuildContext context, {
  required List<CategoryModel> categories,
  required String? selectedId,
  required bool thai,
}) =>
    showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => _CategoryPicker(
          categories: categories, selectedId: selectedId, thai: thai),
    );

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker(
      {required this.categories, required this.selectedId, required this.thai});
  final List<CategoryModel> categories;
  final String? selectedId;
  final bool thai;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where(
            (c) => c.name.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                        child: Container(
                            width: 38,
                            height: 5,
                            decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.accentAltBg,
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: AppColors.ink)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              widget.thai
                                  ? 'เลือกหมวดหมู่'
                                  : 'Choose a category',
                              style: AppTextStyles.heading)),
                      IconButton(
                          tooltip: widget.thai ? 'ปิด' : 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: AppColors.ink)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                          hintText: widget.thai
                              ? 'ค้นหาหมวดหมู่'
                              : 'Search categories',
                          prefixIcon:
                              Icon(Icons.search_rounded, color: AppColors.ink),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                        child: categories.isEmpty
                            ? Center(
                                child: Text(
                                    widget.thai
                                        ? 'ไม่พบหมวดหมู่นี้ ลองค้นหาใหม่นะ'
                                        : 'No categories found. Try another search.',
                                    textAlign: TextAlign.center))
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: categories.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final selected =
                                      category.id == widget.selectedId;
                                  final colors = [
                                    AppColors.accentBg,
                                    AppColors.surfaceAlt,
                                    AppColors.accentAltBg
                                  ];
                                  return Semantics(
                                      selected: selected,
                                      child: Material(
                                        color: selected
                                            ? AppColors.accentBg
                                            : colors[index % colors.length]
                                                .withValues(alpha: .55),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            side: BorderSide(
                                                color: selected
                                                    ? AppColors.ink
                                                    : Colors.transparent)),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () =>
                                              Navigator.pop(context, category),
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                              child: Row(children: [
                                                CategoryIcon(
                                                    category: category,
                                                    size: 44),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                    child: Text(category.name,
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textPrimary))),
                                                if (selected)
                                                  Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: AppColors.ink),
                                              ])),
                                        ),
                                      ));
                                },
                              )),
                  ]),
            )),
      ),
    );
  }
}
