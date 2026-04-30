<?php
/**
 * Support ticketing routes (customer + admin).
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Support
{
    /**
     * Register support routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        // Public customer routes (guest-friendly, protected by chat_token).
        register_rest_route($ns, '/support/tickets', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'create_ticket'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/support/my-tickets', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_my_tickets'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/support/tickets/(?P<ticket_id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_ticket_details'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/support/tickets/(?P<ticket_id>\d+)/messages', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'send_customer_message'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/support/tickets/(?P<ticket_id>\d+)/attachments', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'upload_customer_attachment'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/support/tickets/(?P<ticket_id>\d+)/close', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'close_customer_ticket'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/support/tickets/(?P<ticket_id>\d+)/poll', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'poll_ticket_messages'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        // Admin routes (JWT + manage_woocommerce).
        register_rest_route($ns, '/admin/support/tickets', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_inbox'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/support/tickets/(?P<id>\d+)', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'admin_ticket_details'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'admin_update_ticket'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));

        register_rest_route($ns, '/admin/support/tickets/(?P<id>\d+)/reply', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_reply'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/support/tickets/(?P<id>\d+)/note', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_note'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/support/tickets/(?P<id>\d+)/assign', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'admin_assign'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/support/canned', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'admin_get_canned'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'admin_save_canned'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));

        register_rest_route($ns, '/admin/support/analytics', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_analytics'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));
    }

    /**
     * POST /support/tickets
     */
    public static function create_ticket(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();

        $name = trim(sanitize_text_field((string) ($body['name'] ?? '')));
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? ''));
        $email = sanitize_email((string) ($body['email'] ?? ''));
        $subject = trim(sanitize_text_field((string) ($body['subject'] ?? '')));
        $message_raw = (string) (
            $body['message']
            ?? $body['details']
            ?? $body['description']
            ?? ''
        );
        $message = trim(sanitize_textarea_field($message_raw));
        $category = Lexi_Support::normalize_category((string) ($body['category'] ?? 'other'));
        $priority = Lexi_Support::normalize_priority((string) ($body['priority'] ?? 'medium'));

        if (strlen($name) < 2) {
            return Lexi_Security::error('invalid_name', 'يرجى إدخال الاسم بشكل صحيح.', 422);
        }
        if (strlen($phone) < 9) {
            return Lexi_Security::error('invalid_phone', 'يرجى إدخال رقم هاتف صحيح.', 422);
        }
        if (strlen($subject) < 3) {
            return Lexi_Security::error('invalid_subject', 'عنوان المشكلة مطلوب.', 422);
        }
        if (strlen($message) < 10) {
            return Lexi_Security::error('invalid_message', 'يرجى كتابة تفاصيل المشكلة (10 أحرف على الأقل).', 422);
        }
        if ('' !== $email && !is_email($email)) {
            return Lexi_Security::error('invalid_email', 'البريد الإلكتروني غير صالح.', 422);
        }

        $ticket = Lexi_Support::create_ticket(array(
            'name' => $name,
            'phone' => $phone,
            'email' => $email,
            'subject' => $subject,
            'category' => $category,
            'priority' => $priority,
            'customer_user_id' => get_current_user_id(),
        ));

        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_create_failed', 'تعذر إنشاء التذكرة حالياً.', 500);
        }

        // Add initial message
        Lexi_Support::add_message(
            (int) $ticket['id'],
            'customer',
            $message,
            get_current_user_id()
        );

        self::notify_admin_activity(
            $ticket,
            'تذكرة دعم جديدة',
            'تم إنشاء تذكرة دعم جديدة وتحتاج المتابعة.'
        );

        return Lexi_Security::success(array(
            'ticket_id' => (int) $ticket['id'],
            'ticket_number' => (string) $ticket['ticket_number'],
            'chat_token' => (string) $ticket['chat_token'],
            'status' => 'open',
            'status_label_ar' => Lexi_Support::status_label_ar('open'),
            'sla_first_response_minutes' => (int) $ticket['sla_first_response_minutes'],
            'sla_resolution_minutes' => (int) $ticket['sla_resolution_minutes'],
        ), 201);
    }

    /**
     * GET /support/my-tickets
     */
    public static function get_my_tickets(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('auth_required', 'يجب تسجيل الدخول للوصول إلى التذاكر.', 401);
        }

        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));
        $table = Lexi_Support::tickets_table();

        $total = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT COUNT(*) FROM {$table} WHERE customer_user_id = %d",
                $user_id
            )
        );

        $offset = ($page - 1) * $per_page;
        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT * FROM {$table}
                 WHERE customer_user_id = %d
                 ORDER BY updated_at DESC
                 LIMIT %d OFFSET %d",
                $user_id,
                $per_page,
                $offset
            ),
            ARRAY_A
        );
        if (!is_array($rows)) {
            $rows = array();
        }

        $items = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $payload = Lexi_Support::normalize_ticket_payload($row);
            $payload = Lexi_Support::with_sla_flags($payload);
            $payload['unread_count'] = 0;
            $items[] = $payload;
        }

        return Lexi_Security::success(array(
            'tickets' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
        ));
    }

    /**
     * GET /support/tickets/{ticket_id}?token=...
     */
    public static function get_ticket_details(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('ticket_id');
        $token = trim((string) $request->get_param('token'));

        $ticket = self::validate_customer_ticket($ticket_id, $token);
        if ($ticket instanceof WP_REST_Response) {
            return $ticket;
        }

        $messages = Lexi_Support::get_messages($ticket_id, false, 0);
        $attachments = Lexi_Support::get_attachments($ticket_id);

        $latest = Lexi_Support::last_message_id($ticket_id, false);
        Lexi_Support::mark_view(
            $ticket_id,
            'customer',
            Lexi_Support::customer_viewer_key($token),
            $latest
        );

        $data = Lexi_Support::normalize_ticket_payload($ticket);
        $data['messages'] = $messages;
        $data['attachments'] = $attachments;

        return Lexi_Security::success($data);
    }

    /**
     * POST /support/tickets/{ticket_id}/messages
     */
    public static function send_customer_message(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('ticket_id');
        $body = (array) $request->get_json_params();
        $token = trim((string) ($body['token'] ?? ''));
        $message = trim(sanitize_textarea_field((string) ($body['message'] ?? '')));

        if ('' === $message) {
            return Lexi_Security::error('message_required', 'نص الرسالة مطلوب.', 422);
        }

        $ticket = self::validate_customer_ticket($ticket_id, $token);
        if ($ticket instanceof WP_REST_Response) {
            return $ticket;
        }

        $status = Lexi_Support::normalize_status((string) ($ticket['status'] ?? 'open'));
        if ('closed' === $status) {
            return Lexi_Security::error('ticket_closed', 'لا يمكن إرسال رسائل في تذكرة مغلقة.', 422);
        }

        $created = Lexi_Support::add_message($ticket_id, 'customer', $message, 0, 0);
        if (!is_array($created)) {
            return Lexi_Security::error('send_failed', 'تعذر إرسال الرسالة حالياً.', 500);
        }

        Lexi_Support::update_ticket($ticket_id, array(
            'status' => 'pending_admin',
            'updated_at' => Lexi_Support::now(),
            'last_message_at' => Lexi_Support::now(),
        ));

        self::notify_admin_activity(
            $ticket,
            'رسالة جديدة في تذكرة دعم',
            sprintf('وصلت رسالة جديدة في التذكرة %s.', (string) $ticket['ticket_number'])
        );

        return Lexi_Security::success(array(
            'message' => $created,
            'status' => 'pending_admin',
            'status_label_ar' => Lexi_Support::status_label_ar('pending_admin'),
        ), 201);
    }

    /**
     * POST /support/tickets/{ticket_id}/attachments
     */
    public static function upload_customer_attachment(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('ticket_id');
        $token = trim((string) $request->get_param('token'));
        $message_id = absint((int) $request->get_param('message_id'));

        $ticket = self::validate_customer_ticket($ticket_id, $token);
        if ($ticket instanceof WP_REST_Response) {
            return $ticket;
        }

        $status = Lexi_Support::normalize_status((string) ($ticket['status'] ?? 'open'));
        if ('closed' === $status) {
            return Lexi_Security::error('ticket_closed', 'لا يمكن رفع مرفقات في تذكرة مغلقة.', 422);
        }

        $files = $request->get_file_params();
        if (empty($files['file'])) {
            return Lexi_Security::error('file_required', 'يرجى اختيار ملف للرفع.', 422);
        }

        $file = $files['file'];
        $allowed = array(
            'image/jpeg',
            'image/png',
            'image/webp',
            'image/gif',
            'application/pdf',
        );

        $mime = (string) ($file['type'] ?? '');
        $size = (int) ($file['size'] ?? 0);

        if (!in_array($mime, $allowed, true)) {
            return Lexi_Security::error('invalid_file_type', 'نوع الملف غير مدعوم.', 422);
        }
        if ($size <= 0 || $size > 5 * 1024 * 1024) {
            return Lexi_Security::error('file_too_large', 'حجم الملف يتجاوز الحد المسموح (5MB).', 422);
        }

        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/media.php';
        require_once ABSPATH . 'wp-admin/includes/image.php';

        $upload = wp_handle_upload($file, array('test_form' => false));
        if (!is_array($upload) || isset($upload['error'])) {
            return Lexi_Security::error('upload_failed', 'تعذر رفع الملف حالياً.', 500);
        }

        $attach_id = wp_insert_attachment(array(
            'post_title' => sprintf('مرفق تذكرة %s', (string) $ticket['ticket_number']),
            'post_mime_type' => (string) ($upload['type'] ?? $mime),
            'post_status' => 'inherit',
        ), (string) $upload['file']);

        if (is_wp_error($attach_id) || !$attach_id) {
            return Lexi_Security::error('save_failed', 'تعذر حفظ الملف حالياً.', 500);
        }

        $metadata = wp_generate_attachment_metadata($attach_id, (string) $upload['file']);
        if (is_array($metadata)) {
            wp_update_attachment_metadata((int) $attach_id, $metadata);
        }

        if ($message_id <= 0) {
            $message = Lexi_Support::add_message($ticket_id, 'customer', 'تم إرسال مرفق.', 0, 0);
            $message_id = is_array($message) ? (int) $message['id'] : 0;
        } else {
            global $wpdb;
            $messages_table = Lexi_Support::messages_table();
            $exists = (int) $wpdb->get_var(
                $wpdb->prepare(
                    "SELECT COUNT(*) FROM {$messages_table} WHERE id = %d AND ticket_id = %d",
                    $message_id,
                    $ticket_id
                )
            );
            if ($exists <= 0) {
                return Lexi_Security::error('invalid_message_id', 'مرجع الرسالة غير صالح.', 422);
            }
        }

        $attachment = Lexi_Support::add_attachment(
            $ticket_id,
            $message_id,
            array(
                'wp_attachment_id' => (int) $attach_id,
                'url' => (string) ($upload['url'] ?? ''),
                'mime_type' => (string) ($upload['type'] ?? $mime),
                'size_bytes' => $size,
            )
        );

        if (!is_array($attachment)) {
            return Lexi_Security::error('save_failed', 'تعذر حفظ بيانات المرفق.', 500);
        }

        Lexi_Support::update_ticket($ticket_id, array(
            'status' => 'pending_admin',
            'updated_at' => Lexi_Support::now(),
            'last_message_at' => Lexi_Support::now(),
        ));

        self::notify_admin_activity(
            $ticket,
            'مرفق جديد في تذكرة دعم',
            sprintf('تم رفع مرفق جديد في التذكرة %s.', (string) $ticket['ticket_number'])
        );

        return Lexi_Security::success(array(
            'attachment' => $attachment,
            'status' => 'pending_admin',
            'status_label_ar' => Lexi_Support::status_label_ar('pending_admin'),
        ), 201);
    }

    /**
     * POST /support/tickets/{ticket_id}/close
     */
    public static function close_customer_ticket(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('ticket_id');
        $body = (array) $request->get_json_params();
        $token = trim((string) ($body['token'] ?? ''));
        $rating = isset($body['rating']) ? (int) $body['rating'] : null;
        $feedback = trim(sanitize_textarea_field((string) ($body['feedback'] ?? '')));

        $ticket = self::validate_customer_ticket($ticket_id, $token);
        if ($ticket instanceof WP_REST_Response) {
            return $ticket;
        }

        if (null !== $rating && ($rating < 1 || $rating > 5)) {
            return Lexi_Security::error('invalid_rating', 'التقييم يجب أن يكون بين 1 و5.', 422);
        }

        Lexi_Support::update_ticket($ticket_id, array(
            'status' => 'closed',
            'closed_at' => Lexi_Support::now(),
            'customer_rating' => $rating,
            'customer_feedback' => $feedback,
            'updated_at' => Lexi_Support::now(),
        ));

        Lexi_Support::add_message($ticket_id, 'system', 'تم إغلاق التذكرة من قبل العميل.', 0, 0);

        return Lexi_Security::success(array(
            'status' => 'closed',
            'status_label_ar' => Lexi_Support::status_label_ar('closed'),
            'message_ar' => 'تم إغلاق التذكرة بنجاح.',
        ));
    }

    /**
     * GET /support/tickets/{ticket_id}/poll?token=...&since_id=123
     */
    public static function poll_ticket_messages(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('ticket_id');
        $token = trim((string) $request->get_param('token'));
        $since_id = max(0, (int) $request->get_param('since_id'));

        $ticket = self::validate_customer_ticket($ticket_id, $token);
        if ($ticket instanceof WP_REST_Response) {
            return $ticket;
        }

        $messages = Lexi_Support::get_messages($ticket_id, false, $since_id);
        $message_ids = array_values(array_filter(array_map(function ($m) {
            return isset($m['id']) ? (int) $m['id'] : 0;
        }, $messages)));
        $attachments = !empty($message_ids)
            ? Lexi_Support::get_attachments($ticket_id, $message_ids)
            : array();

        $latest = Lexi_Support::last_message_id($ticket_id, false);
        Lexi_Support::mark_view(
            $ticket_id,
            'customer',
            Lexi_Support::customer_viewer_key($token),
            $latest
        );

        return Lexi_Security::success(array(
            'ticket_id' => $ticket_id,
            'status' => Lexi_Support::normalize_status((string) ($ticket['status'] ?? 'open')),
            'status_label_ar' => Lexi_Support::status_label_ar((string) ($ticket['status'] ?? 'open')),
            'messages' => $messages,
            'attachments' => $attachments,
            'last_message_id' => $latest,
        ));
    }

    /**
     * GET /admin/support/tickets
     */
    public static function admin_inbox(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $status = trim((string) $request->get_param('status'));
        $priority = trim((string) $request->get_param('priority'));
        $category = trim((string) $request->get_param('category'));
        $assigned = trim((string) $request->get_param('assigned'));
        $q = trim((string) $request->get_param('q'));
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $table = Lexi_Support::tickets_table();
        $where = array('1=1');
        $params = array();

        if ('' !== $status) {
            $where[] = 'status = %s';
            $params[] = Lexi_Support::normalize_status($status);
        }
        if ('' !== $priority) {
            $where[] = 'priority = %s';
            $params[] = Lexi_Support::normalize_priority($priority);
        }
        if ('' !== $category) {
            $where[] = 'category = %s';
            $params[] = Lexi_Support::normalize_category($category);
        }

        if ('me' === $assigned) {
            $where[] = 'assigned_user_id = %d';
            $params[] = get_current_user_id();
        } elseif ('unassigned' === $assigned) {
            $where[] = '(assigned_user_id IS NULL OR assigned_user_id = 0)';
        } elseif (is_numeric($assigned) && (int) $assigned > 0) {
            $where[] = 'assigned_user_id = %d';
            $params[] = (int) $assigned;
        }

        if ('' !== $q) {
            $like = '%' . $wpdb->esc_like($q) . '%';
            $where[] = '(ticket_number LIKE %s OR phone LIKE %s OR subject LIKE %s OR name LIKE %s)';
            $params[] = $like;
            $params[] = $like;
            $params[] = $like;
            $params[] = $like;
        }

        $where_sql = implode(' AND ', $where);

        $count_sql = "SELECT COUNT(*) FROM {$table} WHERE {$where_sql}";
        if (empty($params)) {
            $total = (int) $wpdb->get_var($count_sql);
        } else {
            $total = (int) $wpdb->get_var($wpdb->prepare($count_sql, $params));
        }

        $offset = ($page - 1) * $per_page;
        $rows_sql = "SELECT * FROM {$table} WHERE {$where_sql} ORDER BY last_message_at DESC LIMIT %d OFFSET %d";
        $rows_params = array_merge($params, array($per_page, $offset));
        $rows = $wpdb->get_results($wpdb->prepare($rows_sql, $rows_params), ARRAY_A);
        if (!is_array($rows)) {
            $rows = array();
        }

        $admin_id = get_current_user_id();
        $items = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $payload = Lexi_Support::normalize_ticket_payload($row);
            $payload = Lexi_Support::with_sla_flags($payload);
            $payload['unread_count'] = Lexi_Support::admin_unread_count((int) $payload['id'], $admin_id);
            $payload['assigned_agent'] = self::user_brief((int) $payload['assigned_user_id']);
            $items[] = $payload;
        }

        return Lexi_Security::success(array(
            'tickets' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
        ));
    }

    /**
     * GET /admin/support/tickets/{id}
     */
    public static function admin_ticket_details(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('id');
        $ticket = Lexi_Support::get_ticket($ticket_id);

        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }

        $messages = Lexi_Support::get_messages($ticket_id, true, 0);
        $attachments = Lexi_Support::get_attachments($ticket_id);

        $latest = Lexi_Support::last_message_id($ticket_id, true);
        Lexi_Support::mark_view(
            $ticket_id,
            'admin',
            Lexi_Support::admin_viewer_key(get_current_user_id()),
            $latest
        );

        $payload = Lexi_Support::normalize_ticket_payload($ticket);
        $payload = Lexi_Support::with_sla_flags($payload);
        $payload['assigned_agent'] = self::user_brief((int) $payload['assigned_user_id']);
        $payload['messages'] = $messages;
        $payload['attachments'] = $attachments;

        return Lexi_Security::success($payload);
    }

    /**
     * POST /admin/support/tickets/{id}/reply
     */
    public static function admin_reply(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('id');
        $ticket = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }

        $body = (array) $request->get_json_params();
        $message = trim(sanitize_textarea_field((string) ($body['message'] ?? '')));
        $as_note = self::bool_value($body['as_note'] ?? false);

        if ('' === $message) {
            return Lexi_Security::error('message_required', 'نص الرد مطلوب.', 422);
        }

        $created = Lexi_Support::add_message(
            $ticket_id,
            $as_note ? 'system' : 'agent',
            $message,
            get_current_user_id(),
            $as_note ? 1 : 0
        );
        if (!is_array($created)) {
            return Lexi_Security::error('reply_failed', 'تعذر إرسال الرد حالياً.', 500);
        }

        $fields = array(
            'updated_at' => Lexi_Support::now(),
            'last_message_at' => Lexi_Support::now(),
        );
        if (!$as_note) {
            $fields['status'] = 'pending_customer';
            if (empty($ticket['first_response_at'])) {
                $fields['first_response_at'] = Lexi_Support::now();
            }
        }
        Lexi_Support::update_ticket($ticket_id, $fields);

        $latest = Lexi_Support::last_message_id($ticket_id, true);
        Lexi_Support::mark_view(
            $ticket_id,
            'admin',
            Lexi_Support::admin_viewer_key(get_current_user_id()),
            $latest
        );

        if (!$as_note && class_exists('Lexi_Push')) {
            $customer_user_id = (int) ($ticket['customer_user_id'] ?? 0);
            if ($customer_user_id > 0) {
                Lexi_Push::send_push_for_target(array(
                    'target' => 'specific_user',
                    'audience' => 'customer',
                    'user_id' => $customer_user_id,
                    'title_ar' => 'رد جديد على تذكرتك',
                    'body_ar' => 'تمت إضافة رد جديد من فريق الدعم.',
                    'type' => 'support_ticket_reply',
                    'open_mode' => 'in_app',
                    'deep_link' => '/support',
                    'priority' => 'high',
                    'extra_data' => array(
                        'ticket_id' => (string) $ticket_id,
                        'ticket_number' => (string) ($ticket['ticket_number'] ?? ''),
                    ),
                ));
            }
        }

        return Lexi_Security::success(array(
            'message' => $created,
            'status' => $as_note ? (string) $ticket['status'] : 'pending_customer',
            'status_label_ar' => Lexi_Support::status_label_ar($as_note ? (string) $ticket['status'] : 'pending_customer'),
        ), 201);
    }

    /**
     * POST /admin/support/tickets/{id}/note
     */
    public static function admin_note(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('id');
        $ticket = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }

        $body = (array) $request->get_json_params();
        $note = trim(sanitize_textarea_field((string) ($body['note'] ?? '')));
        if ('' === $note) {
            return Lexi_Security::error('note_required', 'ملاحظة داخلية مطلوبة.', 422);
        }

        $created = Lexi_Support::add_message(
            $ticket_id,
            'system',
            $note,
            get_current_user_id(),
            1
        );
        if (!is_array($created)) {
            return Lexi_Security::error('note_failed', 'تعذر حفظ الملاحظة.', 500);
        }

        Lexi_Support::update_ticket($ticket_id, array(
            'updated_at' => Lexi_Support::now(),
        ));

        $latest = Lexi_Support::last_message_id($ticket_id, true);
        Lexi_Support::mark_view(
            $ticket_id,
            'admin',
            Lexi_Support::admin_viewer_key(get_current_user_id()),
            $latest
        );

        return Lexi_Security::success(array('note' => $created), 201);
    }

    /**
     * PATCH /admin/support/tickets/{id}/assign
     */
    public static function admin_assign(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('id');
        $ticket = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }

        $body = (array) $request->get_json_params();
        $assigned_user_id = isset($body['assigned_user_id']) ? absint((int) $body['assigned_user_id']) : 0;
        if ($assigned_user_id > 0) {
            $user = get_user_by('id', $assigned_user_id);
            if (!$user) {
                return Lexi_Security::error('invalid_assignee', 'الموظف المحدد غير موجود.', 422);
            }
        }

        Lexi_Support::update_ticket($ticket_id, array(
            'assigned_user_id' => $assigned_user_id > 0 ? $assigned_user_id : null,
            'updated_at' => Lexi_Support::now(),
        ));

        $updated = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($updated)) {
            return Lexi_Security::error('update_failed', 'تعذر تحديث التذكرة.', 500);
        }

        $payload = Lexi_Support::normalize_ticket_payload($updated);
        $payload['assigned_agent'] = self::user_brief((int) $payload['assigned_user_id']);

        return Lexi_Security::success($payload);
    }

    /**
     * PATCH /admin/support/tickets/{id}
     */
    public static function admin_update_ticket(WP_REST_Request $request): WP_REST_Response
    {
        $ticket_id = (int) $request->get_param('id');
        $ticket = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }

        $body = (array) $request->get_json_params();
        $fields = array();

        if (isset($body['status'])) {
            $status = Lexi_Support::normalize_status((string) $body['status']);
            $fields['status'] = $status;
            if ('resolved' === $status) {
                $fields['resolved_at'] = Lexi_Support::now();
            }
            if ('closed' === $status) {
                $fields['closed_at'] = Lexi_Support::now();
            }
            if (in_array($status, array('open', 'pending_admin', 'pending_customer', 'in_progress'), true)) {
                $fields['resolved_at'] = null;
                $fields['closed_at'] = null;
            }
        }
        if (isset($body['priority'])) {
            $fields['priority'] = Lexi_Support::normalize_priority((string) $body['priority']);
        }
        if (isset($body['category'])) {
            $fields['category'] = Lexi_Support::normalize_category((string) $body['category']);
        }
        if (isset($body['tags'])) {
            $fields['tags'] = self::sanitize_tags((string) $body['tags']);
        }

        if (empty($fields)) {
            return Lexi_Security::error('missing_fields', 'لا يوجد حقول للتحديث.', 422);
        }

        $fields['updated_at'] = Lexi_Support::now();
        $ok = Lexi_Support::update_ticket($ticket_id, $fields);
        if (!$ok) {
            return Lexi_Security::error('update_failed', 'تعذر تحديث التذكرة.', 500);
        }

        $updated = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($updated)) {
            return Lexi_Security::error('update_failed', 'تعذر تحديث التذكرة.', 500);
        }

        $payload = Lexi_Support::normalize_ticket_payload($updated);
        $payload = Lexi_Support::with_sla_flags($payload);
        $payload['assigned_agent'] = self::user_brief((int) $payload['assigned_user_id']);

        return Lexi_Security::success($payload);
    }

    /**
     * GET /admin/support/canned
     */
    public static function admin_get_canned(WP_REST_Request $request): WP_REST_Response
    {
        $items = Lexi_Support::get_canned_replies();
        return Lexi_Security::success(array('items' => $items));
    }

    /**
     * POST /admin/support/canned
     */
    public static function admin_save_canned(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $existing = Lexi_Support::get_canned_replies();

        if (isset($body['items']) && is_array($body['items'])) {
            $saved = Lexi_Support::save_canned_replies(array_map('strval', $body['items']));
            return Lexi_Security::success(array(
                'message' => 'تم حفظ الردود الجاهزة.',
                'items' => $saved,
            ));
        }

        $text = trim(sanitize_textarea_field((string) ($body['text'] ?? '')));
        if ('' === $text) {
            return Lexi_Security::error('missing_text', 'نص الرد الجاهز مطلوب.', 422);
        }

        $existing[] = $text;
        $saved = Lexi_Support::save_canned_replies($existing);
        return Lexi_Security::success(array(
            'message' => 'تم حفظ الرد الجاهز.',
            'items' => $saved,
        ));
    }

    /**
     * GET /admin/support/analytics?range=7d|30d
     */
    public static function admin_analytics(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $range = strtolower(trim((string) $request->get_param('range')));
        if (!in_array($range, array('7d', '30d'), true)) {
            $range = '7d';
        }
        $days = ('30d' === $range) ? 30 : 7;
        $since = gmdate('Y-m-d H:i:s', time() - ($days * DAY_IN_SECONDS));

        $table = Lexi_Support::tickets_table();

        $open_count = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT COUNT(*) FROM {$table}
                 WHERE created_at >= %s
                 AND status NOT IN (%s, %s)",
                $since,
                'resolved',
                'closed'
            )
        );

        $avg_first_response = (float) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT AVG(TIMESTAMPDIFF(MINUTE, created_at, first_response_at))
                 FROM {$table}
                 WHERE created_at >= %s AND first_response_at IS NOT NULL",
                $since
            )
        );

        $avg_resolution = (float) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT AVG(TIMESTAMPDIFF(MINUTE, created_at, COALESCE(resolved_at, closed_at)))
                 FROM {$table}
                 WHERE created_at >= %s
                 AND (resolved_at IS NOT NULL OR closed_at IS NOT NULL)",
                $since
            )
        );

        $sla_breach = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT COUNT(*) FROM {$table}
                 WHERE created_at >= %s
                 AND (
                    (first_response_at IS NULL AND TIMESTAMPDIFF(MINUTE, created_at, NOW()) > sla_first_response_minutes)
                    OR
                    (status NOT IN (%s, %s)
                     AND resolved_at IS NULL
                     AND closed_at IS NULL
                     AND TIMESTAMPDIFF(MINUTE, created_at, NOW()) > sla_resolution_minutes)
                 )",
                $since,
                'resolved',
                'closed'
            )
        );

        $rating_average = (float) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT AVG(customer_rating)
                 FROM {$table}
                 WHERE created_at >= %s AND customer_rating IS NOT NULL",
                $since
            )
        );

        $category_rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT category, COUNT(*) AS total
                 FROM {$table}
                 WHERE created_at >= %s
                 GROUP BY category",
                $since
            ),
            ARRAY_A
        );
        $priority_rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT priority, COUNT(*) AS total
                 FROM {$table}
                 WHERE created_at >= %s
                 GROUP BY priority",
                $since
            ),
            ARRAY_A
        );

        return Lexi_Security::success(array(
            'range' => $range,
            'open_tickets_count' => $open_count,
            'avg_first_response_minutes' => round($avg_first_response, 2),
            'avg_resolution_minutes' => round($avg_resolution, 2),
            'sla_breach_count' => $sla_breach,
            'rating_average' => round($rating_average, 2),
            'tickets_by_category' => self::normalize_aggregate_rows($category_rows),
            'tickets_by_priority' => self::normalize_aggregate_rows($priority_rows),
            'generated_at' => Lexi_Support::now(),
        ));
    }

    /**
     * Validate a customer ticket/token pair.
     *
     * @return array<string, mixed>|WP_REST_Response
     */
    private static function validate_customer_ticket(int $ticket_id, string $token)
    {
        if ($ticket_id <= 0) {
            return Lexi_Security::error('ticket_required', 'رقم التذكرة غير صالح.', 422);
        }
        if ('' === $token) {
            return Lexi_Security::error('token_required', 'رمز الوصول مطلوب.', 422);
        }

        $ticket = Lexi_Support::get_ticket($ticket_id);
        if (!is_array($ticket)) {
            return Lexi_Security::error('ticket_not_found', 'التذكرة غير موجودة.', 404);
        }
        if (!Lexi_Support::verify_chat_token($ticket, $token)) {
            return Lexi_Security::error('access_denied', 'بيانات التذكرة غير صحيحة.', 403);
        }

        return $ticket;
    }

    /**
     * Send admin notification for ticket events.
     *
     * @param array<string, mixed> $ticket
     */
    private static function notify_admin_activity(array $ticket, string $subject, string $summary): void
    {
        $ticket_number = (string) ($ticket['ticket_number'] ?? '');
        $name = (string) ($ticket['name'] ?? '');
        $phone = (string) ($ticket['phone'] ?? '');
        $topic = (string) ($ticket['subject'] ?? '');

        $html = sprintf(
            '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;line-height:1.9;">' .
            '<p><strong>%s</strong></p>' .
            '<p>%s</p>' .
            '<p>رقم التذكرة: <strong>%s</strong></p>' .
            '<p>العميل: %s - %s</p>' .
            '<p>الموضوع: %s</p>' .
            '</div>',
            esc_html($subject),
            esc_html($summary),
            esc_html($ticket_number),
            esc_html($name),
            esc_html($phone),
            esc_html($topic)
        );

        Lexi_Support::notify_admin($subject . ' - ' . $ticket_number, $html);
    }

    /**
     * @return array<string, mixed>|null
     */
    private static function user_brief(int $user_id): ?array
    {
        if ($user_id <= 0) {
            return null;
        }

        $user = get_user_by('id', $user_id);
        if (!$user) {
            return null;
        }

        return array(
            'id' => (int) $user->ID,
            'name' => (string) $user->display_name,
            'email' => (string) $user->user_email,
        );
    }

    private static function bool_value($value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return (int) $value === 1;
        }
        $value = strtolower(trim((string) $value));
        return in_array($value, array('1', 'true', 'yes', 'on'), true);
    }

    private static function sanitize_tags(string $value): string
    {
        $parts = explode(',', $value);
        $items = array();

        foreach ($parts as $part) {
            $item = trim(sanitize_text_field($part));
            if ('' === $item) {
                continue;
            }
            $items[] = $item;
        }

        $items = array_values(array_unique($items));
        return implode(',', $items);
    }

    /**
     * @param mixed $rows
     * @return array<int, array<string, mixed>>
     */
    private static function normalize_aggregate_rows($rows): array
    {
        if (!is_array($rows)) {
            return array();
        }

        $out = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }
            $label = '';
            $value = '';
            if (isset($row['category'])) {
                $value = (string) $row['category'];
                $label = Lexi_Support::category_label_ar($value);
            } elseif (isset($row['priority'])) {
                $value = (string) $row['priority'];
                $label = Lexi_Support::priority_label_ar($value);
            }

            $out[] = array(
                'key' => $value,
                'label_ar' => $label,
                'count' => (int) ($row['total'] ?? 0),
            );
        }
        return $out;
    }
}
