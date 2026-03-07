# تقرير صيانة شامل - 2026-03-01

## النتيجة التنفيذية
- تم تنفيذ خطة الصيانة على مراحل بالأولوية المطلوبة: الأمان ثم الترميز ثم الاستقرار والتصميم.
- تم إغلاق المخاطر الحرجة في Flutter/Android وWordPress API مع الحفاظ على التوافق العام للمسارات.
- حالة التحقق النهائي:
  - `flutter analyze`: **No issues found**
  - `flutter test`: **All tests passed (24/24)**
  - `dart run scripts/design_token_lint.dart`: **Pass** (مع hints تحسين غير حاجبة)

## مقارنة خط الأساس مقابل الحالة النهائية
- خط الأساس (قبل الإصلاح):
  - `flutter analyze`: تحذير سلوكي (`use_build_context_synchronously`)
  - `flutter test`: فشل في اختبار forced logout ضمن `AppLockService`
  - `design_token_lint`: نجاح مع ملاحظات hardcoded
- بعد الصيانة:
  - `flutter analyze`: بدون مشاكل
  - `flutter test`: كل الاختبارات ناجحة (24/24)
  - `design_token_lint`: نجاح مع ملاحظات تحسين تصميمية غير حرجة

## ما تم إنجازه حسب المراحل

### 1) خط الأساس والتوثيق
- إنشاء تقرير baseline في:
  - `docs/MAINTENANCE_BASELINE_2026-03-01.md`

### 2) الأمان الحرج (Flutter + Android)
- تقييد تجاوز TLS غير الآمن ليكون debug-only اختياري عبر `--dart-define` في `lib/main.dart`.
- تشديد Android release:
  - تعطيل cleartext افتراضيًا في `android/app/src/main/AndroidManifest.xml`.
  - إزالة استثناءات cleartext في `android/app/src/main/res/xml/network_security_config.xml`.
- إضافة إعداد debug مخصص فقط لمضيفات التطوير المحلية:
  - `android/app/src/debug/AndroidManifest.xml`
  - `android/app/src/debug/res/xml/network_security_config_debug.xml`

### 3) الأمان الحرج (WordPress Plugin)
- قصر اعتراض `OPTIONS` على namespace `lexi/v1` فقط في `wp-content/plugins/lexi-api/lexi-api.php`.
- تشديد `attach-device`:
  - تحقق ملكية إلزامي (`attach_token` أو `phone`) + rate limit + logging abuse.
  - إبطال `attach_token` بعد الاستخدام.
  - الملفات: `class-routes-orders.php`, `class-routes-checkout.php`.
- إضافة `attach_token` قصير العمر في مخرجات checkout.
- تشديد `ai/track` لرفض الهوية الفارغة وتطبيق مفتاح rate-limit مركب في `class-ai-routes.php`.
- حذف `wp-content/plugins/lexi-api/test_cron.php` من الشيفرة الإنتاجية.
- تعزيز مسار fallback في `class-notification-hooks.php` لتفويض التنفيذ للمسار المشدد.

### 4) إصلاح الترميز العربي (Mojibake)
- تشغيل السكربت الشامل على `lib` و`wp-content/plugins/lexi-api` و`docs`.
- إصلاح يدوي في ملفات حرجة داخل الإضافة (public/delivery/orders routes).
- إعادة توليد الترجمة عبر `flutter gen-l10n`.

### 5) الترجمة والواجهة النصية
- تفعيل delegates/locales المولدة في `lib/app/app.dart`.
- إضافة وتوسيع مفاتيح في:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_ar.arb`
- ترحيل نصوص أساسية لشاشات حرجة (wishlist, payment, my-orders, login/register, checkout, profile, home) مع بقاء عناصر ثانوية تحتاج cleanup إضافي.

### 6) الاستقرار والاختبارات
- توحيد منطق التصعيد في `AppLockService` ليصل forced logout عند 10 محاولات فاشلة بشكل متسق.
- إصلاح `use_build_context_synchronously` في `sham_cash_payment_page.dart`.
- النتيجة: اختبارات الأمان والسلوك مستقرة، وكل الاختبارات الحالية ناجحة.

### 7) التصميم واتساق النظام البصري
- اعتماد خط `Amiri` رسميًا:
  - تسجيل الخط في `pubspec.yaml`
  - تحويل `LexiTypography.fontFamily` إلى `Amiri`
  - إزالة `Cairo` hardcoded من `navigation_shell.dart`
- توحيد ألوان hardcoded عالية التأثير إلى tokens في:
  - `home_page.dart`
  - `product_page.dart`
  - `product_card.dart`
  - `order_status_page.dart`
- تحسين responsive grids:
  - تحويل الأعمدة الثابتة إلى delegates ديناميكية حسب العرض في `home_page.dart` (منتجات + تصنيفات).

### 8) التحقق النهائي
- تمت إعادة تشغيل الفحوصات بنجاح:
  - `flutter analyze` أخضر
  - `flutter test` أخضر (24/24)
  - `design_token_lint` أخضر

## التغييرات التعاقدية (API Contracts)
1. `POST /wp-json/lexi/v1/orders/{id}/attach-device`
   - يتطلب إثبات ملكية (`attach_token` أو `phone`) مع rate-limit أقوى.
2. مخرجات checkout تضيف معلومات ربط جهاز آمنة (`attach_token` + expiry).
3. `POST /wp-json/lexi/v1/ai/track`
   - يرفض الطلب عند غياب الهوية (`device_id` و`session_id` فارغان).
   - rate-limit أكثر صرامة + تسجيل إساءة الاستخدام.
4. wishlist بقي متوافقًا خارجيًا مع استمرار التحسين الداخلي التدريجي.

## المخاطر/القيود المتبقية (غير حرجة)
- توجد بقايا نصوص/صياغات تحتاج تنظيف يدوي إضافي في بعض الشاشات المعقدة بعد إصلاح mojibake الشامل.
- `design_token_lint` ما يزال يعرض hints غير حاجبة لبعض hardcoded spacing/colors خارج نطاق الدفعة الحالية.
- في `class-notification-hooks.php` يوجد مسار legacy غير مستخدم عمليًا بعد التفويض المبكر؛ يُفضَّل تنظيفه في دفعة لاحقة.

## الخلاصة
- أهداف الأمان والاستقرار الأساسية أُغلقت بنجاح.
- التوافق العام محفوظ، مع تشديد فعلي على المسارات العامة الحساسة.
- جاهزية الإصدار أفضل بشكل واضح، مع قائمة تحسينات تجميلية/تنظيفية متبقية غير حرجة.
