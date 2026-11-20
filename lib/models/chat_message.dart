import 'package:flutter/foundation.dart';

/// Sender role inside the AI schedule parser chat.
enum ChatRole {
  user,
  assistant,
  system;

  static ChatRole fromString(String? raw) {
    return ChatRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ChatRole.assistant,
    );
  }
}

/// Message item shown in the AI Chat screen.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.createdTaskIds = const [],
    this.isError = false,
    this.providerName,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final List<String> createdTaskIds;
  final bool isError;
  final String? providerName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'createdTaskIds': createdTaskIds,
        'isError': isError,
        'providerName': providerName,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id']?.toString() ?? '',
        role: ChatRole.fromString(json['role']?.toString()),
        text: json['text']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        createdTaskIds: (json['createdTaskIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        isError: json['isError'] == true,
        providerName: json['providerName']?.toString(),
      );
}
