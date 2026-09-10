import 'package:flutter/material.dart';

/// Original pastel artwork atlas. Rows have explicit bounds because the
/// illustrations use slightly different spacing in the generated source.
class PastelArtwork extends StatelessWidget {
  const PastelArtwork(
      {super.key, required this.categoryNumber, this.size = 24});
  final int categoryNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index =
        categoryNumber <= 33 ? categoryNumber - 1 : categoryNumber - 2;
    final int row;
    final int column;
    final int columns;
    if (index < 32) {
      row = index ~/ 8;
      column = index % 8;
      columns = 8;
    } else if (index < 41) {
      row = 4;
      column = index - 32;
      columns = 9;
    } else {
      row = 5 + (index - 41) ~/ 8;
      column = (index - 41) % 8;
      columns = 8;
    }
    const bounds = [0.0, 210.0, 380.0, 552.0, 720.0, 884.0, 1050.0, 1254.0];
    final edges = row == 5
        ? <double>[0, 155, 303, 454, 583, 761, 941, 1090, 1254]
        : row == 4
            ? <double>[0, 158, 289, 439, 585, 718, 860, 998, 1120, 1254]
            : List<double>.generate(columns + 1, (i) => 1254 * i / columns);
    final cellWidth = edges[column + 1] - edges[column];
    final cellHeight = bounds[row + 1] - bounds[row];
    final scale = size / (cellWidth > cellHeight ? cellWidth : cellHeight);
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: SizedBox(width: cellWidth * scale, height: cellHeight * scale, child: ClipRect(
        child: Stack(children: [
          Positioned(
            left: -edges[column] * scale,
            top: -bounds[row] * scale,
            width: 1254 * scale,
            height: 1254 * scale,
            child: Image.asset('assets/images/categories/pastel_atlas.png',
                fit: BoxFit.fill, filterQuality: FilterQuality.medium),
          ),
        ]),
      ))),
    );
  }
}

/// Keep saved goal icon codes compatible while presenting the new artwork.
class GoalArtwork extends StatelessWidget {
  const GoalArtwork(this.icon, {super.key, this.size = 24, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  static const icons = [
    Icons.restaurant,
    Icons.local_cafe,
    Icons.home,
    Icons.directions_car,
    Icons.receipt_long,
    Icons.shopping_bag,
    Icons.card_giftcard,
    Icons.flight,
    Icons.spa,
    Icons.music_note,
    Icons.sports_soccer,
    Icons.pets,
    Icons.school,
  ];
  @override
  Widget build(BuildContext context) {
    final index = icons.indexWhere((item) => item.codePoint == icon.codePoint);
    final extra = <int, int>{
      Icons.category_outlined.codePoint: 32,
      Icons.payments.codePoint: 14,
      Icons.trending_up.codePoint: 20,
      Icons.card_membership.codePoint: 16,
      Icons.savings.codePoint: 17,
      Icons.fastfood.codePoint: 1,
      Icons.local_hospital.codePoint: 49,
      Icons.build.codePoint: 43,
      Icons.pets_outlined.codePoint: 12,
      Icons.celebration.codePoint: 26,
      Icons.wifi.codePoint: 46,
      Icons.subscriptions.codePoint: 47,
    };
    final number = index >= 0 ? index + 1 : extra[icon.codePoint];
    return number == null
        ? Icon(icon, size: size, color: color)
        : Center(child: PastelArtwork(categoryNumber: number, size: size));
  }
}
