jQuery(document).ready(function ($) {
    if (typeof lexiAdminData === 'undefined') {
        $('.lexi-dashboard-wrapper').prepend('<div class="notice notice-error"><p>خطأ: لم يتم تحميل إعدادات لوحة التحكم بشكل صحيح.</p></div>');
        return;
    }

    const apiRoot = lexiAdminData.root.replace(/\/$/, '');
    const nonce = lexiAdminData.nonce;

    function formatCurrency(amount) {
        try {
            return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SYP' }).format(amount).replace('SYP', 'ل.س');
        } catch (e) {
            return amount + ' ل.س';
        }
    }

    function showToast(message, isError = false) {
        if (isError) {
            console.error('Lexi Dashboard Error:', message);
            alert('خطأ: ' + message);
        }
    }

    function fetchDashboardStats() {
        $.ajax({
            url: apiRoot + '/admin/dashboard',
            method: 'GET',
            beforeSend: function (xhr) { xhr.setRequestHeader('X-WP-Nonce', nonce); },
            success: function (response) {
                if (response.success) { // Fixed: was response.ok
                    const data = response.data;
                    $('#stat-today-sales').text(formatCurrency(data.today_sales));
                    $('#stat-today-orders').text(data.today_orders_count);
                    $('#stat-total-orders').text(data.total_orders_count);
                    $('#stat-pending-verification').text(data.pending_verification_count);
                    $('#stat-processing').text(data.processing_count);
                    const completed = (data.total_orders_count || 0) - (data.pending_verification_count || 0) - (data.processing_count || 0);
                    $('#stat-completed').text(Math.max(0, completed));
                }
            },
            error: function (xhr) {
                $('#stat-today-sales, #stat-today-orders, #stat-total-orders, #stat-pending-verification, #stat-processing, #stat-completed').text('!');
            }
        });
    }

    function fetchIntelOverview() {
        $.ajax({
            url: apiRoot + '/admin/intel/overview?range=today',
            method: 'GET',
            beforeSend: function (xhr) { xhr.setRequestHeader('X-WP-Nonce', nonce); },
            success: function (response) {
                if (response.success) { // Fixed: was response.ok
                    const data = response.data;
                    $('#stat-conversion-rate').text((data.conversion_rate || 0).toFixed(2) + '%');
                    $('#stat-avg-order').text(formatCurrency(data.avg_order_value || 0));
                    $('#stat-add-to-cart').text((data.add_to_cart_rate || 0).toFixed(2) + '%');
                    $('#stat-sessions').text(data.sessions || 0);
                }
            },
            error: function () {
                $('#stat-conversion-rate, #stat-avg-order, #stat-add-to-cart, #stat-sessions').text('!');
            }
        });
    }

    // Modal Control
    window.openLexiModal = function (title, content, actionsHtml = '') {
        $('#lexi-modal-title').text(title);
        $('#lexi-modal-body').html(content);
        if ($('#lexi-modal-actions').length === 0) {
            $('.lexi-modal-header').append('<div id="lexi-modal-actions" style="margin-right: 15px; display:flex; gap:10px;"></div>');
        }
        $('#lexi-modal-actions').html(actionsHtml);
        $('#lexi-modal-overlay').css('display', 'flex');
    };

    window.closeLexiModal = function () {
        $('#lexi-modal-overlay').hide();
    };

    // Quick Actions (using delegated events for better reliability)
    $(document).on('click', '#action-home-sections', function () { loadHomeSections(); });
    $(document).on('click', '#action-banners', function () { loadBanners(); });
    $(document).on('click', '#action-categories', function () { loadCategories(); });
    $(document).on('click', '#action-reviews', function () { loadReviews(); });
    $(document).on('click', '#action-notifications', function () {
        console.log('Lexi Dashboard: Push Notifications clicked.');
        loadNotificationsManager();
    });
    $(document).on('click', '#action-fcm-settings', function () { loadFcmSettings(); });

    function lexiAjax(options) {
        const defaults = {
            method: 'GET',
            beforeSend: function (xhr) { xhr.setRequestHeader('X-WP-Nonce', nonce); },
            error: function (xhr) {
                const msg = xhr.responseJSON ? xhr.responseJSON.message : 'فشل الاتصال بالخادم.';
                $('#lexi-modal-body').html('<div style="padding:40px; text-align:center; color:var(--lexi-error);">' + msg + '</div>');
            }
        };
        return $.ajax($.extend({}, defaults, options));
    }

    // --- Push Notifications Manager ---
    function loadNotificationsManager() {
        const sendBtn = '<button class="button button-primary" onclick="openSendNotificationForm()">إرسال إشعار جديد</button>';
        openLexiModal('إدارة إشعارات الدفع', '<div class="lexi-loading">جارِ التحميل...</div>', sendBtn);

        lexiAjax({
            url: apiRoot + '/admin/notifications/campaigns',
            success: function (response) {
                if (response.success) {
                    let html = '<div style="margin-bottom:20px;"><h3 style="color:#fff;">سجل الحملات الأخيرة</h3>';
                    html += '<table class="wp-list-table widefat fixed striped lexi-modal-table">';
                    html += '<thead><tr><th>العنوان</th><th>الهدف</th><th>الحالة</th><th>تاريخ الإرسال</th></tr></thead><tbody>';

                    response.data.items.forEach(item => {
                        const date = new Date(item.created_at).toLocaleString('ar-EG');
                        html += `<tr>
                            <td><strong>${item.title_ar}</strong></td>
                            <td><code>${item.target}</code> (${item.targeted_count})</td>
                            <td><span style="color:#4caf50;">${item.push_success} نجح</span> / <span style="color:#f44336;">${item.push_failed} فشل</span></td>
                            <td>${date}</td>
                        </tr>`;
                    });

                    if (response.data.items.length === 0) {
                        html += '<tr><td colspan="4" style="text-align:center; padding:20px;">لا يوجد سجل حملات حتى الآن.</td></tr>';
                    }
                    html += '</tbody></table></div>';
                    $('#lexi-modal-body').html(html);
                }
            }
        });
    }

    window.openSendNotificationForm = function () {
        let formHtml = `
            <div class="lexi-form">
                <div class="lexi-field"><label>العنوان (بالعربية)</label><input type="text" id="notif-title" placeholder="أدخل عنوان الإشعار" style="width:100%;"></div>
                <div class="lexi-field"><label>نص الإشعار (بالعربية)</label><textarea id="notif-body" rows="3" placeholder="أدخل محتوى الإشعار" style="width:100%;"></textarea></div>
                <div class="lexi-field"><label>رابط الصورة (اختياري)</label><input type="text" id="notif-image" placeholder="https://..." style="width:100%;"></div>
                <div class="lexi-field">
                    <label>الهدف</label>
                    <select id="notif-target" style="width:100%;">
                        <option value="everyone">الجميع (بمن فيهم المديرون والضيوف)</option>
                        <option value="broadcast">بث للكل (الزبائن فقط)</option>
                        <option value="all_admins">جميع المديرين</option>
                        <option value="specific_user">مستخدم محدد (ID)</option>
                        <option value="specific_device">جهاز محدد (Device ID)</option>
                    </select>
                </div>
                <div class="lexi-field" id="notif-target-val-group" style="display:none;">
                    <label>معرف المستخدم / الجهاز</label><input type="text" id="notif-target-value" style="width:100%;">
                </div>
                <div class="lexi-field"><label>رابط عميق (Deep Link)</label><input type="text" id="notif-link" placeholder="category:ID / product:ID / screen_name" style="width:100%;"></div>
                <div class="lexi-field">
                    <label>Android Channel ID (اختياري)</label>
                    <input type="text" id="notif-channel" value="customer_default" style="width:100%;" placeholder="مثال: customer_default">
                </div>
                <div style="margin-top:20px; display:flex; gap:10px;">
                    <button class="button button-primary" onclick="sendNotification()">إرسال الآن</button>
                    <button class="button" onclick="loadNotificationsManager()">رجوع</button>
                </div>
            </div>
        `;
        $('#lexi-modal-title').text('إرسال إشعار دفع جديد');
        $('#lexi-modal-body').html(formHtml);
        $('#lexi-modal-actions').html('');

        $('#notif-target').on('change', function () {
            const val = $(this).val();
            if (val === 'specific_user' || val === 'specific_device') {
                $('#notif-target-val-group').show();
            } else {
                $('#notif-target-val-group').hide();
            }
        });
    };

    window.sendNotification = function () {
        const target = $('#notif-target').val();
        const data = {
            target: target,
            audience: target === 'all_admins' ? 'admin' : 'customer',
            title_ar: $('#notif-title').val(),
            body_ar: $('#notif-body').val(),
            image_url: $('#notif-image').val(),
            deep_link: $('#notif-link').val(),
            android_channel_id: $('#notif-channel').val() || 'customer_default',
            user_id: target === 'specific_user' ? $('#notif-target-value').val() : 0,
            device_id: target === 'specific_device' ? $('#notif-target-value').val() : '',
            send_push: true
        };

        if (!data.title_ar || !data.body_ar) {
            alert('يرجى إدخال العنوان والنص.');
            return;
        }

        lexiAjax({
            url: apiRoot + '/admin/notifications/send',
            method: 'POST',
            data: JSON.stringify(data),
            contentType: 'application/json',
            success: function (response) {
                if (response.success) {
                    alert('تم إرسال الإشعار بنجاح: ' + response.data.campaign.push_success + ' نجحوا.');
                    loadNotificationsManager();
                } else {
                    alert('فشل الإرسال: ' + response.error.message);
                }
            }
        });
    };

    // --- FCM Settings Management ---
    function loadFcmSettings() {
        openLexiModal('إعدادات Firebase Cloud Messaging', '<div class="lexi-loading">جارِ التحميل...</div>');

        lexiAjax({
            url: apiRoot + '/admin/notifications/firebase-settings',
            success: function (response) {
                if (response.success) {
                    const settings = response.data;
                    const escapeHtml = (value) => $('<div>').text(value || '').html();
                    const effectiveProjectHtml = settings.effective_project_id
                        ? `<small style="display:block; margin-top:6px; opacity:0.8;">المشروع المستخدم فعليًا: <code>${escapeHtml(settings.effective_project_id)}</code></small>`
                        : '';
                    const serviceProjectHtml = settings.service_account_project_id
                        ? `<small style="display:block; margin-top:6px; opacity:0.8;">المشروع داخل ملف الخدمة: <code>${escapeHtml(settings.service_account_project_id)}</code></small>`
                        : '';
                    const warningHtml = settings.config_warning
                        ? `<div style="margin-top:15px; padding:12px; background:rgba(255,82,82,0.12); border-right:4px solid #ff5252; border-radius:4px; color:#ffd6d6;"><strong>تحذير في الإعدادات:</strong> ${escapeHtml(settings.config_warning)}</div>`
                        : '';
                    let formHtml = `
                        <div class="lexi-form">
                            <div class="lexi-field" style="margin-bottom: 20px; display: flex; align-items: center; gap: 10px;">
                                <label style="margin:0; cursor:pointer;"><input type="checkbox" id="fcm-enabled" ${settings.enabled ? 'checked' : ''}> تفعيل إشعارات الدفع (FCM)</label>
                            </div>
                            <div class="lexi-field">
                                <label>Service Account JSON (URL or Path)</label>
                                <div style="display:flex; gap:10px;">
                                    <input type="text" id="fcm-json-path" value="${settings.fcm_service_account_path || ''}" style="flex:1; border-color:#555; background:#222; color:#fff;">
                                    <button class="button" type="button" onclick="fetchFcmJson()">جلب وتعبئة تلقائية</button>
                                </div>
                                <small style="display:block; margin-top:4px; opacity:0.6;">يمكنك وضع رابط مباشر لملف JSON أو المسار المحلي في الخادم.</small>
                            </div>
                            <div class="lexi-field" style="margin-top:15px;">
                                <label>Project ID</label>
                                <input type="text" id="fcm-project-id" value="${settings.fcm_project_id || ''}" style="width:100%; border-color:#555; background:#222; color:#fff;">
                                ${effectiveProjectHtml}
                                ${serviceProjectHtml}
                                <small style="display:block; margin-top:4px; opacity:0.6;">معرف المشروع في Firebase (مثال: leximegastore-25c4d)</small>
                            </div>
                            ${warningHtml}
                            <div style="margin-top:25px; padding:15px; background:rgba(255,165,0,0.1); border-right:4px solid #ffa500; border-radius:4px;">
                                <strong>تنبيه:</strong> سيتم استخدام هذه الإعدادات لجلب "Access Token" الخاص بـ FCM HTTP v1. تأكد من تحميل الملف في المسار الصحيح أو وضع رابط صحيح.
                            </div>
                            <div style="margin-top:30px; display:flex; gap:10px;">
                                <button class="button button-primary" onclick="saveFcmSettings()">حفظ الإعدادات</button><button class="button lexi-btn-delete" style="border-color:#ff5252; color:#ff5252; margin-right:10px;" onclick="clearPushTokens()">مسح الرموز (Reset)</button>
                                <button class="button" onclick="closeLexiModal()">إغلاق</button>
                            </div>
                        </div>
                    `;
                    $('#lexi-modal-body').html(formHtml);
                }
            }
        });
    }

        window.clearPushTokens = function () {
        if (!confirm('هل أنت متأكد من مسح جميع رموز الإشعارات؟ سيؤدي ذلك إلى توقف الإشعارات مؤقتاً لجميع المستخدمين حتى يفتحوا التطبيق مرة أخرى.')) {
            return;
        }

        const btn = $(event.target);
        const originalText = btn.text();
        btn.text('جارِ المسح...').prop('disabled', true);

        lexiAjax({
            url: apiRoot + '/admin/notifications/clear-tokens',
            method: 'DELETE',
            success: function (response) {
                if (response.success) {
                    alert(response.data.message);
                } else {
                    alert('خطأ: ' + response.error.message);
                }
            },
            complete: function () {
                btn.text(originalText).prop('disabled', false);
            }
        });
    };

    window.saveFcmSettings = function () {
        const data = {
            enabled: $('#fcm-enabled').is(':checked'),
            fcm_project_id: $('#fcm-project-id').val(),
            fcm_service_account_path: $('#fcm-json-path').val()
        };

        lexiAjax({
            url: apiRoot + '/admin/notifications/firebase-settings',
            method: 'PATCH',
            data: JSON.stringify(data),
            contentType: 'application/json',
            success: function (response) {
                if (response.success) {
                    alert('تم حفظ الإعدادات بنجاح.');
                    closeLexiModal();
                } else {
                    alert('خطأ في الحفظ: ' + (response.message || 'غير معروف'));
                }
            },
            error: function (xhr) {
                const msg = xhr.responseJSON ? xhr.responseJSON.message : 'فشل الاتصال بالخادم.';
                alert('فشل الحفظ: ' + msg);
            }
        });
    };

    window.fetchFcmJson = function () {
        const pathOrUrl = $('#fcm-json-path').val().trim();
        if (!pathOrUrl) {
            alert('يرجى إدخال الرابط أولاً.');
            return;
        }

        if (!pathOrUrl.startsWith('http')) {
            alert('يرجى إدخال رابط (URL) صالح للملف لجلب البيانات تلقائياً.');
            return;
        }

        const originalText = $('button:contains("جلب وتعبئة تلقائية")').text();
        $('button:contains("جلب وتعبئة تلقائية")').text('جارِ الجلب...').prop('disabled', true);

        $.ajax({
            url: pathOrUrl,
            method: 'GET',
            dataType: 'json',
            success: function (data) {
                if (data && data.project_id) {
                    $('#fcm-project-id').val(data.project_id);
                    alert('تم جلب البيانات بنجاح: ' + data.project_id);
                } else {
                    alert('الملف لا يبدو أنه ملف JSON صالح لـ Firebase Service Account.');
                }
            },
            error: function () {
                alert('فشل في جلب الملف. تأكد من صحة الرابط ومن سياسة الـ CORS (قد تحتاج لرفعه على استضافة تسمح بالوصول من المتصفح).');
            },
            complete: function () {
                $('button:contains("جلب وتعبئة تلقائية")').text(originalText).prop('disabled', false);
            }
        });
    };

    // --- Home Sections ---
    function loadHomeSections() {
        const addBtn = '<button class="button button-primary" onclick="openHomeSectionForm()">إضافة قسم جديد</button>';
        openLexiModal('إدارة الأقسام الرئيسية', '<div class="lexi-loading">جارِ التحميل...</div>', addBtn);
        lexiAjax({
            url: apiRoot + '/admin/merch/home-sections',
            success: function (response) {
                if (response.success) { // Fixed: was response.ok
                    let html = '<table class="wp-list-table widefat fixed striped lexi-modal-table">';
                    html += '<thead><tr><th>القسم</th><th>النوع</th><th>الحالة</th><th>الإجراءات</th></tr></thead><tbody>';
                    response.data.items.forEach(item => {
                        const statusColor = item.is_active ? '#4caf50' : '#f44336';
                        const statusLabel = item.is_active ? 'نشط' : 'معطل';
                        html += `<tr id="section-${item.id}">
                            <td><strong>${item.title_ar}</strong></td>
                            <td><code>${item.type}</code></td>
                            <td><span style="color:${statusColor}; font-weight:bold;">${statusLabel}</span></td>
                            <td>
                                <button class="button button-small" onclick=\'openHomeSectionForm(${JSON.stringify(item).replace(/'/g, "&apos;")})\'>تعديل</button>
                                <button class="button button-small lexi-btn-delete" onclick="deleteHomeSection(${item.id})">حذف</button>
                            </td>
                        </tr>`;
                    });
                    if (response.data.items.length === 0) {
                        html += '<tr><td colspan="4" style="text-align:center; padding:20px;">لا توجد أقسام مضافة حالياً.</td></tr>';
                    }
                    html += '</tbody></table>';
                    $('#lexi-modal-body').html(html);
                }
            }
        });
    }

    window.openHomeSectionForm = function (item = null) {
        const isEdit = !!item;
        const title = isEdit ? 'تعديل قسم' : 'إضافة قسم جديد';
        let categoriesHtml = '<option value="">اختر التصنيف...</option>';
        lexiAjax({
            url: apiRoot + '/admin/merch/categories',
            async: false,
            success: function (resp) {
                if (resp.success) {
                    resp.data.items.forEach(cat => {
                        const categoryLabel = cat.display_name || cat.name;
                        categoriesHtml += `<option value="${cat.id}" ${item && item.term_id == cat.id ? 'selected' : ''}>${categoryLabel}</option>`;
                    });
                }
            }
        });

        let formHtml = `
            <div class="lexi-form">
                <div class="lexi-field"><label>العنوان (بالعربية)</label><input type="text" id="hs-title" value="${item ? item.title_ar : ''}" style="width:100%;"></div>
                <div class="lexi-field">
                    <label>النوع</label>
                    <select id="hs-type" style="width:100%;">
                        <option value="manual_products" ${item && item.type === 'manual_products' ? 'selected' : ''}>منتجات يدوية</option>
                        <option value="category" ${item && item.type === 'category' ? 'selected' : ''}>تصنيف محدد</option>
                        <option value="deals" ${item && item.type === 'deals' ? 'selected' : ''}>عروض فلاش</option>
                    </select>
                </div>
                <div class="lexi-field" id="hs-cat-group" style="${item && item.type === 'category' ? '' : 'display:none;'}">
                    <label>التصنيف</label><select id="hs-term-id" style="width:100%;">${categoriesHtml}</select>
                </div>
                <div class="lexi-field"><label><input type="checkbox" id="hs-active" ${!item || item.is_active ? 'checked' : ''}> نشط</label></div>
                <div style="margin-top:20px; display:flex; gap:10px;">
                    <button class="button button-primary" onclick="saveHomeSection(${item ? item.id : 'null'})">حفظ</button>
                    <button class="button" onclick="loadHomeSections()">إلغاء</button>
                </div>
            </div>
        `;
        $('#lexi-modal-title').text(title);
        $('#lexi-modal-body').html(formHtml);
        $('#lexi-modal-actions').html('');
        $('#hs-type').on('change', function () { if ($(this).val() === 'category') { $('#hs-cat-group').show(); } else { $('#hs-cat-group').hide(); } });
    };

    window.saveHomeSection = function (id) {
        const data = { title_ar: $('#hs-title').val(), type: $('#hs-type').val(), term_id: $('#hs-term-id').val(), is_active: $('#hs-active').is(':checked') };
        lexiAjax({
            url: apiRoot + '/admin/merch/home-sections' + (id ? '/' + id : ''),
            method: id ? 'PATCH' : 'POST',
            data: JSON.stringify(data),
            contentType: 'application/json',
            success: function (response) { if (response.success) { loadHomeSections(); } else { showToast(response.error.message, true); } }
        });
    };

    window.deleteHomeSection = function (id) {
        if (!confirm('هل أنت متأكد من حذف هذا القسم؟')) return;
        lexiAjax({
            url: apiRoot + '/admin/merch/home-sections/' + id,
            method: 'DELETE',
            success: function (response) { if (response.success) { $(`#section-${id}`).fadeOut(); } }
        });
    };

    // --- Banners ---
    function loadBanners() {
        const addBtn = '<button class="button button-primary" onclick="openBannerForm()">إضافة بانر جديد</button>';
        openLexiModal('إدارة البانرات الإعلانية', '<div class="lexi-loading">جارِ التحميل...</div>', addBtn);
        lexiAjax({
            url: apiRoot + '/admin/merch/ad-banners',
            success: function (response) {
                if (response.success) {
                    let html = '<table class="wp-list-table widefat fixed striped lexi-modal-table">';
                    html += '<thead><tr><th>البانر</th><th>الصورة</th><th>الرابط</th><th>الإجراءات</th></tr></thead><tbody>';
                    response.data.items.forEach(item => {
                        html += `<tr id="banner-${item.id}">
                            <td><strong>${item.title || 'بدون عنوان'}</strong></td>
                            <td><img src="${item.image_url}" style="height:40px; border-radius:4px; border:1px solid #444;"></td>
                            <td><code>${item.link_type || 'none'}</code></td>
                            <td>
                                <button class="button button-small" onclick=\'openBannerForm(${JSON.stringify(item).replace(/'/g, "&apos;")})\'>تعديل</button>
                                <button class="button button-small lexi-btn-delete" onclick="deleteBanner(${item.id})">حذف</button>
                            </td>
                        </tr>`;
                    });
                    if (response.data.items.length === 0) {
                        html += '<tr><td colspan="4" style="text-align:center; padding:20px;">لا توجد بانرات مضافة حالياً.</td></tr>';
                    }
                    html += '</tbody></table>';
                    $('#lexi-modal-body').html(html);
                }
            }
        });
    }

    window.openBannerForm = function (item = null) {
        const isEdit = !!item;
        const title = isEdit ? 'تعديل بانر' : 'إضافة بانر جديد';
        let formHtml = `
            <div class="lexi-form">
                <div class="lexi-field"><label>عنوان البانر</label><input type="text" id="bn-title" value="${item ? (item.title || '') : ''}" style="width:100%;"></div>
                <div class="lexi-field"><label>رابط الصورة</label><input type="text" id="bn-image" value="${item ? (item.image_url || '') : ''}" style="width:100%;"></div>
                <div class="lexi-field">
                    <label>نوع الارتباط</label>
                    <select id="bn-link-type" style="width:100%;">
                        <option value="none" ${item && item.link_type === 'none' ? 'selected' : ''}>لا يوجد</option>
                        <option value="category" ${item && item.link_type === 'category' ? 'selected' : ''}>تصنيف</option>
                        <option value="product" ${item && item.link_type === 'product' ? 'selected' : ''}>منتج محدد</option>
                        <option value="url" ${item && item.link_type === 'url' ? 'selected' : ''}>رابط خارجي</option>
                    </select>
                </div>
                <div class="lexi-field"><label>قيمة الارتباط (ID أو URL)</label><input type="text" id="bn-link-value" value="${item ? (item.link_value || '') : ''}" style="width:100%;"></div>
                <div style="margin-top:20px; display:flex; gap:10px;">
                    <button class="button button-primary" onclick="saveBanner(${item ? item.id : 'null'})">حفظ</button>
                    <button class="button" onclick="loadBanners()">إلغاء</button>
                </div>
            </div>
        `;
        $('#lexi-modal-title').text(title);
        $('#lexi-modal-body').html(formHtml);
        $('#lexi-modal-actions').html('');
    };

    window.saveBanner = function (id) {
        lexiAjax({
            url: apiRoot + '/admin/merch/ad-banners',
            success: function (response) {
                if (response.success) {
                    let banners = response.data.items;
                    const newBanner = { id: id || Date.now(), title: $('#bn-title').val(), image_url: $('#bn-image').val(), link_type: $('#bn-link-type').val(), link_value: $('#bn-link-value').val() };
                    if (id) { banners = banners.map(b => b.id == id ? newBanner : b); } else { banners.push(newBanner); }
                    lexiAjax({
                        url: apiRoot + '/admin/merch/ad-banners',
                        method: 'POST',
                        data: JSON.stringify({ items: banners }),
                        contentType: 'application/json',
                        success: function () { loadBanners(); }
                    });
                }
            }
        });
    };

    window.deleteBanner = function (id) {
        if (!confirm('هل أنت متأكد من حذف هذا البانر؟')) return;
        lexiAjax({
            url: apiRoot + '/admin/merch/ad-banners/' + id,
            method: 'DELETE',
            success: function (response) { if (response.success) { $(`#banner-${id}`).fadeOut(); } }
        });
    };

    // --- Categories ---
    function loadCategories() {
        openLexiModal('تصنيفات المنتجات', '<div class="lexi-loading">جارِ التحميل...</div>');
        lexiAjax({
            url: apiRoot + '/admin/merch/categories',
            success: function (response) {
                if (response.success) {
                    let html = '<table class="wp-list-table widefat fixed striped lexi-modal-table">';
                    html += '<thead><tr><th>التصنيف</th><th>الصورة</th><th>الإجراءات</th></tr></thead><tbody>';
                    response.data.items.forEach(item => {
                        const categoryLabel = item.display_name || item.name;
                        html += `<tr>
                            <td><strong>${categoryLabel}</strong></td>
                            <td><img src="${item.image_url}" style="height:35px; border-radius:4px;"></td>
                            <td><a href="edit-tags.php?action=edit&taxonomy=product_cat&tag_ID=${item.id}&post_type=product" class="button button-small">تعديل</a></td>
                        </tr>`;
                    });
                    html += '</tbody></table>';
                    $('#lexi-modal-body').html(html);
                }
            }
        });
    }

    // --- Reviews ---
    function loadReviews() {
        openLexiModal('مراجعة التقييمات', '<div class="lexi-loading">جارِ التحميل...</div>');
        lexiAjax({
            url: apiRoot + '/admin/merch/reviews/pending',
            success: function (response) {
                if (response.success) {
                    let html = '<table class="wp-list-table widefat fixed striped lexi-modal-table">';
                    html += '<thead><tr><th>المنتج</th><th>العميل</th><th>التقييم</th><th>الإجراءات</th></tr></thead><tbody>';
                    response.data.items.forEach(item => {
                        html += `<tr id="review-${item.id}">
                            <td>${item.product_name}</td>
                            <td>${item.author_name}</td>
                            <td>${'⭐'.repeat(item.rating)}</td>
                            <td>
                                <button class="button button-small lexi-btn-success" onclick="approveReview(${item.id})">قبول</button>
                                <button class="button button-small lexi-btn-delete" onclick="deleteReview(${item.id})">حذف</button>
                            </td>
                        </tr>`;
                    });
                    html += '</tbody></table>';
                    $('#lexi-modal-body').html(response.data.items.length ? html : '<p style="text-align:center; padding:20px;">لا توجد مراجعات معلقة حالياً.</p>');
                }
            }
        });
    }

    window.approveReview = function (id) {
        lexiAjax({
            url: apiRoot + '/admin/merch/reviews/' + id + '/approve',
            method: 'POST',
            success: function (response) { if (response.success) { $(`#review-${id}`).fadeOut(); } }
        });
    };

    window.deleteReview = function (id) {
        if (!confirm('هل أنت متأكد من حذف هذا التقييم؟')) return;
        lexiAjax({
            url: apiRoot + '/admin/merch/reviews/' + id,
            method: 'DELETE',
            success: function (response) { if (response.success) { $(`#review-${id}`).fadeOut(); } }
        });
    };

    // Initialize
    fetchDashboardStats();
    fetchIntelOverview();
});
