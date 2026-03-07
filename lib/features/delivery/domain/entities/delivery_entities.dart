import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../orders/domain/entities/order.dart';

class DeliveryCodInfo {
  final bool isCod;
  final String expectedAmount;
  final String currency;
  final String collectedStatus;
  final String? collectedAmount;
  final bool locked;

  const DeliveryCodInfo({
    required this.isCod,
    required this.expectedAmount,
    required this.currency,
    required this.collectedStatus,
    required this.collectedAmount,
    required this.locked,
  });

  DeliveryCodInfo copyWith({
    bool? isCod,
    String? expectedAmount,
    String? currency,
    String? collectedStatus,
    String? collectedAmount,
    bool? locked,
  }) {
    return DeliveryCodInfo(
      isCod: isCod ?? this.isCod,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      currency: currency ?? this.currency,
      collectedStatus: collectedStatus ?? this.collectedStatus,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      locked: locked ?? this.locked,
    );
  }

  factory DeliveryCodInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryCodInfo(
      isCod: parseBool(json['is_cod']),
      expectedAmount: (json['expected_amount'] ?? '').toString(),
      currency: (json['currency'] ?? '').toString(),
      collectedStatus: (json['collected_status'] ?? 'pending').toString(),
      collectedAmount:
          (json['collected_amount'] ?? '').toString().trim().isEmpty
          ? null
          : (json['collected_amount'] ?? '').toString(),
      locked: parseBool(json['locked']),
    );
  }
}

class DeliveryAgentProfile {
  final int id;
  final String displayName;
  final String email;
  final bool isAvailable;

  const DeliveryAgentProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isAvailable,
  });

  factory DeliveryAgentProfile.fromJson(Map<String, dynamic> json) {
    return DeliveryAgentProfile(
      id: parseInt(json['id']),
      displayName: TextNormalizer.normalize(json['display_name']),
      email: TextNormalizer.normalize(json['email']),
      isAvailable: parseBool(json['is_available']),
    );
  }
}

class DeliveryOrderCard {
  final int id;
  final String orderNumber;
  final String status;
  final String deliveryState;
  final double total;
  final DeliveryCodInfo? cod;
  final String customerName;
  final String customerPhone;
  final String address;
  final String mapsNavigateUrl;
  final String mapsOpenUrl;
  final String date;
  final Order fullOrder;

  const DeliveryOrderCard({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryState,
    required this.total,
    required this.cod,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.mapsNavigateUrl,
    required this.mapsOpenUrl,
    required this.date,
    required this.fullOrder,
  });

  DeliveryOrderCard copyWith({
    int? id,
    String? orderNumber,
    String? status,
    String? deliveryState,
    double? total,
    DeliveryCodInfo? cod,
    String? customerName,
    String? customerPhone,
    String? address,
    String? mapsNavigateUrl,
    String? mapsOpenUrl,
    String? date,
    Order? fullOrder,
  }) {
    return DeliveryOrderCard(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      deliveryState: deliveryState ?? this.deliveryState,
      total: total ?? this.total,
      cod: cod ?? this.cod,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      address: address ?? this.address,
      mapsNavigateUrl: mapsNavigateUrl ?? this.mapsNavigateUrl,
      mapsOpenUrl: mapsOpenUrl ?? this.mapsOpenUrl,
      date: date ?? this.date,
      fullOrder: fullOrder ?? this.fullOrder,
    );
  }

  factory DeliveryOrderCard.fromJson(Map<String, dynamic> json) {
    final billingRaw = json['billing'];
    final billing = billingRaw is Map<String, dynamic>
        ? billingRaw
        : billingRaw is Map
        ? billingRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final deliveryRaw = json['delivery_location'];
    final deliveryLocation = deliveryRaw is Map<String, dynamic>
        ? deliveryRaw
        : deliveryRaw is Map
        ? deliveryRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final assignmentRaw = json['delivery_assignment'];
    final assignment = assignmentRaw is Map<String, dynamic>
        ? assignmentRaw
        : assignmentRaw is Map
        ? assignmentRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final codRaw = json['cod'];
    final codMap = codRaw is Map<String, dynamic>
        ? codRaw
        : codRaw is Map
        ? codRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final cod = codMap.isEmpty ? null : DeliveryCodInfo.fromJson(codMap);

    final billingName = [
      TextNormalizer.normalize(billing['first_name']).trim(),
      TextNormalizer.normalize(billing['last_name']).trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    final fullAddress = TextNormalizer.normalize(
      deliveryLocation['full_address'],
    );
    final locationComposedAddress = [
      TextNormalizer.normalize(deliveryLocation['city']).trim(),
      TextNormalizer.normalize(deliveryLocation['area']).trim(),
      TextNormalizer.normalize(deliveryLocation['street']).trim(),
      TextNormalizer.normalize(deliveryLocation['building']).trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final fallbackAddress = [
      locationComposedAddress,
      TextNormalizer.normalize(billing['city']).trim(),
      TextNormalizer.normalize(billing['address_1']).trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final resolvedAddress = fullAddress.trim().isNotEmpty
        ? fullAddress
        : fallbackAddress;

    final lat = parseDoubleNullable(deliveryLocation['lat']);
    final lng = parseDoubleNullable(deliveryLocation['lng']);
    final resolvedMaps = _resolveMapsUrls(
      navigateUrl: (deliveryLocation['maps_navigate_url'] ?? '').toString(),
      openUrl: (deliveryLocation['maps_open_url'] ?? '').toString(),
      address: resolvedAddress,
      lat: lat,
      lng: lng,
    );

    return DeliveryOrderCard(
      id: parseInt(json['id']),
      orderNumber: TextNormalizer.normalize(json['order_number']),
      status: TextNormalizer.normalize(json['status']),
      deliveryState: TextNormalizer.normalize(assignment['delivery_state']),
      total: parseDouble(json['total']),
      cod: cod,
      customerName: billingName.isEmpty ? 'عميل' : billingName,
      customerPhone: TextNormalizer.normalize(billing['phone']),
      address: resolvedAddress,
      mapsNavigateUrl: resolvedMaps.navigateUrl,
      mapsOpenUrl: resolvedMaps.openUrl,
      date: TextNormalizer.normalize(json['date'] ?? json['date_created']),
      fullOrder: Order.fromJson(json),
    );
  }
}

class _ResolvedMapsUrls {
  final String navigateUrl;
  final String openUrl;

  const _ResolvedMapsUrls({required this.navigateUrl, required this.openUrl});
}

_ResolvedMapsUrls _resolveMapsUrls({
  required String navigateUrl,
  required String openUrl,
  required String address,
  required double? lat,
  required double? lng,
}) {
  var resolvedNavigate = navigateUrl.trim();
  var resolvedOpen = openUrl.trim();

  final destination = _resolveDestination(address: address, lat: lat, lng: lng);
  if (destination.isEmpty) {
    return _ResolvedMapsUrls(
      navigateUrl: resolvedNavigate,
      openUrl: resolvedOpen,
    );
  }

  if (resolvedOpen.isEmpty) {
    resolvedOpen = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': destination,
    }).toString();
  }
  if (resolvedNavigate.isEmpty) {
    resolvedNavigate = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    }).toString();
  }

  return _ResolvedMapsUrls(
    navigateUrl: resolvedNavigate,
    openUrl: resolvedOpen,
  );
}

String _resolveDestination({
  required String address,
  required double? lat,
  required double? lng,
}) {
  if (lat != null && lng != null) {
    return '${_formatCoordinate(lat)},${_formatCoordinate(lng)}';
  }
  return address.trim();
}

String _formatCoordinate(double value) {
  final fixed = value.toStringAsFixed(6);
  final withoutZeros = fixed.replaceAll(RegExp(r'0+$'), '');
  return withoutZeros.replaceAll(RegExp(r'\\.$'), '');
}

class DeliveryDashboardData {
  final DeliveryAgentProfile profile;
  final List<DeliveryOrderCard> orders;
  final int page;
  final int total;
  final int totalPages;
  final double totalCollectedToday;

  const DeliveryDashboardData({
    required this.profile,
    required this.orders,
    required this.page,
    required this.total,
    required this.totalPages,
    required this.totalCollectedToday,
  });
}
