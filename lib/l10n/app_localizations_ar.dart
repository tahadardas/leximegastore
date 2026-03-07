// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get homeCategoriesTooltip => 'الأقسام';

  @override
  String get homeErrorTitle => 'تعذر تحميل الصفحة الرئيسية. حاول مرة أخرى.';

  @override
  String get homeEmptyStateTitle => 'لا توجد أقسام نشطة حالياً';

  @override
  String get homeHeaderTitle => 'اكتشف ترتيب المنتجات المختارة بعناية في كل قسم';

  @override
  String get actionViewAll => 'عرض الكل';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionShare => 'مشاركة';

  @override
  String productAddedToCart(String productName) {
    return 'تمت إضافة $productName إلى السلة';
  }

  @override
  String get currencySymbol => 'ل.س';

  @override
  String get appProfileTitle => 'حسابي';

  @override
  String get appWishlistTitle => 'المتجر المفضل';

  @override
  String get appPaymentTitle => 'الدفع';

  @override
  String get appCheckoutTitle => 'إتمام الطلب';

  @override
  String get appMyOrdersTitle => 'طلباتي';

  @override
  String get loginWelcomeTitle => 'مرحباً بك في Lexi Mega Store';

  @override
  String get loginSubtitle => 'سجل الدخول للمتابعة';

  @override
  String get loginBiometric => 'الدخول بالبصمة';

  @override
  String get loginWithPasswordOption => 'أو سجل الدخول بكلمة المرور';

  @override
  String get loginEmailOrUsername => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get loginCreateAccount => 'إنشاء حساب جديد';

  @override
  String get loginContinueAsGuest => 'متابعة كضيف';

  @override
  String get loginSuccess => 'تم تسجيل الدخول بنجاح';

  @override
  String get loginPasswordFirst => 'يرجى تسجيل الدخول بكلمة المرور أولاً.';

  @override
  String get loginBiometricUnavailable => 'البصمة غير متاحة على هذا الجهاز.';

  @override
  String get loginBiometricFailed => 'تعذر التحقق بالبصمة. حاول مرة أخرى.';

  @override
  String get loginSessionExpired => 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول بكلمة المرور.';

  @override
  String get loginFailedGeneric => 'تعذر تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get registerAppBarTitle => 'إنشاء حساب جديد';

  @override
  String get registerSectionTitle => 'بيانات التسجيل';

  @override
  String get registerCreateAccount => 'إنشاء الحساب';

  @override
  String get registerHaveAccount => 'لديك حساب بالفعل؟ تسجيل الدخول';

  @override
  String registerWelcomeMessage(Object name) {
    return 'مرحباً $name، تم إنشاء الحساب بنجاح.';
  }

  @override
  String get registerUseCurrentLocation => 'استخدام موقعي الحالي';

  @override
  String get registerAddressAutoFilled => 'تم تعبئة العنوان من موقعك الحالي.';

  @override
  String get registerAddressFetchFailed => 'تعذر جلب العنوان من الموقع.';

  @override
  String get registerFailedGeneric => 'تعذر إنشاء الحساب. حاول مرة أخرى.';

  @override
  String get checkoutPrev => 'السابق';

  @override
  String get checkoutNext => 'التالي';

  @override
  String get checkoutConfirmOrder => 'تأكيد الطلب';

  @override
  String get checkoutLoadCartFailed => 'تعذر تحميل السلة.';

  @override
  String get checkoutCartEmpty => 'السلة فارغة. أضف منتجات أولاً.';

  @override
  String get checkoutGoToCart => 'الذهاب للسلة';

  @override
  String get checkoutLeaveTitle => 'مغادرة صفحة إتمام الطلب؟';

  @override
  String get checkoutLeaveBody => 'لديك بيانات غير محفوظة. هل تريد العودة إلى السلة؟';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get checkoutLeaveAction => 'مغادرة';

  @override
  String get ordersLoadFailed => 'تعذر تحميل الطلبات حالياً. حاول مرة أخرى.';

  @override
  String get ordersEmptyTitle => 'لا توجد طلبات بعد';

  @override
  String get ordersEmptyDesc => 'عند إتمام أول طلب سيظهر هنا مع الحالة والتفاصيل.';

  @override
  String get ordersStartShopping => 'ابدأ التسوق';

  @override
  String ordersNumberPrefix(Object number) {
    return 'طلب #$number';
  }

  @override
  String ordersTotalLabel(Object total) {
    return 'الإجمالي: $total';
  }

  @override
  String ordersItemsCountLabel(Object count) {
    return 'عدد المنتجات: $count';
  }

  @override
  String get wishlistLoadFailed => 'تعذر تحميل المفضلة';

  @override
  String get wishlistEmptyTitle => 'قائمة المفضلة فارغة';

  @override
  String get wishlistBrowseProducts => 'تصفح المنتجات';

  @override
  String get profileActionsTitle => 'إجراءات الحساب';

  @override
  String get profileSettingsTitle => 'الإعدادات';

  @override
  String get profileSupportTooltip => 'الدعم';

  @override
  String get homeCategoriesTitle => 'التصنيفات';

  @override
  String get homeCategoriesLoadFailed => 'تعذر تحميل التصنيفات حالياً.';

  @override
  String get homeNoProductsNow => 'لا توجد منتجات حالياً.';

  @override
  String get homeNoActiveCategories => 'لا توجد فئات نشطة حالياً.';

  @override
  String get homeSearchHint => 'ابحث عن المنتجات...';

  @override
  String get paymentInfoIntro => 'اختيار وسيلة الدفع يتم أثناء إتمام الطلب.';

  @override
  String get paymentInfoSteps => 'عد إلى السلة ثم اضغط \"إتمام الطلب\" للمتابعة.';

  @override
  String get paymentGoToCart => 'الذهاب إلى السلة';
}
