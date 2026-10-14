/// Bank-independent OCR suggestions. Always review before saving an expense.
class ReceiptDraft {
  final double? amount;
  final DateTime? date;
  final String merchant;
  const ReceiptDraft({this.amount, this.date, required this.merchant});

  static final _excluded = RegExp(
      r'sub\s*total|ยอดก่อน|เงินทอน|change|cash|เงินสด|vat|ภาษี|ค่าธรรมเนียม|fees?\b|balance|ยอดคงเหลือ|เลขที่|เลขอ้างอิง|รหัสอ้างอิง|reference|account|บัญชี',
      caseSensitive: false);
  // Longer labels precede shorter labels, including bilingual slip labels.
  static final _labels = RegExp(
      r'จำนวนเงินที่โอน|ยอดเงินที่โอน|ยอดเงินโอน|ยอดโอน|transfer\s*amount|amount\s*transferred|'
      r'grand\s*total|net\s*total|amount\s*due|ยอดเงินสุทธิ|ยอดสุทธิ|ยอดชำระสุทธิ|รวมสุทธิ|รวมทั้งสิ้น|'
      r'จำนวนเงินที่ชำระ|ยอดเงินที่ชำระ|ยอดที่ชำระ|ยอดชำระ|จำนวนเงิน|ยอดเงิน|ยอดรวม|รวมเงิน|'
      r'payment\s*amount|amount\s*paid|\btotal\b|\bamount\b',
      caseSensitive: false);
  static final _transferLabels = RegExp(
      r'จำนวนเงินที่โอน|ยอดเงินที่โอน|ยอดเงินโอน|ยอดโอน|transfer\s*amount|amount\s*transferred',
      caseSensitive: false);
  static final _netLabels = RegExp(
      r'grand\s*total|net\s*total|amount\s*due|ยอดเงินสุทธิ|ยอดสุทธิ|ยอดชำระสุทธิ|รวมสุทธิ|รวมทั้งสิ้น',
      caseSensitive: false);
  static final _transferContext = RegExp(
      r'โอนเงินสำเร็จ|โอนสำเร็จ|โอนเงิน|ชำระเงินสำเร็จ|ชำระสำเร็จ|จ่ายเงินสำเร็จ|ทำรายการสำเร็จ|'
      r'transfer\s*(?:successful|completed)|successful\s*transfer|payment\s*(?:successful|completed)|successful\s*payment',
      caseSensitive: false);
  static final _currency = RegExp(r'บาท(?:ไทย)?|THB|฿', caseSensitive: false);

  static String _normalize(String text) {
    const thai = '๐๑๒๓๔๕๖๗๘๙';
    for (var i = 0; i < thai.length; i++) {
      text = text.replaceAll(thai[i], '$i');
    }
    text = text
        .replaceAll('\u0e4d\u0e32', '\u0e33')
        .replaceAll(RegExp('[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('\u00a0', ' ');
    return text.replaceAllMapped(
        RegExp(r'([\u0E00-\u0E7F])[ \t]+(?=[\u0E00-\u0E7F])'),
        (match) => match[1]!);
  }

  factory ReceiptDraft.fromText(String text) {
    final displayLines = text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final normalized = _normalize(text);
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    var bestPriority = 0;
    final candidates = <double>{};
    for (var i = 0; i < lines.length; i++) {
      final exclusion = _excluded.firstMatch(lines[i]);
      // A fee may follow the amount in the same OCR row. Never use the fee
      // itself, or look below an excluded label for a replacement amount.
      final line =
          exclusion == null ? lines[i] : lines[i].substring(0, exclusion.start);
      final labels = _labels.allMatches(line).toList();
      if (labels.isEmpty) continue;
      for (var labelIndex = 0; labelIndex < labels.length; labelIndex++) {
        final label = labels[labelIndex];
        final name = label.group(0)!;
        final priority = _transferLabels.hasMatch(name)
            ? 3
            : _netLabels.hasMatch(name)
                ? 2
                : 1;
        if (priority < bestPriority) continue;
        final tail = line.substring(
            label.end,
            labelIndex + 1 < labels.length
                ? labels[labelIndex + 1].start
                : line.length);
        double? value = _moneyValue(tail);
        if (value == null &&
            exclusion == null &&
            labelIndex == labels.length - 1 &&
            _onlyCurrencyOrSeparator(tail)) {
          // Currency can be printed on its own line between label and value.
          for (var next = i + 1; next < lines.length && next <= i + 2; next++) {
            value = _moneyValue(lines[next]);
            if (value != null || !_onlyCurrencyOrSeparator(lines[next])) break;
          }
        }
        if (value != null && value > 0) {
          if (priority > bestPriority) candidates.clear();
          candidates.add(value);
          bestPriority = priority;
        }
      }
    }

    // Never silently choose one of multiple conflicting labelled totals.
    double? amount = candidates.length == 1 ? candidates.single : null;
    if (candidates.isEmpty && _transferContext.hasMatch(normalized)) {
      final currencyAmounts = <double>{};
      for (var i = 0; i < lines.length; i++) {
        if (_excluded.hasMatch(lines[i])) continue;
        var previous = i - 1;
        if (previous >= 0 && _onlyCurrencyOrSeparator(lines[previous])) {
          previous--;
        }
        if (previous >= 0 && _excluded.hasMatch(lines[previous])) continue;
        final hasCurrency = _currency.hasMatch(lines[i]) ||
            (i > 0 &&
                _currency.hasMatch(lines[i - 1]) &&
                _onlyCurrencyOrSeparator(lines[i - 1])) ||
            (i + 1 < lines.length &&
                _currency.hasMatch(lines[i + 1]) &&
                _onlyCurrencyOrSeparator(lines[i + 1]));
        if (!hasCurrency) continue;
        final value = _moneyValue(lines[i]);
        if (value != null && value > 0) currencyAmounts.add(value);
      }
      if (currencyAmounts.length == 1) amount = currencyAmounts.single;
    }
    return ReceiptDraft(
        amount: amount,
        date: _date(normalized),
        merchant: _merchant(displayLines, normalized));
  }

  static String _merchant(List<String> lines, String normalized) {
    if (lines.isEmpty) return '';
    final recipientLabel = RegExp(
        r'^(?:ชื่อผู้รับ(?:เงิน)?|ผู้รับ(?:เงิน)?|โอนไปยัง|โอนไป|ปลายทาง|recipient|beneficiary|to)(?:\s*[:：\-]\s*|\s+|$)',
        caseSensitive: false);
    final account = RegExp(
        r'(?:[xX*•●][\s\-]*){2,}[\d xX*•●\-]*\d[\d xX*•●\-]*|\b\d{3}-\d-\d{4,5}-\d\b');
    bool isName(String value) {
      final compact = _normalize(value);
      return RegExp(r'[ก-๙a-zA-Z]').hasMatch(value) &&
          !RegExp(r'\d|[xX*•●]{2,}').hasMatch(value) &&
          !_transferContext.hasMatch(compact) &&
          !_excluded.hasMatch(compact) &&
          !_labels.hasMatch(compact) &&
          !RegExp(r'ธนาคาร|กสิกร|ไทยพาณิชย์|กรุงไทย|กรุงเทพ|พร้อมเพย์|promptpay|bank|^make$|^scb$|^k\s*plus$|^จำนวน$|ค่าธรรมเนียม|สแกน|โอนแล้ว',
                  caseSensitive: false)
              .hasMatch(compact);
    }

    final labelled = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final match = recipientLabel.firstMatch(lines[i]);
      if (match == null) continue;
      final tail = lines[i].substring(match.end).trim();
      if (tail.isNotEmpty) {
        if (isName(tail)) labelled.add(tail);
      } else if (i + 1 < lines.length && isName(lines[i + 1])) {
        labelled.add(lines[i + 1]);
      }
    }
    if (labelled.length == 1) return labelled.single;
    if (labelled.length > 1) return '';
    if (_transferContext.hasMatch(normalized)) {
      // Unlabelled slips (including MAKE) print sender then recipient, each
      // followed by a masked account. Require exactly two complete pairs.
      final names = <String>[];
      var accountCount = 0;
      for (var i = 0; i < lines.length; i++) {
        final match = account.firstMatch(lines[i]);
        if (match == null) continue;
        accountCount++;
        final prefix = lines[i].substring(0, match.start).trim();
        if (isName(prefix)) {
          names.add(prefix);
        } else if (i > 0 && isName(lines[i - 1])) {
          names.add(lines[i - 1]);
        }
      }
      return accountCount == 2 && names.length == 2 ? names.last : '';
    }
    return lines.first;
  }

  static bool _onlyCurrencyOrSeparator(String text) =>
      RegExp(r'^[\s:：/()\[\]]*(?:(?:บาท(?:ไทย)?|THB|฿)[\s:：/()\[\]]*)?$',
              caseSensitive: false)
          .hasMatch(text);

  static double? _moneyValue(String text) {
    // Join OCR spaces around numeric punctuation without inventing digits.
    text = text.replaceAllMapped(
        RegExp(r'(\d)\s*([,.])\s*(?=\d)'), (m) => '${m[1]}${m[2]}');
    final match = RegExp(
            r'^[\s:：/]*(?:(?:\(?(?:THB|บาท(?:ไทย)?)\)?|฿|\$)\s*)?'
            r'((?:\d{1,3}(?:,\d{3})+|\d{1,7})(?:\.\d{2}|\.-)?)'
            r'\s*(?:\(?(?:บาท(?:ไทย)?|THB)\)?|฿)?\s*$',
            caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    return double.tryParse(
        match[1]!.replaceAll(',', '').replaceAll('.-', '.00'));
  }

  static DateTime? _validDate(int day, int month, int year) {
    if (year >= 2400) year -= 543;
    if (year < 2000 ||
        year > 2200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static DateTime? _date(String text) {
    final numeric = RegExp(
        r'(?<!\d)(\d{4}|\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{4}|\d{2})(?!\d)');
    for (final m in numeric.allMatches(text)) {
      final iso = m[1]!.length == 4;
      final day = int.parse(m[iso ? 3 : 1]!);
      final month = int.parse(m[2]!);
      var year = int.parse(m[iso ? 1 : 3]!);
      if (year < 100) year += year >= 50 ? 2500 : 2000;
      final date = _validDate(day, month, year);
      if (date != null) return date;
    }
    const months = [
      ['มค', 'มกราคม', 'jan', 'january'],
      ['กพ', 'กุมภาพันธ์', 'feb', 'february'],
      ['มีค', 'มีนาคม', 'mar', 'march'],
      ['เมย', 'เมษายน', 'apr', 'april'],
      ['พค', 'พฤษภาคม', 'may'],
      ['มิย', 'มิถุนายน', 'jun', 'june'],
      ['กค', 'กรกฎาคม', 'jul', 'july'],
      ['สค', 'สิงหาคม', 'aug', 'august'],
      ['กย', 'กันยายน', 'sep', 'sept', 'september'],
      ['ตค', 'ตุลาคม', 'oct', 'october'],
      ['พย', 'พฤศจิกายน', 'nov', 'november'],
      ['ธค', 'ธันวาคม', 'dec', 'december'],
    ];
    final compact = _normalize(text.replaceAll('.', '')).toLowerCase();
    final names = months.expand((m) => m).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
        '(?<!\\d)(\\d{1,2})\\s*(${names.join('|')})\\s*(พศ|คศ)?\\s*(\\d{4}|\\d{2})(?!\\d)');
    for (final m in pattern.allMatches(compact)) {
      final month = months.indexWhere((names) => names.contains(m[2])) + 1;
      var year = int.parse(m[4]!);
      if (year < 100) {
        final buddhist =
            m[3] == 'พศ' || (m[3] != 'คศ' && RegExp(r'[ก-๙]').hasMatch(m[2]!));
        year += buddhist ? 2500 : 2000;
      }
      final date = _validDate(int.parse(m[1]!), month, year);
      if (date != null) return date;
    }
    return null;
  }
}
