import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const Duration _navigationDuplicateWindow = Duration(milliseconds: 500);
String? _lastNavigationLocation;
DateTime? _lastNavigationAt;

bool _isRapidDuplicateNavigation(String location) {
  final lastLocation = _lastNavigationLocation;
  final lastAt = _lastNavigationAt;
  if (lastLocation == null || lastAt == null) {
    return false;
  }
  if (lastLocation != location) {
    return false;
  }
  return DateTime.now().difference(lastAt) <= _navigationDuplicateWindow;
}

void _markNavigation(String location) {
  _lastNavigationLocation = location;
  _lastNavigationAt = DateTime.now();
}

class AppRoutePaths {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const appLock = '/security/lock';
  static const pinSetup = '/security/pin/setup';
  static const securityEnable = '/security/enable';
  static const securityReauth = '/security/reauth';

  static const home = '/';
  static const products = '/products';
  static const cart = '/cart';
  static const deals = '/deals';
  static const profile = '/profile';
  static const categories = '/categories';
  static const wishlist = '/wishlist';
  static const checkout = '/checkout';
  static const payment = '/payment';
  static const orders = '/orders';
  static const trackOrder = '/track-order';
  static const notifications = '/notifications';
  static const debugApi = '/debug-api';
  static const profileUpdate = '/profile/update';

  static const productTemplate = '/product/:id';
  static String product(int productId) => '/product/$productId';

  static const categoryProductsTemplate = '/categories/:id/products';
  static String categoryProducts(int categoryId) =>
      '/categories/$categoryId/products';

  static const brandProductsTemplate = '/brands/:id/products';
  static String brandProducts(int brandId) => '/brands/$brandId/products';
  static String brandProductsWithTitle(int brandId, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return brandProducts(brandId);
    }
    return Uri(
      path: brandProducts(brandId),
      queryParameters: {'title': trimmed},
    ).toString();
  }

  static String brandProductsFromCard({
    required String brandName,
    int? brandId,
  }) {
    final normalizedBrand = brandName.trim();
    final normalizedId = (brandId ?? 0) > 0 ? brandId! : 0;
    if (normalizedBrand.isEmpty) {
      return brandProducts(normalizedId);
    }
    return Uri(
      path: brandProducts(normalizedId),
      queryParameters: {'title': normalizedBrand, 'brand': normalizedBrand},
    ).toString();
  }

  static const search = '/search';
  static const searchResults = '/search/results';

  static const supportTickets = '/support/tickets';
  static const supportCreate = '/support/create';
  static const supportChatTemplate = '/support/tickets/:id/chat';
  static String supportChat(int ticketId) => '/support/tickets/$ticketId/chat';

  static const shareTemplate = '/s/:type/:id';
  static String share(String type, String id) => '/s/$type/$id';

  static const orderInvoiceTemplate = '/orders/:id/invoice';
  static String orderInvoice(String orderId) => '/orders/$orderId/invoice';
  static const orderDetailsByIdTemplate = '/orders/:id';
  static String orderDetailsById(String orderId) => '/orders/$orderId';

  static const orderSuccessTemplate = '/order-success/:id';
  static String orderSuccess(String orderId) => '/order-success/$orderId';

  static const ordersStatus = '/orders/status';
  static const ordersPending = '/orders/pending';
  static const ordersDetails = '/orders/details';
  static const pendingShamCash = '/orders/incomplete-shamcash';
  static const shamCashPayment = '/payment/sham-cash';

  static const adminDashboard = '/admin/dashboard';
  static const adminOrders = '/admin/orders';
  static const adminShippingCities = '/admin/shipping/cities';
  static const adminNotificationSettings = '/admin/notification-settings';
  static const adminShamCash = '/admin/shamcash';
  static const adminMerchCategories = '/admin/merch/categories';
  static const adminMerchCategoryProducts = '/admin/merch/category-products';
  static const adminMerchHomeSections = '/admin/merch/home-sections';
  static const adminMerchAdBanners = '/admin/merch/ad-banners';
  static const adminMerchDeals = '/admin/merch/deals';
  static const adminMerchDealsNew = '/admin/merch/deals/new';
  static const adminMerchReviews = '/admin/merch/reviews';
  static const adminNotificationsSend = '/admin/notifications/send';
  static const adminCoupons = '/admin/coupons';
  static const adminIntel = '/admin/intel';
  static const adminSupport = '/admin/support';
  static const adminCourierReports = '/admin/couriers/reports';
  static const adminSupportTicketTemplate = '/admin/support/:id';
  static String adminSupportTicket(int ticketId) => '/admin/support/$ticketId';
  static const adminOrderDetailsTemplate = '/admin/orders/:id';
  static const deliveryDashboard = '/delivery/dashboard';
  static const courierAssignmentDecision = '/delivery/assignment-decision';

  static String courierAssignmentDecisionPath({
    required int orderId,
    String amountDue = '',
    String customerName = '',
    String address = '',
    String customerPhone = '',
    int ttlSeconds = 90,
    String deepLink = '',
    String action = '',
    String receivedAt = '',
  }) {
    final query = <String, String>{
      'order_id': '$orderId',
      if (amountDue.trim().isNotEmpty) 'amount_due': amountDue.trim(),
      if (customerName.trim().isNotEmpty) 'customer_name': customerName.trim(),
      if (address.trim().isNotEmpty) 'address': address.trim(),
      if (customerPhone.trim().isNotEmpty)
        'customer_phone': customerPhone.trim(),
      'ttl_seconds': '$ttlSeconds',
      if (deepLink.trim().isNotEmpty) 'deep_link': deepLink.trim(),
      if (action.trim().isNotEmpty) 'action': action.trim(),
      if (receivedAt.trim().isNotEmpty) 'received_at': receivedAt.trim(),
    };

    return Uri(
      path: courierAssignmentDecision,
      queryParameters: query,
    ).toString();
  }
}

class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const register = 'register';
  static const forgotPassword = 'forgotPassword';
  static const appLock = 'appLock';
  static const pinSetup = 'pinSetup';
  static const securityEnable = 'securityEnable';
  static const securityReauth = 'securityReauth';

  static const home = 'home';
  static const products = 'products';
  static const cart = 'cart';
  static const deals = 'deals';
  static const profile = 'profile';
  static const categories = 'categories';
  static const wishlist = 'wishlist';

  static const adminDashboard = 'adminDashboard';
  static const adminOrders = 'adminOrders';
  static const adminShippingCities = 'adminShippingCities';
  static const adminNotificationSettings = 'adminNotificationSettings';
  static const adminShamCash = 'adminShamCash';
  static const adminMerchCategories = 'adminMerchCategories';
  static const adminMerchCategoryProducts = 'adminMerchCategoryProducts';
  static const adminMerchHomeSections = 'adminMerchHomeSections';
  static const adminMerchAdBanners = 'adminMerchAdBanners';
  static const adminMerchDeals = 'adminMerchDeals';
  static const adminMerchDealsNew = 'adminMerchDealsNew';
  static const adminMerchReviews = 'adminMerchReviews';
  static const adminNotificationsSend = 'adminNotificationsSend';
  static const adminCoupons = 'adminCoupons';
  static const adminIntel = 'adminIntel';
  static const adminSupport = 'adminSupport';
  static const adminCourierReports = 'adminCourierReports';
  static const adminSupportTicket = 'adminSupportTicket';
  static const adminOrderDetails = 'adminOrderDetails';
  static const deliveryDashboard = 'deliveryDashboard';
  static const courierAssignmentDecision = 'courierAssignmentDecision';

  static const product = 'product';
  static const checkout = 'checkout';
  static const categoryProducts = 'categoryProducts';
  static const brandProducts = 'brandProducts';
  static const search = 'search';
  static const searchResults = 'searchResults';
  static const payment = 'payment';
  static const orders = 'orders';
  static const trackOrder = 'trackOrder';
  static const notifications = 'notifications';
  static const supportTickets = 'supportTickets';
  static const supportCreate = 'supportCreate';
  static const supportTicketChat = 'supportTicketChat';
  static const shareEntry = 'shareEntry';
  static const debugApi = 'debugApi';
  static const orderInvoice = 'orderInvoice';
  static const orderDetailsById = 'orderDetailsById';
  static const orderSuccess = 'orderSuccess';
  static const orderStatus = 'orderStatus';
  static const pendingOrders = 'pendingOrders';
  static const pendingShamCash = 'pendingShamCash';
  static const orderDetails = 'orderDetails';
  static const profileUpdate = 'profileUpdate';
  static const shamCashPayment = 'shamCashPayment';
}

extension AppNavigationX on BuildContext {
  Uri get currentUri => GoRouterState.of(this).uri;

  bool isCurrentLocation(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return currentUri.path == path &&
        mapEquals(currentUri.queryParameters, queryParameters);
  }

  String namedLocationSafe(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return GoRouter.of(this).namedLocation(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  void goNamedSafe(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
  }) {
    final location = namedLocationSafe(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
    final targetUri = Uri.parse(location);

    if (currentUri.path == targetUri.path &&
        mapEquals(currentUri.queryParameters, targetUri.queryParameters)) {
      return;
    }

    if (_isRapidDuplicateNavigation(location)) {
      return;
    }
    _markNavigation(location);

    if (extra != null) {
      GoRouter.of(this).go(location, extra: extra);
      return;
    }
    GoRouter.of(this).go(location);
  }

  Future<T?> pushNamedIfNotCurrent<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
  }) {
    final location = namedLocationSafe(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
    final targetUri = Uri.parse(location);

    if (currentUri.path == targetUri.path &&
        mapEquals(currentUri.queryParameters, targetUri.queryParameters)) {
      return Future<T?>.value(null);
    }

    if (_isRapidDuplicateNavigation(location)) {
      return Future<T?>.value(null);
    }
    _markNavigation(location);

    return GoRouter.of(this).push<T>(location, extra: extra);
  }
}
