import '../env/app_environment.dart';

/// Lexi API Plugin Endpoints
///
/// All paths are relative to [baseUrl] so Dio resolves them with
/// `baseUrl + path`. No WooCommerce keys are stored in the app.
abstract class Endpoints {
  /// Domain-only base URL used by Dio's [BaseOptions.baseUrl].
  static String get baseUrl => AppEnvironment.baseUrl;

  /// Products endpoint path.
  static const productsPath = '/wp-json/lexi/v1/products';

  /// Categories endpoint path.
  static const categoriesPath = '/wp-json/lexi/v1/categories';

  /// WordPress REST root.
  static const wpJson = '/wp-json';

  /// Lexi plugin namespace.
  static const lexiV1 = '$wpJson/lexi/v1';

  /// JWT auth namespace (JWT Authentication for WP REST API).
  static const authV1 = '$wpJson/jwt-auth/v1';

  // Auth (JWT)
  static String jwtToken() => '$authV1/token';
  static String jwtValidate() => '$authV1/token/validate';
  static String customerAuthLogin() => '$lexiV1/auth/login';
  static String customerAuthRegister() => '$lexiV1/auth/register';
  static String customerAuthRefresh() => '$lexiV1/auth/refresh';
  static String customerAuthLogout() => '$lexiV1/auth/logout';
  static String customerAuthMe() => '$lexiV1/auth/me';
  static String customerAuthProfile() => '$lexiV1/auth/profile';
  static String customerProfileUpdate() => '$lexiV1/profile/update';
  static String customerProfileAvatar() => '$lexiV1/profile/avatar';
  static String customerWishlist() => '$lexiV1/wishlist';
  static String customerWishlistToggle() => '$lexiV1/wishlist/toggle';

  // Password reset
  static String forgotPassword() => '$lexiV1/auth/forgot-password';
  static String resetPassword() => '$lexiV1/auth/reset-password';
  static String changePassword() => '$lexiV1/auth/change-password';

  // Products
  static String products() => productsPath;
  static String productById(String id) => '$lexiV1/products/$id';
  static String productReviews(String id) => '$lexiV1/products/$id/reviews';
  static String productSimilar(String id) => '$lexiV1/products/$id/similar';

  // Categories
  static String categories() => categoriesPath;
  static String categoryById(String id) => '$lexiV1/categories/$id';
  static String homeSections() => '$lexiV1/home/sections';
  static String homeAdBanners() => '$lexiV1/home/ad-banners';
  static String searchSuggestions() => '$lexiV1/search/suggestions';
  static String searchProducts() => '$lexiV1/search/products';
  static String searchSuggest() => '$lexiV1/search/suggest';
  static String search() => '$lexiV1/search';
  static String searchTrending() => '$lexiV1/search/trending';

  // Shipping
  static String shippingCities() => '$lexiV1/shipping/cities';
  static String shippingRate() => '$lexiV1/shipping/rate';

  // Checkout
  static String guestCheckout() => '$lexiV1/checkout/guest';
  static String checkoutCreateOrder() => '$lexiV1/checkout/create-order';

  // Payments
  static String shamCashConfig() => '$lexiV1/payment-settings';
  static String shamCashProofUpload() => '$lexiV1/payments/shamcash/proof';

  // Coupons
  static String couponsValidate() => '$lexiV1/coupons/validate';

  // Orders
  static String myOrders({int page = 1, int perPage = 20}) =>
      '$lexiV1/my-orders?page=$page&per_page=$perPage';
  static String myOrderDetails(int orderId) => '$lexiV1/my-orders/$orderId';
  static String trackOrder() => '$lexiV1/track-order';
  static String confirmOrderReceived(int orderId) =>
      '$lexiV1/my-orders/$orderId/confirm-received';
  static String refuseOrder(int orderId) => '$lexiV1/my-orders/$orderId/refuse';
  static String invoice(String orderId) => '$lexiV1/orders/$orderId/invoice';
  static String invoiceRender() => '$lexiV1/invoices/render';
  static String invoiceVerify() => '$lexiV1/invoices/verify';

  // Admin
  static String adminDashboard() => '$lexiV1/admin/dashboard';
  static String adminOrders() => '$lexiV1/admin/orders';
  static String adminOrder(int id) => '$lexiV1/admin/orders/$id';
  static String adminOrderNotify(int id) => '$lexiV1/admin/orders/$id/notify';
  static String adminOrderAssignCourier(int id) =>
      '$lexiV1/admin/orders/$id/assign-courier';
  static String adminCouriers() => '$lexiV1/admin/couriers';
  static String adminCourierLocation(int courierId) =>
      '$lexiV1/admin/couriers/$courierId/location';
  static String adminCourierSettle(int courierId) =>
      '$lexiV1/admin/couriers/$courierId/settle';
  static String adminCouriersReport() => '$lexiV1/admin/couriers/report';
  static String adminShippingCities() => '$lexiV1/admin/shipping/cities';
  static String adminShippingCity(int id) =>
      '$lexiV1/admin/shipping/cities/$id';

  // Admin: Coupons
  static String adminCoupons() => '$lexiV1/admin/coupons';
  static String adminCoupon(int id) => '$lexiV1/admin/coupons/$id';

  static String adminNotificationSettings() =>
      '$lexiV1/admin/notification-settings';
  static String adminEmailDiagnostics() => '$lexiV1/admin/email-diagnostics';
  static String adminNotificationFirebaseSettings() =>
      '$lexiV1/admin/notifications/firebase-settings';
  static String adminNotificationCampaigns() =>
      '$lexiV1/admin/notifications/campaigns';
  static String adminMe() => '$lexiV1/admin/me';
  static String adminShamCashPending() => '$lexiV1/admin/shamcash/pending';
  static String adminShamCashOrder(int id) =>
      '$lexiV1/admin/shamcash/orders/$id';
  static String adminMerchCategories() => '$lexiV1/admin/merch/categories';
  static String adminMerchCategoryProducts() =>
      '$lexiV1/admin/merch/category-products';
  static String adminMerchCategoryProductsBulk() =>
      '$lexiV1/admin/merch/category-products/bulk';
  static String adminMerchHomeSections() => '$lexiV1/admin/merch/home-sections';
  static String adminMerchHomeSection(int id) =>
      '$lexiV1/admin/merch/home-sections/$id';
  static String adminMerchHomeSectionsReorder() =>
      '$lexiV1/admin/merch/home-sections/reorder';
  static String adminMerchHomeSectionItems(int id) =>
      '$lexiV1/admin/merch/home-sections/$id/items';
  static String adminMerchAdBanners() => '$lexiV1/admin/merch/ad-banners';

  static String adminMerchDeals() => '$lexiV1/admin/merch/deals';
  static String adminMerchDealsSchedule() =>
      '$lexiV1/admin/merch/deals/schedule';
  static String adminMerchReviews() => '$lexiV1/admin/merch/reviews';
  static String adminMerchReview(int id) => '$lexiV1/admin/merch/reviews/$id';
  static String adminIntelOverview() => '$lexiV1/admin/intel/overview';
  static String adminIntelTrendingProducts() =>
      '$lexiV1/admin/intel/trending-products';
  static String adminIntelOpportunities() =>
      '$lexiV1/admin/intel/opportunities';
  static String adminIntelWishlistTop() => '$lexiV1/admin/intel/wishlist-top';
  static String adminIntelSearch() => '$lexiV1/admin/intel/search';
  static String adminIntelBundles() => '$lexiV1/admin/intel/bundles';
  static String adminIntelStockAlerts() => '$lexiV1/admin/intel/stock-alerts';
  static String adminIntelCreateOfferDraft() =>
      '$lexiV1/admin/intel/actions/create-offer-draft';
  static String adminIntelPinHome() => '$lexiV1/admin/intel/actions/pin-home';

  // Analytics Events
  static String eventsTrack() => '$lexiV1/events/track';

  // Support - Customer
  static String supportMyTickets() => '$lexiV1/support/my-tickets';
  static String supportTickets() => '$lexiV1/support/tickets';
  static String supportTicket(int ticketId) =>
      '$lexiV1/support/tickets/$ticketId';
  static String supportTicketMessages(int ticketId) =>
      '$lexiV1/support/tickets/$ticketId/messages';
  static String supportTicketAttachments(int ticketId) =>
      '$lexiV1/support/tickets/$ticketId/attachments';
  static String supportTicketClose(int ticketId) =>
      '$lexiV1/support/tickets/$ticketId/close';
  static String supportTicketPoll(int ticketId) =>
      '$lexiV1/support/tickets/$ticketId/poll';

  // Support - Admin
  static String adminSupportTickets() => '$lexiV1/admin/support/tickets';
  static String adminSupportTicket(int ticketId) =>
      '$lexiV1/admin/support/tickets/$ticketId';
  static String adminSupportTicketReply(int ticketId) =>
      '$lexiV1/admin/support/tickets/$ticketId/reply';
  static String adminSupportTicketNote(int ticketId) =>
      '$lexiV1/admin/support/tickets/$ticketId/note';
  static String adminSupportTicketAssign(int ticketId) =>
      '$lexiV1/admin/support/tickets/$ticketId/assign';
  static String adminSupportCanned() => '$lexiV1/admin/support/canned';
  static String adminSupportAnalytics() => '$lexiV1/admin/support/analytics';

  // Notifications
  static String notifications() => '$lexiV1/notifications';
  static String notificationsMarkRead() => '$lexiV1/notifications/mark-read';
  static String notificationsMarkAllRead() =>
      '$lexiV1/notifications/mark-all-read';
  static String notificationsUnreadCount() =>
      '$lexiV1/notifications/unread-count';
  static String notificationsRegisterToken() =>
      '$lexiV1/notifications/register-token';
  static String devicesRegister() => '$lexiV1/devices/register';

  // Delivery agent
  static String deliveryMe() => '$lexiV1/delivery/me';
  static String deliveryAvailability() => '$lexiV1/delivery/availability';
  static String deliveryOrders() => '$lexiV1/delivery/orders';
  static String deliveryOrder(int id) => '$lexiV1/delivery/orders/$id';
  static String deliveryOrderStatus(int id) =>
      '$lexiV1/delivery/orders/$id/status';
  static String deliveryOrderCollectCod(int id) =>
      '$lexiV1/delivery/orders/$id/collect-cod';
  static String courierAssignmentAccept(int orderId) =>
      '$lexiV1/courier/assignments/$orderId/accept';
  static String courierAssignmentDecline(int orderId) =>
      '$lexiV1/courier/assignments/$orderId/decline';
  static String courierAssignmentCancel(int orderId) =>
      '$lexiV1/courier/assignments/$orderId/cancel';
  static String courierLocationPing() => '$lexiV1/courier/location';

  // Admin Order Decision
  static String adminOrderDecision(int orderId) =>
      '$lexiV1/admin/orders/$orderId/decision';

  // Order Device Attachment (for guest orders)
  static String orderAttachDevice(int orderId) =>
      '$lexiV1/orders/$orderId/attach-device';

  // AI Core - Tracking
  static String aiTrack() => '$lexiV1/ai/track';

  // AI Core - Recommendations
  static String aiForYou({int limit = 20}) =>
      '$lexiV1/ai/reco/for-you?limit=$limit';
  static String aiSimilar(int productId, {int limit = 12}) =>
      '$lexiV1/ai/reco/similar?product_id=$productId&limit=$limit';
  static String aiTrending({String range = '24h', int limit = 20}) =>
      '$lexiV1/ai/reco/trending?range=$range&limit=$limit';
  static String aiBundles(int productId, {int limit = 10}) =>
      '$lexiV1/ai/reco/bundles?product_id=$productId&limit=$limit';

  static String adminSendNotification() => '$lexiV1/admin/notifications/send';
  static String adminNotifyUser() => '$lexiV1/admin/notify/user';
  static String adminNotifyCourier() => '$lexiV1/admin/notify/courier';
  static String adminNotifyOrder() => '$lexiV1/admin/notify/order';
}
