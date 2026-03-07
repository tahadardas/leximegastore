import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Title of the Home Page
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// Tooltip for the categories icon in the app bar
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategoriesTooltip;

  /// Error message when home page fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load home page. Please try again.'**
  String get homeErrorTitle;

  /// Text displayed when there are no home sections
  ///
  /// In en, this message translates to:
  /// **'No active sections available currently'**
  String get homeEmptyStateTitle;

  /// Header text on the home page banner
  ///
  /// In en, this message translates to:
  /// **'Discover carefully selected products in every category'**
  String get homeHeaderTitle;

  /// Button text to view all items in a section
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get actionViewAll;

  /// Button text to add a product to cart
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// Tooltip for share button
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// Message shown when a product is added to cart
  ///
  /// In en, this message translates to:
  /// **'{productName} added to cart'**
  String productAddedToCart(String productName);

  /// Currency symbol appended to prices
  ///
  /// In en, this message translates to:
  /// **'SYP'**
  String get currencySymbol;

  /// No description provided for @appProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get appProfileTitle;

  /// No description provided for @appWishlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Wishlist Store'**
  String get appWishlistTitle;

  /// No description provided for @appPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get appPaymentTitle;

  /// No description provided for @appCheckoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get appCheckoutTitle;

  /// No description provided for @appMyOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get appMyOrdersTitle;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Lexi Mega Store'**
  String get loginWelcomeTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// No description provided for @loginBiometric.
  ///
  /// In en, this message translates to:
  /// **'Sign in with biometrics'**
  String get loginBiometric;

  /// No description provided for @loginWithPasswordOption.
  ///
  /// In en, this message translates to:
  /// **'Or sign in with password'**
  String get loginWithPasswordOption;

  /// No description provided for @loginEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get loginEmailOrUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get loginCreateAccount;

  /// No description provided for @loginContinueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get loginContinueAsGuest;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get loginSuccess;

  /// No description provided for @loginPasswordFirst.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with password first.'**
  String get loginPasswordFirst;

  /// No description provided for @loginBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is unavailable on this device.'**
  String get loginBiometricUnavailable;

  /// No description provided for @loginBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed. Please try again.'**
  String get loginBiometricFailed;

  /// No description provided for @loginSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in with password.'**
  String get loginSessionExpired;

  /// No description provided for @loginFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Please try again.'**
  String get loginFailedGeneric;

  /// No description provided for @registerAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerAppBarTitle;

  /// No description provided for @registerSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration Details'**
  String get registerSectionTitle;

  /// No description provided for @registerCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerCreateAccount;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get registerHaveAccount;

  /// No description provided for @registerWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'{name}, your account has been created successfully.'**
  String registerWelcomeMessage(Object name);

  /// No description provided for @registerUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get registerUseCurrentLocation;

  /// No description provided for @registerAddressAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Address filled from your current location.'**
  String get registerAddressAutoFilled;

  /// No description provided for @registerAddressFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch address from location.'**
  String get registerAddressFetchFailed;

  /// No description provided for @registerFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Unable to create account. Please try again.'**
  String get registerFailedGeneric;

  /// No description provided for @checkoutPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get checkoutPrev;

  /// No description provided for @checkoutNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get checkoutNext;

  /// No description provided for @checkoutConfirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get checkoutConfirmOrder;

  /// No description provided for @checkoutLoadCartFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load cart.'**
  String get checkoutLoadCartFailed;

  /// No description provided for @checkoutCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty. Add products first.'**
  String get checkoutCartEmpty;

  /// No description provided for @checkoutGoToCart.
  ///
  /// In en, this message translates to:
  /// **'Go to cart'**
  String get checkoutGoToCart;

  /// No description provided for @checkoutLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave checkout page?'**
  String get checkoutLeaveTitle;

  /// No description provided for @checkoutLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved data. Return to cart?'**
  String get checkoutLeaveBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @checkoutLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get checkoutLeaveAction;

  /// No description provided for @ordersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load orders right now. Please try again.'**
  String get ordersLoadFailed;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Your orders will appear here once you complete checkout.'**
  String get ordersEmptyDesc;

  /// No description provided for @ordersStartShopping.
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get ordersStartShopping;

  /// No description provided for @ordersNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String ordersNumberPrefix(Object number);

  /// No description provided for @ordersTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {total}'**
  String ordersTotalLabel(Object total);

  /// No description provided for @ordersItemsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Items: {count}'**
  String ordersItemsCountLabel(Object count);

  /// No description provided for @wishlistLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load wishlist'**
  String get wishlistLoadFailed;

  /// No description provided for @wishlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Wishlist is empty'**
  String get wishlistEmptyTitle;

  /// No description provided for @wishlistBrowseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse products'**
  String get wishlistBrowseProducts;

  /// No description provided for @profileActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get profileActionsTitle;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsTitle;

  /// No description provided for @profileSupportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupportTooltip;

  /// No description provided for @homeCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategoriesTitle;

  /// No description provided for @homeCategoriesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load categories right now.'**
  String get homeCategoriesLoadFailed;

  /// No description provided for @homeNoProductsNow.
  ///
  /// In en, this message translates to:
  /// **'No products available currently.'**
  String get homeNoProductsNow;

  /// No description provided for @homeNoActiveCategories.
  ///
  /// In en, this message translates to:
  /// **'No active categories currently.'**
  String get homeNoActiveCategories;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for products...'**
  String get homeSearchHint;

  /// No description provided for @paymentInfoIntro.
  ///
  /// In en, this message translates to:
  /// **'Payment method is selected during checkout.'**
  String get paymentInfoIntro;

  /// No description provided for @paymentInfoSteps.
  ///
  /// In en, this message translates to:
  /// **'Go back to cart then tap \"Checkout\" to continue.'**
  String get paymentInfoSteps;

  /// No description provided for @paymentGoToCart.
  ///
  /// In en, this message translates to:
  /// **'Go to cart'**
  String get paymentGoToCart;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
