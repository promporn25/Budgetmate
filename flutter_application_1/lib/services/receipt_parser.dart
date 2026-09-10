/// Conservative suggestions only: the user reviews the receipt before saving.
class ReceiptDraft {
  final double? amount;
  final DateTime? date;
  final String merchant;
  const ReceiptDraft({this.amount, this.date, required this.merchant});

  factory ReceiptDraft.fromText(String text) {
    const thai = '๐๑๒๓๔๕๖๗๘๙';
    for (var i = 0; i < thai.length; i++) {
      text = text.replaceAll(thai[i], '$i');
    }
    final lines = text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    double? amount;
    var bestPriority = 0;
    final money = RegExp(r'(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{2})?(?![\d.])');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (RegExp(r'sub\s*total|ยอดก่อน|เงินทอน|change|cash|เงินสด|vat|ภาษี')
          .hasMatch(line)) {
        continue;
      }
      final priority =
          RegExp(r'grand\s*total|net\s*total|amount\s*due|ยอดสุทธิ|ยอดชำระ|รวมสุทธิ|รวมทั้งสิ้น')
                  .hasMatch(line)
              ? 2
              : RegExp(r'\btotal\b|ยอดรวม|รวมเงิน').hasMatch(line)
                  ? 1
                  : 0;
      if (priority == 0 || priority < bestPriority) continue;
      var matches = money.allMatches(line).toList();
      if (matches.isEmpty &&
          i + 1 < lines.length &&
          RegExp(r'^[฿\$\s\d,.]+(?:\s*(?:บาท|THB))?$', caseSensitive: false)
              .hasMatch(lines[i + 1])) {
        matches = money.allMatches(lines[i + 1]).toList();
      }
      if (matches.isNotEmpty) {
        final value =
            double.tryParse(matches.last.group(0)!.replaceAll(',', ''));
        if (value != null && value.isFinite && value > 0) {
          amount = value;
          bestPriority = priority;
        }
      }
    }
    DateTime? date;
    final match =
        RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\b').firstMatch(text);
    if (match != null) {
      final day = int.parse(match[1]!);
      final month = int.parse(match[2]!);
      var year = int.parse(match[3]!);
      if (year >= 2400) year -= 543;
      final candidate = DateTime(year, month, day);
      if (year >= 2000 &&
          year <= 2200 &&
          candidate.year == year &&
          candidate.month == month &&
          candidate.day == day) {
        date = candidate;
      }
    }
    return ReceiptDraft(
        amount: amount, date: date, merchant: lines.isEmpty ? '' : lines.first);
  }
}
