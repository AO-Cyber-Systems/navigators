import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:eden_platform_flutter/eden_platform.dart';

// --- Models ---

class SMSMessage {
  final String id;
  final String voterId;
  final String userId;
  final String direction;
  final String messageType;
  final String body;
  final String status;
  final String createdAt;
  final String fromNumber;
  final String toNumber;

  const SMSMessage({
    required this.id,
    required this.voterId,
    required this.userId,
    required this.direction,
    required this.messageType,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.fromNumber,
    required this.toNumber,
  });

  factory SMSMessage.fromJson(Map<String, dynamic> json) {
    return SMSMessage(
      id: json['id'] as String? ?? '',
      voterId: json['voterId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      direction: json['direction'] as String? ?? '',
      messageType: json['messageType'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      fromNumber: json['fromNumber'] as String? ?? '',
      toNumber: json['toNumber'] as String? ?? '',
    );
  }

  bool get isOutbound => direction == 'outbound';
  bool get isInbound => direction == 'inbound';
}

class ConversationSummary {
  final String voterId;
  final String voterName;
  final String lastMessageBody;
  final String lastMessageAt;

  const ConversationSummary({
    required this.voterId,
    required this.voterName,
    required this.lastMessageBody,
    required this.lastMessageAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      voterId: json['voterId'] as String? ?? '',
      voterName: json['voterName'] as String? ?? '',
      lastMessageBody: json['lastMessageBody'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] as String? ?? '',
    );
  }
}

class SMSTemplate {
  final String id;
  final String name;
  final String body;
  final List<String> mergeFields;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const SMSTemplate({
    required this.id,
    required this.name,
    required this.body,
    required this.mergeFields,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SMSTemplate.fromJson(Map<String, dynamic> json) {
    return SMSTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      mergeFields: (json['mergeFields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class SMSCampaign {
  final String id;
  final String name;
  final String templateId;
  final String segmentFilters;
  final String status;
  final int totalRecipients;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final String launchedAt;
  final String completedAt;
  final String createdAt;
  final String updatedAt;

  const SMSCampaign({
    required this.id,
    required this.name,
    required this.templateId,
    required this.segmentFilters,
    required this.status,
    required this.totalRecipients,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.launchedAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SMSCampaign.fromJson(Map<String, dynamic> json) {
    return SMSCampaign(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
      segmentFilters: json['segmentFilters'] as String? ?? '{}',
      status: json['status'] as String? ?? 'draft',
      totalRecipients: (json['totalRecipients'] as num?)?.toInt() ?? 0,
      sentCount: (json['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      launchedAt: json['launchedAt'] as String? ?? '',
      completedAt: json['completedAt'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSending => status == 'sending';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  double get progressPercent =>
      totalRecipients > 0 ? sentCount / totalRecipients : 0.0;
}

class SMSConfig {
  final String companyId;
  final String twilioAccountSid;
  final String p2pMessagingServiceSid;
  final String a2pMessagingServiceSid;
  final String inboundWebhookUrl;
  final String statusWebhookUrl;
  final int quietHoursStart;
  final int quietHoursEnd;
  final String tenDlcBrandSid;
  final String tenDlcCampaignSid;
  final String tenDlcStatus;

  const SMSConfig({
    required this.companyId,
    required this.twilioAccountSid,
    required this.p2pMessagingServiceSid,
    required this.a2pMessagingServiceSid,
    required this.inboundWebhookUrl,
    required this.statusWebhookUrl,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.tenDlcBrandSid,
    required this.tenDlcCampaignSid,
    required this.tenDlcStatus,
  });

  factory SMSConfig.fromJson(Map<String, dynamic> json) {
    return SMSConfig(
      companyId: json['companyId'] as String? ?? '',
      twilioAccountSid: json['twilioAccountSid'] as String? ?? '',
      p2pMessagingServiceSid: json['p2pMessagingServiceSid'] as String? ?? '',
      a2pMessagingServiceSid: json['a2pMessagingServiceSid'] as String? ?? '',
      inboundWebhookUrl: json['inboundWebhookUrl'] as String? ?? '',
      statusWebhookUrl: json['statusWebhookUrl'] as String? ?? '',
      quietHoursStart: (json['quietHoursStart'] as num?)?.toInt() ?? 0,
      quietHoursEnd: (json['quietHoursEnd'] as num?)?.toInt() ?? 0,
      tenDlcBrandSid: json['tenDlcBrandSid'] as String? ?? '',
      tenDlcCampaignSid: json['tenDlcCampaignSid'] as String? ?? '',
      tenDlcStatus: json['tenDlcStatus'] as String? ?? '',
    );
  }

  bool get is10DLCApproved => tenDlcStatus == 'approved';
}

// --- Service ---

class SMSService {
  final String _baseUrl;
  final String? Function() _getAccessToken;

  SMSService({
    required String baseUrl,
    required String? Function() getAccessToken,
  })  : _baseUrl = baseUrl,
        _getAccessToken = getAccessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_getAccessToken() != null)
          'Authorization': 'Bearer ${_getAccessToken()}',
      };

  Future<Map<String, dynamic>> _post(
      String method, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/navigators.v1.SMSService/$method');
    final response =
        await http.post(url, headers: _headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw Exception('$method failed: ${response.statusCode} ${response.body}');
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // --- P2P / Conversation RPCs ---

  Future<SMSMessage> sendP2PMessage(String voterId, String body) async {
    final result = await _post('SendP2PMessage', {
      'voterId': voterId,
      'body': body,
    });
    return SMSMessage.fromJson(
        result['message'] as Map<String, dynamic>? ?? {});
  }

  Future<({List<SMSMessage> messages, String nextPageToken})> getConversation(
    String voterId, {
    int pageSize = 50,
    String pageToken = '',
  }) async {
    final result = await _post('GetConversation', {
      'voterId': voterId,
      'pageSize': pageSize,
      if (pageToken.isNotEmpty) 'pageToken': pageToken,
    });
    final messages = (result['messages'] as List<dynamic>? ?? [])
        .map((m) => SMSMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    final nextToken = result['nextPageToken'] as String? ?? '';
    return (messages: messages, nextPageToken: nextToken);
  }

  Future<({List<ConversationSummary> conversations, String nextPageToken})>
      listConversations({
    int pageSize = 50,
    String pageToken = '',
  }) async {
    final result = await _post('ListConversations', {
      'pageSize': pageSize,
      if (pageToken.isNotEmpty) 'pageToken': pageToken,
    });
    final conversations = (result['conversations'] as List<dynamic>? ?? [])
        .map((c) => ConversationSummary.fromJson(c as Map<String, dynamic>))
        .toList();
    final nextToken = result['nextPageToken'] as String? ?? '';
    return (conversations: conversations, nextPageToken: nextToken);
  }

  // --- Template RPCs ---

  Future<SMSTemplate> createTemplate(
      String name, String body, List<String> mergeFields) async {
    final result = await _post('CreateTemplate', {
      'name': name,
      'body': body,
      'mergeFields': mergeFields,
    });
    return SMSTemplate.fromJson(
        result['template'] as Map<String, dynamic>? ?? {});
  }

  Future<List<SMSTemplate>> listTemplates() async {
    final result = await _post('ListTemplates', {});
    return (result['templates'] as List<dynamic>? ?? [])
        .map((t) => SMSTemplate.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<SMSTemplate> getTemplate(String templateId) async {
    final result = await _post('GetTemplate', {'templateId': templateId});
    return SMSTemplate.fromJson(
        result['template'] as Map<String, dynamic>? ?? {});
  }

  Future<void> updateTemplate(
      String templateId, String name, String body, List<String> mergeFields) async {
    await _post('UpdateTemplate', {
      'templateId': templateId,
      'name': name,
      'body': body,
      'mergeFields': mergeFields,
    });
  }

  Future<void> deleteTemplate(String templateId) async {
    await _post('DeleteTemplate', {'templateId': templateId});
  }

  Future<String> previewTemplate(String templateId) async {
    final result =
        await _post('PreviewTemplate', {'templateId': templateId});
    return result['renderedBody'] as String? ?? '';
  }

  // --- Campaign RPCs ---

  Future<SMSCampaign> createCampaign(
      String name, String templateId, String segmentFilters) async {
    final result = await _post('CreateCampaign', {
      'name': name,
      'templateId': templateId,
      'segmentFilters': segmentFilters,
    });
    return SMSCampaign.fromJson(
        result['campaign'] as Map<String, dynamic>? ?? {});
  }

  Future<void> launchCampaign(String campaignId) async {
    await _post('LaunchCampaign', {'campaignId': campaignId});
  }

  Future<void> pauseCampaign(String campaignId) async {
    await _post('PauseCampaign', {'campaignId': campaignId});
  }

  Future<void> cancelCampaign(String campaignId) async {
    await _post('CancelCampaign', {'campaignId': campaignId});
  }

  Future<SMSCampaign> getCampaign(String campaignId) async {
    final result = await _post('GetCampaign', {'campaignId': campaignId});
    return SMSCampaign.fromJson(
        result['campaign'] as Map<String, dynamic>? ?? {});
  }

  Future<({List<SMSCampaign> campaigns, String nextPageToken})> listCampaigns({
    int pageSize = 50,
    String pageToken = '',
  }) async {
    final result = await _post('ListCampaigns', {
      'pageSize': pageSize,
      if (pageToken.isNotEmpty) 'pageToken': pageToken,
    });
    final campaigns = (result['campaigns'] as List<dynamic>? ?? [])
        .map((c) => SMSCampaign.fromJson(c as Map<String, dynamic>))
        .toList();
    final nextToken = result['nextPageToken'] as String? ?? '';
    return (campaigns: campaigns, nextPageToken: nextToken);
  }

  // --- Config RPCs ---

  Future<SMSConfig> getSMSConfig() async {
    final result = await _post('GetSMSConfig', {});
    return SMSConfig.fromJson(
        result['config'] as Map<String, dynamic>? ?? {});
  }

  Future<void> updateSMSConfig({
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? p2pMessagingServiceSid,
    String? a2pMessagingServiceSid,
    String? inboundWebhookUrl,
    String? statusWebhookUrl,
    int? quietHoursStart,
    int? quietHoursEnd,
    String? tenDlcBrandSid,
    String? tenDlcCampaignSid,
    String? tenDlcStatus,
  }) async {
    await _post('UpdateSMSConfig', {
      if (twilioAccountSid != null) 'twilioAccountSid': twilioAccountSid,
      if (twilioAuthToken != null) 'twilioAuthToken': twilioAuthToken,
      if (p2pMessagingServiceSid != null)
        'p2pMessagingServiceSid': p2pMessagingServiceSid,
      if (a2pMessagingServiceSid != null)
        'a2pMessagingServiceSid': a2pMessagingServiceSid,
      if (inboundWebhookUrl != null) 'inboundWebhookUrl': inboundWebhookUrl,
      if (statusWebhookUrl != null) 'statusWebhookUrl': statusWebhookUrl,
      if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
      if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
      if (tenDlcBrandSid != null) 'tenDlcBrandSid': tenDlcBrandSid,
      if (tenDlcCampaignSid != null) 'tenDlcCampaignSid': tenDlcCampaignSid,
      if (tenDlcStatus != null) 'tenDlcStatus': tenDlcStatus,
    });
  }

  // --- 10DLC RPCs ---

  Future<({String status, String brandSid, String campaignSid})>
      get10DLCStatus() async {
    final result = await _post('Get10DLCStatus', {});
    return (
      status: result['status'] as String? ?? '',
      brandSid: result['brandSid'] as String? ?? '',
      campaignSid: result['campaignSid'] as String? ?? '',
    );
  }

  Future<String> update10DLCStatus(
      String brandSid, String campaignSid, String status) async {
    final result = await _post('Update10DLCStatus', {
      'brandSid': brandSid,
      'campaignSid': campaignSid,
      'status': status,
    });
    return result['status'] as String? ?? '';
  }
}

// --- Providers ---

final smsServiceProvider = Provider<SMSService>((ref) {
  final auth = ref.watch(authProvider);
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final baseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:8080';
  return SMSService(
    baseUrl: baseUrl,
    getAccessToken: () => auth.accessToken,
  );
});
