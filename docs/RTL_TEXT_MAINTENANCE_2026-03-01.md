# تقرير صيانة RTL والنصوص - 2026-03-01

## ما تم تنفيذه
- فرض العربية كواجهة افتراضية في التطبيق:
  - `locale: const Locale('ar')`
  - تغليف الجذر بـ `Directionality(textDirection: TextDirection.rtl)`
  - تحديث عنوان التطبيق للعربية.
- تحويل الهوامش غير الاتجاهية في المسارات الحرجة (Home/Search/Cart) إلى اتجاهية (`EdgeInsetsDirectional.fromSTEB`) لضمان انعكاس RTL الصحيح.
- تنظيف شامل للنصوص المشوهة (mojibake) داخل التطبيق والإضافة.
- تعريب نصوص واجهة البحث بالكامل (العناوين، التلميحات، رسائل الخطأ، أزرار إعادة المحاولة، خيارات الفرز/التصفية).
- تعريب رسائل واجهة الصفحة الرئيسية وسلة التسوق التي كانت بالإنجليزية.

## الملفات الأساسية التي تم تعديلها
- `lib/app/app.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/home/presentation/widgets/home_skeletons.dart`
- `lib/features/search/search_screen.dart`
- `lib/features/search/search_results_screen.dart`
- `lib/features/cart/presentation/pages/cart_page.dart`
- `wp-content/plugins/lexi-api/includes/class-text.php`
- `wp-content/plugins/lexi-api/includes/class-routes-orders.php`

## التحقق
- فحص النصوص المشوهة: لا توجد أنماط mojibake متبقية في `lib` و`wp-content/plugins/lexi-api` و`docs`.
- `flutter analyze`: ناجح بدون مشاكل.
- `flutter test`: جميع الاختبارات ناجحة.
