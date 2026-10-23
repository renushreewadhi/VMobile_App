import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

final helpdeskServiceProvider = Provider<HelpdeskService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return HelpdeskService(apiClient);
});

class HelpdeskService {
  final ApiClient _apiClient;

  HelpdeskService(this._apiClient);

  dynamic _unwrap(dynamic res) {
    if (res is Map<String, dynamic> && res.containsKey('data')) {
      return res['data'];
    }
    return res;
  }

  Future<dynamic> getDashboard() async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/dashboard');
    return _unwrap(res);
  }

  Future<dynamic> getRoleDashboard() async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/role-dashboard');
    return _unwrap(res);
  }

  Future<List<dynamic>> getTickets({String? status, String? category, String? department, String? priority}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (department != null && department.isNotEmpty) queryParams['department'] = department;
    if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;

    final res = await _apiClient.get(ApiEndpoints.helpdeskTickets, queryParams: queryParams.isNotEmpty ? queryParams : null);
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<List<dynamic>> getMyTickets() async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/my');
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<List<dynamic>> getTeamTickets() async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/team');
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<dynamic> getTicket(String id) async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/$id');
    return _unwrap(res);
  }

  Future<dynamic> createTicket(Map<String, dynamic> data) async {
    final res = await _apiClient.post(ApiEndpoints.helpdeskTickets, body: data);
    return _unwrap(res);
  }

  Future<dynamic> updateTicket(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.put('${ApiEndpoints.helpdeskTickets}/$id', body: data);
    return _unwrap(res);
  }

  Future<dynamic> assignTicket(String id, String assignedToId) async {
    final res = await _apiClient.post('${ApiEndpoints.helpdeskTickets}/$id/assign', body: {'assignedToId': assignedToId});
    return _unwrap(res);
  }

  Future<dynamic> escalateTicket(String id, String? reason) async {
    final res = await _apiClient.post('${ApiEndpoints.helpdeskTickets}/$id/escalate', body: {'reason': reason ?? ''});
    return _unwrap(res);
  }

  Future<dynamic> resolveTicket(String id, String? resolution) async {
    final res = await _apiClient.post('${ApiEndpoints.helpdeskTickets}/$id/resolve', body: {'resolution': resolution ?? ''});
    return _unwrap(res);
  }

  Future<dynamic> closeTicket(String id) async {
    final res = await _apiClient.post('${ApiEndpoints.helpdeskTickets}/$id/close', body: {});
    return _unwrap(res);
  }

  Future<dynamic> getTicketStats() async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/stats');
    return _unwrap(res);
  }

  Future<List<dynamic>> getComments(String ticketId) async {
    final res = await _apiClient.get('${ApiEndpoints.helpdeskTickets}/$ticketId/comments');
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<dynamic> addComment(String ticketId, Map<String, dynamic> data) async {
    final res = await _apiClient.post('${ApiEndpoints.helpdeskTickets}/$ticketId/comments', body: data);
    return _unwrap(res);
  }

  Future<List<dynamic>> getKnowledgeBaseArticles({String? category, String? search}) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final res = await _apiClient.get('/helpdesk/knowledge-base', queryParams: queryParams.isNotEmpty ? queryParams : null);
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<dynamic> getKnowledgeBaseArticle(String id) async {
    final res = await _apiClient.get('/helpdesk/knowledge-base/$id');
    return _unwrap(res);
  }

  Future<dynamic> createKnowledgeBaseArticle(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/helpdesk/knowledge-base', body: data);
    return _unwrap(res);
  }

  Future<dynamic> updateKnowledgeBaseArticle(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.put('/helpdesk/knowledge-base/$id', body: data);
    return _unwrap(res);
  }

  Future<bool> deleteKnowledgeBaseArticle(String id) async {
    await _apiClient.delete('/helpdesk/knowledge-base/$id');
    return true;
  }

  Future<dynamic> markArticleHelpful(String id) async {
    final res = await _apiClient.post('/helpdesk/knowledge-base/$id/helpful', body: {});
    return _unwrap(res);
  }

  Future<dynamic> chatbot(String message) async {
    final res = await _apiClient.post(ApiEndpoints.helpdeskChatbot, body: {'message': message});
    return _unwrap(res);
  }

  Future<List<dynamic>> getCategories({bool? isActive}) async {
    final queryParams = <String, String>{};
    if (isActive != null) queryParams['isActive'] = isActive.toString();
    final res = await _apiClient.get(ApiEndpoints.helpdeskCategories, queryParams: queryParams.isNotEmpty ? queryParams : null);
    final unwrapped = _unwrap(res);
    if (unwrapped is List) return unwrapped;
    return [];
  }

  Future<dynamic> createCategory(Map<String, dynamic> data) async {
    final res = await _apiClient.post(ApiEndpoints.helpdeskCategories, body: data);
    return _unwrap(res);
  }

  Future<dynamic> updateCategory(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.put('${ApiEndpoints.helpdeskCategories}/$id', body: data);
    return _unwrap(res);
  }

  Future<bool> deleteCategory(String id) async {
    await _apiClient.delete('${ApiEndpoints.helpdeskCategories}/$id');
    return true;
  }
}
