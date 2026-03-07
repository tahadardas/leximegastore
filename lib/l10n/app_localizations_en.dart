// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTitle => 'Home';

  @override
  String get homeCategoriesTooltip => 'Categories';

  @override
  String get homeErrorTitle => 'Failed to load home page. Please try again.';

  @override
  String get homeEmptyStateTitle => 'No active sections available currently';

  @override
  String get homeHeaderTitle => 'Discover carefully selected products in every category';

  @override
  String get actionViewAll => 'View All';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionShare => 'Share';

  @override
  String productAddedToCart(String productName) {
    return '$productName added to cart';
  }

  @override
  String get currencySymbol => 'SYP';

  @override
  String get appProfileTitle => 'Profile';

  @override
  String get appWishlistTitle => 'Wishlist Store';

  @override
  String get appPaymentTitle => 'Payment';

  @override
  String get appCheckoutTitle => 'Checkout';

  @override
  String get appMyOrdersTitle => 'My Orders';

  @override
  String get loginWelcomeTitle => 'Welcome to Lexi Mega Store';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get loginBiometric => 'Sign in with biometrics';

  @override
  String get loginWithPasswordOption => 'Or sign in with password';

  @override
  String get loginEmailOrUsername => 'Email or username';

  @override
  String get loginPassword => 'Password';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginCreateAccount => 'Create new account';

  @override
  String get loginContinueAsGuest => 'Continue as guest';

  @override
  String get loginSuccess => 'Signed in successfully';

  @override
  String get loginPasswordFirst => 'Please sign in with password first.';

  @override
  String get loginBiometricUnavailable => 'Biometric authentication is unavailable on this device.';

  @override
  String get loginBiometricFailed => 'Biometric authentication failed. Please try again.';

  @override
  String get loginSessionExpired => 'Session expired. Please sign in with password.';

  @override
  String get loginFailedGeneric => 'Unable to sign in. Please try again.';

  @override
  String get registerAppBarTitle => 'Create Account';

  @override
  String get registerSectionTitle => 'Registration Details';

  @override
  String get registerCreateAccount => 'Create Account';

  @override
  String get registerHaveAccount => 'Already have an account? Sign in';

  @override
  String registerWelcomeMessage(Object name) {
    return '$name, your account has been created successfully.';
  }

  @override
  String get registerUseCurrentLocation => 'Use current location';

  @override
  String get registerAddressAutoFilled => 'Address filled from your current location.';

  @override
  String get registerAddressFetchFailed => 'Failed to fetch address from location.';

  @override
  String get registerFailedGeneric => 'Unable to create account. Please try again.';

  @override
  String get checkoutPrev => 'Previous';

  @override
  String get checkoutNext => 'Next';

  @override
  String get checkoutConfirmOrder => 'Confirm Order';

  @override
  String get checkoutLoadCartFailed => 'Unable to load cart.';

  @override
  String get checkoutCartEmpty => 'Cart is empty. Add products first.';

  @override
  String get checkoutGoToCart => 'Go to cart';

  @override
  String get checkoutLeaveTitle => 'Leave checkout page?';

  @override
  String get checkoutLeaveBody => 'You have unsaved data. Return to cart?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get checkoutLeaveAction => 'Leave';

  @override
  String get ordersLoadFailed => 'Unable to load orders right now. Please try again.';

  @override
  String get ordersEmptyTitle => 'No orders yet';

  @override
  String get ordersEmptyDesc => 'Your orders will appear here once you complete checkout.';

  @override
  String get ordersStartShopping => 'Start shopping';

  @override
  String ordersNumberPrefix(Object number) {
    return 'Order #$number';
  }

  @override
  String ordersTotalLabel(Object total) {
    return 'Total: $total';
  }

  @override
  String ordersItemsCountLabel(Object count) {
    return 'Items: $count';
  }

  @override
  String get wishlistLoadFailed => 'Unable to load wishlist';

  @override
  String get wishlistEmptyTitle => 'Wishlist is empty';

  @override
  String get wishlistBrowseProducts => 'Browse products';

  @override
  String get profileActionsTitle => 'Account Actions';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSupportTooltip => 'Support';

  @override
  String get homeCategoriesTitle => 'Categories';

  @override
  String get homeCategoriesLoadFailed => 'Unable to load categories right now.';

  @override
  String get homeNoProductsNow => 'No products available currently.';

  @override
  String get homeNoActiveCategories => 'No active categories currently.';

  @override
  String get homeSearchHint => 'Search for products...';

  @override
  String get paymentInfoIntro => 'Payment method is selected during checkout.';

  @override
  String get paymentInfoSteps => 'Go back to cart then tap \"Checkout\" to continue.';

  @override
  String get paymentGoToCart => 'Go to cart';
}
