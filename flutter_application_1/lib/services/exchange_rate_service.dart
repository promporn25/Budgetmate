import 'dart:convert';
import 'dart:io';

class ExchangeQuote {
  final String base;
  final String quote;
  final double rate;
  final String date;
  const ExchangeQuote({required this.base, required this.quote, required this.rate, required this.date});
}

class ExchangeRateService {
  Future<ExchangeQuote> fetch(String base, String quote) async {
    if (base == quote) return ExchangeQuote(base: base, quote: quote, rate: 1,
      date: DateTime.now().toIso8601String().substring(0, 10));
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.https('api.frankfurter.dev', '/v2/rate/$base/$quote'))
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('Exchange rate unavailable (${response.statusCode})');
      final raw = jsonDecode(await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15))) as Map<String, dynamic>;
      final rate = (raw['rate'] as num).toDouble();
      final date = raw['date'] as String;
      if (raw['base'] != base || raw['quote'] != quote || !rate.isFinite || rate <= 0 || DateTime.tryParse(date) == null) {
        throw const FormatException('Invalid exchange rate');
      }
      return ExchangeQuote(base: base, quote: quote, rate: rate, date: date);
    } finally {
      client.close(force: true);
    }
  }
}
