import 'package:flutter/foundation.dart';

/// User-defined task category with a custom display label and Material icon key.
@immutable
class CustomTaskType {
  const CustomTaskType({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String iconKey;

  CustomTaskType copyWith({
    String? id,
    String? name,
    String? iconKey,
  }) {
    return CustomTaskType(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
      };

  factory CustomTaskType.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final iconKey = json['iconKey']?.toString().trim() ?? 'label';
    return CustomTaskType(
      id: id.isEmpty ? name.toLowerCase().replaceAll(RegExp(r'\s+'), '_') : id,
      name: name.isEmpty ? 'Custom' : name,
      iconKey: iconKey.isEmpty ? 'label' : iconKey,
    );
  }
}
