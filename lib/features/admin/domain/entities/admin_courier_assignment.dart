import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';

class AdminCourier {
  final int id;
  final String displayName;
  final String email;
  final String phone;
  final bool isAvailable;
  final int activeOrdersCount;

  const AdminCourier({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.isAvailable,
    required this.activeOrdersCount,
  });

  factory AdminCourier.fromJson(Map<String, dynamic> json) {
    return AdminCourier(
      id: parseInt(json['id']),
      displayName: TextNormalizer.normalize(json['display_name']),
      email: TextNormalizer.normalize(json['email']),
      phone: TextNormalizer.normalize(json['phone']),
      isAvailable: parseBool(json['is_available']),
      activeOrdersCount: parseInt(json['active_orders_count']),
    );
  }
}

class AdminOrderCourierAssignment {
  final int? agentId;
  final AdminCourier? agent;
  final String assignedAt;
  final String deliveryState;

  const AdminOrderCourierAssignment({
    required this.agentId,
    required this.agent,
    required this.assignedAt,
    required this.deliveryState,
  });

  bool get isAssigned => agentId != null && agentId! > 0;

  factory AdminOrderCourierAssignment.fromJson(Map<String, dynamic> json) {
    final agentRaw = json['agent'];
    final agent = agentRaw is Map<String, dynamic>
        ? AdminCourier.fromJson(agentRaw)
        : agentRaw is Map
        ? AdminCourier.fromJson(
            agentRaw.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;

    final parsedAgentId = parseInt(json['agent_id']);
    return AdminOrderCourierAssignment(
      agentId: parsedAgentId > 0 ? parsedAgentId : null,
      agent: agent,
      assignedAt: TextNormalizer.normalize(json['assigned_at']),
      deliveryState: TextNormalizer.normalize(json['delivery_state']),
    );
  }
}
