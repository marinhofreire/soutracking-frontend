import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/finance_models.dart';

class FinanceApiService {
  const FinanceApiService({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  Map<String, String> get _headers => {
        'access_token': apiKey,
        'Content-Type': 'application/json',
      };

  Future<List<Map<String, dynamic>>> fetchAsaasCharges({
    String? status,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null && status.isNotEmpty) 'status': status,
      if (from != null) 'dueDateGe': _dateStr(from),
      if (to != null) 'dueDateLe': _dateStr(to),
    };
    final uri = Uri.parse('$baseUrl/payments').replace(queryParameters: params);
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    _checkStatus(resp, '/payments');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  Future<Map<String, dynamic>> fetchBalance() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/finance/balance'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    _checkStatus(resp, '/finance/balance');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchPaymentStatistics({
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{
      if (from != null) 'dateCreatedGe': _dateStr(from),
      if (to != null) 'dateCreatedLe': _dateStr(to),
    };
    final uri = Uri.parse('$baseUrl/finance/payment/statistics')
        .replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    _checkStatus(resp, '/finance/payment/statistics');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptions({
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/subscriptions')
        .replace(queryParameters: {'limit': '$limit'});
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    _checkStatus(resp, '/subscriptions');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  Future<List<Map<String, dynamic>>> fetchAsaasCustomers({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/customers')
        .replace(queryParameters: {'limit': '$limit'});
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    _checkStatus(resp, '/customers');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  Future<List<Map<String, dynamic>>> fetchPaymentLinks() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/paymentLinks'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    _checkStatus(resp, '/paymentLinks');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  Future<List<Map<String, dynamic>>> fetchPaymentWebhooks() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/webhooks'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    _checkStatus(resp, '/webhooks');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  Future<FinanceKpiSummary> fetchKpiSummary() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    final stats = await fetchPaymentStatistics(from: firstOfMonth, to: now);

    double asDouble(String key) =>
        (stats[key] as num?)?.toDouble() ?? 0;

    return FinanceKpiSummary(
      monthRevenue: asDouble('invoicedValueInMonth'),
      received:     asDouble('receivedInMonth'),
      openAmount:   asDouble('pendingValueInMonth'),
      delinquency:  asDouble('overdueValueInMonth'),
    );
  }

  static void _checkStatus(http.Response resp, String path) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Asaas $path ${resp.statusCode}: ${resp.body}');
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
