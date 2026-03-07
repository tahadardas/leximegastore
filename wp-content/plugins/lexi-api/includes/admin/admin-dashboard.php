<?php
/**
 * Lexi Admin Dashboard Template
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>

<div class="lexi-dashboard-wrapper">
    <div class="lexi-header">
        <h1>لوحة تحكم ليكسي</h1>
        <p>مرحباً بك في مركز إدارة متجر ليكسي ميجا ستور.</p>
    </div>

    <!-- Hero Today Summary -->
    <div id="lexi-hero-summary">
        <div class="lexi-card lexi-hero-card">
            <div class="kpi-label">إجمالي مبيعات اليوم</div>
            <div class="kpi-value" id="stat-today-sales">...</div>
            <div style="margin-top: 10px; font-size: 14px; opacity: 0.8;">
                عدد طلبات اليوم: <span id="stat-today-orders">...</span>
            </div>
        </div>
    </div>

    <!-- KPI Grid -->
    <div class="lexi-kpi-grid">
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label"><span class="dashicons dashicons-archive"></span> إجمالي الطلبات</div>
            <div class="kpi-value" id="stat-total-orders">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label"><span class="dashicons dashicons-id-alt"></span> بانتظار التحقق</div>
            <div class="kpi-value" id="stat-pending-verification" style="color: var(--lexi-warning);">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label"><span class="dashicons dashicons-update"></span> قيد المعالجة</div>
            <div class="kpi-value" id="stat-processing" style="color: var(--lexi-info);">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label"><span class="dashicons dashicons-yes-alt"></span> مكتمل</div>
            <div class="kpi-value" id="stat-completed" style="color: var(--lexi-success);">...</div>
        </div>
    </div>

    <div class="lexi-section-title">
        <span class="dashicons dashicons-chart-line"></span> Store Intelligence
    </div>

    <div class="lexi-kpi-grid">
         <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label">معدل التحويل</div>
            <div class="kpi-value" id="stat-conversion-rate" style="color: var(--lexi-success);">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label">متوسط قيمة الطلب</div>
            <div class="kpi-value" id="stat-avg-order">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label">الإضافة للسلة</div>
            <div class="kpi-value" id="stat-add-to-cart" style="color: var(--lexi-info);">...</div>
        </div>
        <div class="lexi-card lexi-kpi-card">
            <div class="kpi-label">إجمالي الجلسات</div>
            <div class="kpi-value" id="stat-sessions">...</div>
        </div>
    </div>

    <div class="lexi-section-title">
        <span class="dashicons dashicons-bolt"></span> إجراءات سريعة
    </div>

    <div class="lexi-action-list">
        <div class="lexi-action-item" onclick="window.location.href='admin.php?page=wc-orders'">
            <div class="lexi-action-icon"><span class="dashicons dashicons-list-view"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">إدارة الطلبات</span>
                <span class="action-subtitle">مراجعة الحالات وتأكيد المدفوعات.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-home-sections">
            <div class="lexi-action-icon"><span class="dashicons dashicons-layout"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">ترتيب الأقسام</span>
                <span class="action-subtitle">التحكم في ظهور وترتيب أقسام الصفحة الرئيسية.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-banners">
            <div class="lexi-action-icon"><span class="dashicons dashicons-images-alt2"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">بانرات إعلانية</span>
                <span class="action-subtitle">إدارة بانرات الصور الإعلانية في الصفحة الرئيسية.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-categories">
            <div class="lexi-action-icon"><span class="dashicons dashicons-category"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">تصنيفات المنتجات</span>
                <span class="action-subtitle">إدارة التصنيفات وترتيب المنتجات داخلها.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-reviews">
            <div class="lexi-action-icon"><span class="dashicons dashicons-testimonial"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">مراجعة التقييمات</span>
                <span class="action-subtitle">الموافقة على تقييمات العملاء أو حذفها.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-notifications">
            <div class="lexi-action-icon"><span class="dashicons dashicons-megaphone"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">إشعارات الدفع</span>
                <span class="action-subtitle">إرسال تنبيهات وحملات تسويقية للمستخدمين.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>

        <div class="lexi-action-item" id="action-fcm-settings">
            <div class="lexi-action-icon"><span class="dashicons dashicons-admin-settings"></span></div>
            <div class="lexi-action-info">
                <span class="action-title">إعدادات Firebase</span>
                <span class="action-subtitle">ضبط مفاتيح الربط ورموز الوصول لـ FCM.</span>
            </div>
            <span class="dashicons dashicons-arrow-left-alt2"></span>
        </div>
    </div>
</div>

<!-- Management Modals -->
<div class="lexi-modal-overlay" id="lexi-modal-overlay">
    <div class="lexi-modal">
        <div class="lexi-modal-header">
            <h2 id="lexi-modal-title" style="margin:0; color: #fff;">...</h2>
            <div id="lexi-modal-actions" style="margin-right: 15px; display:flex; gap:10px;"></div>
            <button class="dashicons dashicons-no-alt" style="background:none; border:none; color:#888; cursor:pointer; margin-right: auto;" onclick="closeLexiModal()"></button>
        </div>
        <div class="lexi-modal-body" id="lexi-modal-body">
            <!-- Dynamic Content -->
        </div>
    </div>
</div>
