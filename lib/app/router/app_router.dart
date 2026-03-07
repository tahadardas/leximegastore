import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'app_lock_guard.dart';
import '../../design_system/lexi_motion.dart';
import '../../core/auth/auth_session_controller.dart';
import '../../core/deeplink/share_links.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/session/app_session.dart';
import '../../features/auth/presentation/pages/unified_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/admin/presentation/pages/dashboard_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

// Shells
import '../../features/admin/presentation/shell/admin_shell.dart';
import '../shell/navigation_shell.dart';

// Features
import '../../features/cart/presentation/pages/cart_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/categories/presentation/pages/category_products_page.dart';
import '../../features/profile/presentation/pages/account_root_page.dart';
import '../../features/product/presentation/pages/product_page.dart';
import '../../features/product/presentation/pages/product_deep_link_resolver_page.dart';
import '../../features/product/presentation/pages/products_listing_page.dart';
import '../../features/checkout/presentation/pages/checkout_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/deals/presentation/pages/deals_page.dart';
import '../../features/payment/presentation/pages/payment_page.dart';
import '../../features/payment/presentation/pages/sham_cash_payment_page.dart';
import '../../features/orders/presentation/pages/invoice_viewer_page.dart';
import '../../features/orders/presentation/pages/order_details_page.dart';
import '../../features/orders/presentation/pages/order_status_page.dart';
import '../../features/orders/presentation/pages/track_order_page.dart';
import '../../features/orders/presentation/pages/pending_orders_page.dart';
import '../../features/orders/presentation/pages/pending_shamcash_orders_page.dart';
import '../../features/checkout/presentation/pages/order_success_page.dart';
import '../../features/admin/presentation/pages/orders_page.dart';
import '../../features/admin/presentation/pages/shipping_page.dart';
import '../../features/admin/presentation/pages/admin_notification_settings_page.dart';
import '../../features/admin/presentation/pages/admin_order_details_page.dart';
import '../../features/admin/presentation/pages/shamcash_verification_page.dart';
import '../../features/admin/merch/presentation/pages/admin_merch_categories_page.dart';
import '../../features/admin/merch/presentation/pages/admin_merch_category_products_page.dart';
import '../../features/admin/merch/presentation/pages/admin_home_sections_page.dart';
import '../../features/admin/merch/presentation/pages/admin_ad_banners_page.dart';
import '../../features/admin/merch/presentation/pages/admin_flash_deals_page.dart';
import '../../features/admin/merch/presentation/pages/admin_edit_flash_deal_page.dart';
import '../../features/admin/merch/presentation/pages/admin_reviews_page.dart';
import '../../features/admin/intel/presentation/pages/store_intelligence_page.dart';
import '../../features/admin/presentation/pages/admin_notification_sender_page.dart';

import '../../features/admin/domain/entities/admin_order.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/debug/presentation/pages/debug_api_page.dart';
import '../../features/profile/presentation/pages/profile_update_page.dart';
import '../../features/wishlist/presentation/pages/wishlist_page.dart';
import '../../features/support/presentation/pages/support_tickets_page.dart';
import '../../features/support/presentation/pages/support_ticket_chat_page.dart';
import '../../features/support/presentation/pages/create_ticket_page.dart';
import '../../features/admin/support_desk/presentation/pages/admin_support_inbox_page.dart';
import '../../features/admin/support_desk/presentation/pages/admin_support_ticket_page.dart';
import '../../features/admin/presentation/pages/admin_coupons_page.dart';
import '../../features/admin/presentation/pages/admin_courier_reports_page.dart';
import '../../features/search/search_results_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/delivery/presentation/pages/delivery_dashboard_page.dart';
import '../../features/delivery/presentation/pages/assignment_decision_screen.dart';
import '../../features/security/presentation/pages/app_lock_screen.dart';
import '../../features/security/presentation/pages/enable_app_lock_flow_page.dart';
import '../../features/security/presentation/pages/app_lock_reauth_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);
final _customerShellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'customerShellNavigator',
);
final _adminShellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminShellNavigator',
);

class _RouteBackGuard extends StatelessWidget {
  final String fallbackRouteName;
  final Widget child;

  const _RouteBackGuard({required this.fallbackRouteName, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        context.goNamedSafe(fallbackRouteName);
      },
      child: child,
    );
  }
}

CustomTransitionPage<void> _fadeSlidePage(
  GoRouterState state,
  Widget child, {
  String? fallbackRouteName,
  LocalKey? pageKey,
}) {
  return CustomTransitionPage<void>(
    key: pageKey ?? state.pageKey,
    transitionDuration: LexiMotion.base,
    reverseTransitionDuration: LexiMotion.base,
    child: fallbackRouteName == null
        ? child
        : _RouteBackGuard(fallbackRouteName: fallbackRouteName, child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) =>
        LexiMotion.fadeSlideTransition(animation: animation, child: pageChild),
  );
}

String? _sanitizeInternalNextPath(String? rawNext) {
  if (rawNext == null) {
    return null;
  }

  final trimmed = rawNext.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final decoded = Uri.decodeFull(trimmed);
  final parsed = Uri.tryParse(decoded) ?? Uri.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }

  if (parsed.scheme.isNotEmpty || parsed.host.isNotEmpty) {
    return null;
  }

  final path = parsed.path.trim();
  if (!path.startsWith('/')) {
    return null;
  }
  if (path == AppRoutePaths.login) {
    return null;
  }

  final queryPart = parsed.hasQuery ? '?${parsed.query}' : '';
  return '$path$queryPart';
}

String _loginLocationForNext(String nextPath) {
  final normalized = _sanitizeInternalNextPath(nextPath) ?? AppRoutePaths.home;
  return Uri(
    path: AppRoutePaths.login,
    queryParameters: {'next': normalized},
  ).toString();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authSession = ref.read(authSessionControllerProvider);
  final appLock = ref.read(appLockServiceProvider);
  final session = ref.read(appSessionProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutePaths.home,
    refreshListenable: Listenable.merge([authSession, appLock]),
    routes: [
      GoRoute(
        name: AppRouteNames.splash,
        path: AppRoutePaths.splash,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const SplashPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.login,
        path: AppRoutePaths.login,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const UnifiedLoginPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.register,
        path: AppRoutePaths.register,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const CustomerRegisterPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.forgotPassword,
        path: AppRoutePaths.forgotPassword,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const ForgotPasswordPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),

      // Security routes
      GoRoute(
        name: AppRouteNames.appLock,
        path: AppRoutePaths.appLock,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          AppLockScreen(nextPath: state.uri.queryParameters['next']),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.securityEnable,
        path: AppRoutePaths.securityEnable,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const EnableAppLockFlowPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.securityReauth,
        path: AppRoutePaths.securityReauth,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const AppLockReauthPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),

      // Keep old pinSetup route as alias → securityEnable (for backward compat)
      GoRoute(
        name: AppRouteNames.pinSetup,
        path: AppRoutePaths.pinSetup,
        redirect: (context, state) => AppRoutePaths.securityEnable,
      ),

      // Customer Shell
      ShellRoute(
        navigatorKey: _customerShellNavigatorKey,
        builder: (context, state, child) => NavigationShell(child: child),
        routes: [
          GoRoute(
            name: AppRouteNames.home,
            path: AppRoutePaths.home,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const HomePage()),
          ),
          GoRoute(
            name: AppRouteNames.cart,
            path: AppRoutePaths.cart,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const CartPage()),
          ),
          GoRoute(
            name: AppRouteNames.deals,
            path: AppRoutePaths.deals,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const DealsPage()),
          ),
          GoRoute(
            name: AppRouteNames.profile,
            path: AppRoutePaths.profile,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const AccountRootPage()),
          ),
          GoRoute(
            name: AppRouteNames.categories,
            path: AppRoutePaths.categories,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const CategoriesPage()),
          ),
          GoRoute(
            name: AppRouteNames.wishlist,
            path: AppRoutePaths.wishlist,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const WishlistPage()),
          ),
        ],
      ),

      // Admin Shell
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminShell(navigationShell: child),
        routes: [
          GoRoute(
            name: AppRouteNames.adminDashboard,
            path: AppRoutePaths.adminDashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminOrders,
            path: AppRoutePaths.adminOrders,
            builder: (context, state) => const AdminOrdersPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminShippingCities,
            path: AppRoutePaths.adminShippingCities,
            builder: (context, state) => const AdminShippingPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminNotificationSettings,
            path: AppRoutePaths.adminNotificationSettings,
            builder: (context, state) => const AdminNotificationSettingsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminShamCash,
            path: AppRoutePaths.adminShamCash,
            builder: (context, state) => const ShamCashVerificationPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchCategories,
            path: AppRoutePaths.adminMerchCategories,
            builder: (context, state) => const AdminMerchCategoriesPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchCategoryProducts,
            path: AppRoutePaths.adminMerchCategoryProducts,
            builder: (context, state) => const AdminMerchCategoryProductsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchHomeSections,
            path: AppRoutePaths.adminMerchHomeSections,
            builder: (context, state) => const AdminHomeSectionsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchAdBanners,
            path: AppRoutePaths.adminMerchAdBanners,
            builder: (context, state) => const AdminAdBannersPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchDeals,
            path: AppRoutePaths.adminMerchDeals,
            builder: (context, state) => const AdminFlashDealsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchDealsNew,
            path: AppRoutePaths.adminMerchDealsNew,
            builder: (context, state) => const AdminEditFlashDealPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminMerchReviews,
            path: AppRoutePaths.adminMerchReviews,
            builder: (context, state) => const AdminReviewsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminNotificationsSend,
            path: AppRoutePaths.adminNotificationsSend,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const AdminNotificationSenderPage()),
          ),
          GoRoute(
            name: AppRouteNames.adminCoupons,
            path: AppRoutePaths.adminCoupons,
            pageBuilder: (context, state) =>
                _fadeSlidePage(state, const AdminCouponsPage()),
          ),
          GoRoute(
            name: AppRouteNames.adminIntel,
            path: AppRoutePaths.adminIntel,
            builder: (context, state) => const StoreIntelligencePage(),
          ),
          GoRoute(
            name: AppRouteNames.adminSupport,
            path: AppRoutePaths.adminSupport,
            builder: (context, state) => const AdminSupportInboxPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminCourierReports,
            path: AppRoutePaths.adminCourierReports,
            builder: (context, state) => const AdminCourierReportsPage(),
          ),
          GoRoute(
            name: AppRouteNames.adminSupportTicket,
            path: AppRoutePaths.adminSupportTicketTemplate,
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return AdminSupportTicketPage(ticketId: id);
            },
          ),
          GoRoute(
            name: AppRouteNames.adminOrderDetails,
            path: AppRoutePaths.adminOrderDetailsTemplate,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! AdminOrder) return const AdminOrdersPage();
              return AdminOrderDetailsPage(order: extra);
            },
          ),
        ],
      ),

      GoRoute(
        name: AppRouteNames.deliveryDashboard,
        path: AppRoutePaths.deliveryDashboard,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const DeliveryDashboardPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.courierAssignmentDecision,
        path: AppRoutePaths.courierAssignmentDecision,
        pageBuilder: (context, state) {
          final orderId =
              int.tryParse(state.uri.queryParameters['order_id'] ?? '') ?? 0;
          final ttlSeconds =
              int.tryParse(state.uri.queryParameters['ttl_seconds'] ?? '') ??
              90;
          final receivedAtParam =
              (state.uri.queryParameters['received_at'] ?? '').trim();
          final receivedAt =
              DateTime.tryParse(receivedAtParam) ?? DateTime.now();

          return _fadeSlidePage(
            state,
            AssignmentDecisionScreen(
              orderId: orderId,
              amountDue: (state.uri.queryParameters['amount_due'] ?? '').trim(),
              customerName: (state.uri.queryParameters['customer_name'] ?? '')
                  .trim(),
              address: (state.uri.queryParameters['address'] ?? '').trim(),
              customerPhone: (state.uri.queryParameters['customer_phone'] ?? '')
                  .trim(),
              ttlSeconds: ttlSeconds > 0 ? ttlSeconds : 90,
              deepLink: (state.uri.queryParameters['deep_link'] ?? '').trim(),
              receivedAt: receivedAt,
              initialAction: (state.uri.queryParameters['action'] ?? '').trim(),
            ),
            fallbackRouteName: AppRouteNames.deliveryDashboard,
          );
        },
      ),

      // Standalone routes
      GoRoute(
        name: AppRouteNames.products,
        path: AppRoutePaths.products,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const ProductsListingPage(
            title: 'جميع المنتجات',
            filterType: ProductsListingFilterType.home,
            initialSort: 'newest',
          ),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.product,
        path: AppRoutePaths.productTemplate,
        pageBuilder: (context, state) {
          final productRef = (state.pathParameters['id'] ?? '').trim();
          final productId = int.tryParse(productRef);
          if (productId != null && productId > 0) {
            return _fadeSlidePage(
              state,
              ProductPage(
                productId: productId,
                heroTag: state.uri.queryParameters['hero_tag'],
              ),
              fallbackRouteName: AppRouteNames.home,
            );
          }

          return _fadeSlidePage(
            state,
            ProductDeepLinkResolverPage(
              productRef: productRef,
              queryParameters: state.uri.queryParameters,
            ),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.checkout,
        path: AppRoutePaths.checkout,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const CheckoutPage(),
          fallbackRouteName: AppRouteNames.cart,
        ),
      ),
      GoRoute(
        name: AppRouteNames.categoryProducts,
        path: AppRoutePaths.categoryProductsTemplate,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final title =
              (state.uri.queryParameters['title'] ?? '').trim().isEmpty
              ? 'منتجات التصنيف'
              : state.uri.queryParameters['title']!;
          final sort = (state.uri.queryParameters['sort'] ?? '').trim();
          final search = (state.uri.queryParameters['search'] ?? '').trim();
          return _fadeSlidePage(
            state,
            CategoryProductsPage(
              categoryId: id > 0 ? id : null,
              title: title,
              initialSort: sort.isEmpty ? 'manual' : sort,
              initialSearch: search,
            ),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.brandProducts,
        path: AppRoutePaths.brandProductsTemplate,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final brandName = (state.uri.queryParameters['brand'] ?? '').trim();
          final title =
              (state.uri.queryParameters['title'] ?? '').trim().isEmpty
              ? (brandName.isEmpty
                    ? 'منتجات العلامة التجارية'
                    : 'منتجات $brandName')
              : state.uri.queryParameters['title']!;
          final sort = (state.uri.queryParameters['sort'] ?? '').trim();
          final search = (state.uri.queryParameters['search'] ?? '').trim();
          return _fadeSlidePage(
            state,
            CategoryProductsPage(
              brandId: id > 0 ? id : null,
              brandName: brandName.isEmpty ? null : brandName,
              title: title,
              initialSort: sort.isEmpty ? 'manual' : sort,
              initialSearch: search,
            ),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.search,
        path: AppRoutePaths.search,
        pageBuilder: (context, state) {
          final initialQuery = (state.uri.queryParameters['q'] ?? '').trim();
          return _fadeSlidePage(
            state,
            SearchScreen(initialQuery: initialQuery),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.searchResults,
        path: AppRoutePaths.searchResults,
        pageBuilder: (context, state) {
          final initialQuery = (state.uri.queryParameters['q'] ?? '').trim();
          return _fadeSlidePage(
            state,
            SearchResultsScreen(initialQuery: initialQuery),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.payment,
        path: AppRoutePaths.payment,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const PaymentPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.orders,
        path: AppRoutePaths.orders,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const OrdersPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.trackOrder,
        path: AppRoutePaths.trackOrder,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const TrackOrderPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.notifications,
        path: AppRoutePaths.notifications,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const NotificationsPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.supportTickets,
        path: AppRoutePaths.supportTickets,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const SupportTicketsPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.supportCreate,
        path: AppRoutePaths.supportCreate,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const CreateTicketPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.supportTicketChat,
        path: AppRoutePaths.supportChatTemplate,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final token = (state.uri.queryParameters['token'] ?? '').trim();
          return _fadeSlidePage(
            state,
            SupportTicketChatPage(ticketId: id, token: token),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.shareEntry,
        path: AppRoutePaths.shareTemplate,
        redirect: (context, state) {
          final target = ShareLinks.fromPathParameters(
            type: state.pathParameters['type'],
            id: state.pathParameters['id'],
          );
          if (target == null) {
            return AppRoutePaths.home;
          }

          final inAppPath = ShareLinks.resolveInAppPath(target);
          if (inAppPath == null) {
            return AppRoutePaths.home;
          }

          if (!ShareLinks.requiresAuthType(target.type)) {
            return inAppPath;
          }

          final authStatus = authSession.state.status;
          if (authStatus == AuthSessionStatus.unknown) {
            return null;
          }

          if (authStatus != AuthSessionStatus.authenticated) {
            return _loginLocationForNext(inAppPath);
          }

          return inAppPath;
        },
      ),
      GoRoute(
        name: AppRouteNames.debugApi,
        path: AppRoutePaths.debugApi,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const DebugApiPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.orderInvoice,
        path: AppRoutePaths.orderInvoiceTemplate,
        pageBuilder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'final';
          final routePhone = (state.uri.queryParameters['phone'] ?? '').trim();
          final sessionPhone = (session.phone ?? '').trim();
          final phone = routePhone.isNotEmpty
              ? routePhone
              : (sessionPhone.isNotEmpty ? sessionPhone : null);
          final extra = state.extra;
          final initialOrder = extra is Order ? extra : null;
          return _fadeSlidePage(
            state,
            InvoiceViewerPage(
              orderId: state.pathParameters['id']!,
              type: type,
              phone: phone,
              initialOrder: initialOrder,
            ),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.orderSuccess,
        path: AppRoutePaths.orderSuccessTemplate,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          OrderSuccessPage(orderId: state.pathParameters['id']!),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.orderStatus,
        path: AppRoutePaths.ordersStatus,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          OrderStatusPage(
            orderNumber: state.uri.queryParameters['order_number'],
          ),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.pendingOrders,
        path: AppRoutePaths.ordersPending,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          PendingOrdersPage(orderId: state.uri.queryParameters['order_id']),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.pendingShamCash,
        path: AppRoutePaths.pendingShamCash,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const PendingShamCashOrdersPage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.orderDetails,
        path: AppRoutePaths.ordersDetails,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final order = extra is Order ? extra : null;
          final LocalKey resolvedKey = order == null
              ? state.pageKey
              : ValueKey<String>('order-details-${order.id}-${state.hashCode}');
          return _fadeSlidePage(
            state,
            order != null
                ? OrderDetailsPage(order: order)
                : const TrackOrderPage(),
            fallbackRouteName: AppRouteNames.home,
            pageKey: resolvedKey,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.orderDetailsById,
        path: AppRoutePaths.orderDetailsByIdTemplate,
        pageBuilder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _fadeSlidePage(
            state,
            OrderDetailsByIdPage(orderId: orderId),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
      GoRoute(
        name: AppRouteNames.profileUpdate,
        path: AppRoutePaths.profileUpdate,
        pageBuilder: (context, state) => _fadeSlidePage(
          state,
          const ProfileUpdatePage(),
          fallbackRouteName: AppRouteNames.home,
        ),
      ),
      GoRoute(
        name: AppRouteNames.shamCashPayment,
        path: AppRoutePaths.shamCashPayment,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) {
            return _fadeSlidePage(
              state,
              const PaymentPage(),
              fallbackRouteName: AppRouteNames.home,
            );
          }
          final args = extra;
          return _fadeSlidePage(
            state,
            ShamCashPaymentPage(
              orderId: args['orderId'],
              amount: args['amount'],
              currency: args['currency'],
              phone: args['phone'],
              accountName: args['accountName'],
              qrValue: args['qrValue'],
              barcodeValue: args['barcodeValue'],
              instructionsAr: args['instructionsAr'],
              uploadEndpoint: args['uploadEndpoint'],
            ),
            fallbackRouteName: AppRouteNames.home,
          );
        },
      ),
    ],

    redirect: (context, state) {
      // ------------------------------------------------------------------
      // 1. App Lock guard (checked first for all authenticated navigations)
      // ------------------------------------------------------------------
      final authState = authSession.state;
      if (authState.status == AuthSessionStatus.authenticated) {
        final lockRedirect = AppLockGuard.redirect(state, appLock);
        if (lockRedirect != null) return lockRedirect;
      }

      // ------------------------------------------------------------------
      // 2. Auth status redirects
      // ------------------------------------------------------------------
      final isLoggingIn = state.uri.path == AppRoutePaths.login;
      final isRegistering = state.uri.path == AppRoutePaths.register;
      final isSplash = state.uri.path == AppRoutePaths.splash;
      final isHome = state.uri.path == AppRoutePaths.home;
      final isProfileRoot = state.uri.path == AppRoutePaths.profile;
      final isAdminRoute = state.uri.path.startsWith('/admin');
      final isDeliveryRoute = state.uri.path.startsWith('/delivery');
      final isSecurityRoute = state.uri.path.startsWith('/security');
      final isShareEntry = state.uri.path.startsWith('/${ShareLinks.segment}/');

      if (authState.status == AuthSessionStatus.unknown) {
        return isHome ||
                isProfileRoot ||
                isLoggingIn ||
                isRegistering ||
                isSplash ||
                isShareEntry
            ? null
            : AppRoutePaths.home;
      }

      if (authState.status == AuthSessionStatus.unauthenticated) {
        if (isSplash) return AppRoutePaths.home;
        if (isAdminRoute || isDeliveryRoute) return AppRoutePaths.home;
        if (isSecurityRoute) return AppRoutePaths.home;
        if (state.uri.path == AppRoutePaths.profileUpdate) {
          return AppRoutePaths.profile;
        }
        if (state.uri.path == AppRoutePaths.orders) {
          return AppRoutePaths.ordersDetails;
        }
        return null;
      }

      if (authState.status == AuthSessionStatus.authenticated) {
        final role = (authState.role ?? session.role ?? '')
            .trim()
            .toLowerCase();
        final isDeliveryAgent =
            role == 'delivery_agent' || session.isDeliveryAgent;

        if (isDeliveryAgent) {
          if (isLoggingIn || isRegistering || isSplash || isProfileRoot) {
            return AppRoutePaths.deliveryDashboard;
          }
          if (isAdminRoute) return AppRoutePaths.deliveryDashboard;
        } else if (isDeliveryRoute && !isSecurityRoute) {
          return AppRoutePaths.home;
        }

        if (isLoggingIn || isRegistering || isSplash) {
          final nextPath = _sanitizeInternalNextPath(
            state.uri.queryParameters['next'],
          );
          if (nextPath != null) {
            return nextPath;
          }
          return AppRoutePaths.home;
        }

        if (isAdminRoute && !session.isAdmin) return AppRoutePaths.home;
      }

      return null;
    },
  );
});
