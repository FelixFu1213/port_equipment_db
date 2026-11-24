-- ============================================================
-- PostgreSQL 初始化脚本：视图 + 触发器
-- 由 init_db.py 在应用启动时自动执行（可重复执行）
-- ============================================================

-- ------------------------------------------------------------
-- 视图
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_inbound_outbound_summary;
DROP VIEW IF EXISTS v_equipment_category_stats;
DROP VIEW IF EXISTS v_equipment_usage;
DROP VIEW IF EXISTS v_billing_summary;
DROP VIEW IF EXISTS v_customer_rental_stats;
DROP VIEW IF EXISTS v_order_summary;
DROP VIEW IF EXISTS v_equipment_inventory;

-- 1. 设备库存统计视图
CREATE VIEW v_equipment_inventory AS
SELECT
    e.equipment_id,
    e.equipment_code,
    e.equipment_name,
    e.category,
    e.status::text AS status,
    e.storage_location,
    e.purchase_price,
    e.daily_rental_rate,
    e.supplier,
    e.manufacturer,
    e.purchase_date,
    e.warranty_date,
    e.last_maintenance_date,
    e.serial_number,
    e.specifications,
    e.created_at,
    e.updated_at,
    CASE WHEN e.status = 'IN_STOCK' THEN 1 ELSE 0 END AS available_quantity,
    CASE WHEN e.status = 'OUT' THEN 1 ELSE 0 END AS rented_quantity,
    CASE WHEN e.status = 'MAINTENANCE' THEN 1 ELSE 0 END AS maintenance_quantity,
    COALESCE(rental_stats.rental_count, 0)::int AS rental_count,
    COALESCE(rental_stats.total_rental_days, 0)::int AS total_rental_days,
    COALESCE(rental_stats.total_revenue, 0.0)::double precision AS total_revenue
FROM equipment e
LEFT JOIN (
    SELECT
        oi.equipment_id,
        COUNT(DISTINCT oi.order_id) AS rental_count,
        SUM(oi.rental_days) AS total_rental_days,
        SUM(oi.subtotal) AS total_revenue
    FROM order_items oi
    JOIN lease_orders lo ON oi.order_id = lo.order_id
    WHERE lo.is_deleted = 0
    GROUP BY oi.equipment_id
) rental_stats ON e.equipment_id = rental_stats.equipment_id
WHERE e.is_deleted = 0;

-- 2. 订单汇总视图
CREATE VIEW v_order_summary AS
SELECT
    lo.order_id,
    lo.order_code,
    lo.customer_id,
    lo.customer_name,
    c.contact_person,
    c.phone AS customer_phone,
    c.email AS customer_email,
    c.credit_rating,
    lo.voyage_no,
    lo.start_date,
    lo.expected_return_date,
    lo.actual_return_date,
    lo.status::text AS order_status,
    lo.total_amount,
    lo.created_by,
    lo.created_at,
    lo.updated_at,
    COALESCE(item_stats.equipment_count, 0)::int AS equipment_count,
    COALESCE(item_stats.total_rental_days, 0)::int AS total_rental_days,
    COALESCE(item_stats.avg_daily_rate, 0.0)::double precision AS avg_daily_rate,
    b.bill_id,
    b.bill_code,
    b.status::text AS billing_status,
    b.total_amount AS billing_amount,
    b.payment_method::text AS payment_method,
    b.paid_amount,
    rr.return_id,
    rr.return_code,
    rr.return_date,
    rr.inspection_status,
    rr.total_damage_fee
FROM lease_orders lo
LEFT JOIN customers c ON lo.customer_id = c.customer_id
LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS equipment_count,
        SUM(rental_days) AS total_rental_days,
        AVG(daily_rate) AS avg_daily_rate
    FROM order_items
    GROUP BY order_id
) item_stats ON lo.order_id = item_stats.order_id
LEFT JOIN billing b ON lo.order_id = b.order_id AND b.is_deleted = 0
LEFT JOIN return_records rr ON lo.order_id = rr.order_id
WHERE lo.is_deleted = 0;

-- 3. 客户租赁统计视图
CREATE VIEW v_customer_rental_stats AS
SELECT
    c.customer_id,
    c.customer_name,
    c.contact_person,
    c.phone,
    c.email,
    c.address,
    c.credit_rating,
    c.created_at,
    COALESCE(order_stats.total_orders, 0)::int AS total_orders,
    COALESCE(order_stats.completed_orders, 0)::int AS completed_orders,
    COALESCE(order_stats.in_progress_orders, 0)::int AS in_progress_orders,
    COALESCE(order_stats.pending_orders, 0)::int AS pending_orders,
    COALESCE(order_stats.total_amount, 0.0)::double precision AS total_rental_amount,
    COALESCE(order_stats.paid_amount, 0.0)::double precision AS paid_amount,
    COALESCE(order_stats.pending_amount, 0.0)::double precision AS pending_amount,
    COALESCE(order_stats.total_equipment_count, 0)::int AS total_equipment_count,
    order_stats.last_order_date,
    order_stats.last_order_code
FROM customers c
LEFT JOIN (
    SELECT
        lo.customer_id,
        COUNT(DISTINCT lo.order_id) AS total_orders,
        SUM(CASE WHEN lo.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN lo.status = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress_orders,
        SUM(CASE WHEN lo.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_orders,
        SUM(lo.total_amount) AS total_amount,
        SUM(COALESCE(b.paid_amount, 0)) AS paid_amount,
        SUM(CASE
            WHEN b.status IN ('PENDING', 'CONFIRMED') THEN COALESCE(b.total_amount, 0)
            ELSE 0
        END) AS pending_amount,
        SUM(oi_stats.equipment_count) AS total_equipment_count,
        MAX(lo.created_at) AS last_order_date,
        MAX(lo.order_code) AS last_order_code
    FROM lease_orders lo
    LEFT JOIN billing b ON lo.order_id = b.order_id AND b.is_deleted = 0
    LEFT JOIN (
        SELECT order_id, COUNT(*) AS equipment_count
        FROM order_items
        GROUP BY order_id
    ) oi_stats ON lo.order_id = oi_stats.order_id
    WHERE lo.is_deleted = 0
    GROUP BY lo.customer_id
) order_stats ON c.customer_id = order_stats.customer_id
WHERE c.is_deleted = 0;

-- 4. 财务汇总视图
CREATE VIEW v_billing_summary AS
SELECT
    b.bill_id,
    b.bill_code,
    b.order_id,
    lo.order_code,
    b.customer_name,
    c.customer_id,
    c.contact_person,
    c.phone AS customer_phone,
    c.email AS customer_email,
    b.rental_fee,
    b.repair_fee,
    b.other_fee,
    b.discount,
    b.total_amount,
    b.paid_amount,
    (b.total_amount - COALESCE(b.paid_amount, 0)) AS unpaid_amount,
    b.status::text AS billing_status,
    b.payment_method::text AS payment_method,
    b.invoice_no,
    b.billing_date,
    b.payment_date,
    b.remarks,
    b.created_at,
    b.updated_at,
    lo.voyage_no,
    lo.start_date,
    lo.expected_return_date,
    lo.actual_return_date,
    lo.status::text AS order_status,
    COALESCE(item_stats.equipment_count, 0)::int AS equipment_count,
    COALESCE(item_stats.total_rental_days, 0)::int AS total_rental_days
FROM billing b
LEFT JOIN lease_orders lo ON b.order_id = lo.order_id
LEFT JOIN customers c ON lo.customer_id = c.customer_id
LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS equipment_count,
        SUM(rental_days) AS total_rental_days
    FROM order_items
    GROUP BY order_id
) item_stats ON b.order_id = item_stats.order_id
WHERE b.is_deleted = 0;

-- 5. 设备使用情况视图
CREATE VIEW v_equipment_usage AS
SELECT
    e.equipment_id,
    e.equipment_code,
    e.equipment_name,
    e.category,
    e.status::text AS status,
    e.storage_location,
    e.purchase_price,
    e.daily_rental_rate,
    e.supplier,
    e.manufacturer,
    e.purchase_date,
    e.warranty_date,
    e.last_maintenance_date,
    e.created_at,
    COALESCE(usage_stats.rental_count, 0)::int AS rental_count,
    COALESCE(usage_stats.total_rental_days, 0)::int AS total_rental_days,
    COALESCE(usage_stats.total_revenue, 0.0)::double precision AS total_revenue,
    COALESCE(usage_stats.avg_rental_days, 0.0)::double precision AS avg_rental_days,
    usage_stats.last_rental_date,
    usage_stats.last_customer_name,
    COALESCE(maintenance_stats.maintenance_count, 0)::int AS maintenance_count,
    COALESCE(maintenance_stats.total_maintenance_cost, 0.0)::double precision AS total_maintenance_cost,
    CASE
        WHEN e.purchase_date IS NOT NULL AND (CURRENT_DATE - e.purchase_date) > 0 THEN
            ROUND(
                COALESCE(usage_stats.total_rental_days, 0)::numeric * 100.0
                / (CURRENT_DATE - e.purchase_date), 2
            )
        ELSE 0
    END AS utilization_rate
FROM equipment e
LEFT JOIN (
    SELECT
        oi.equipment_id,
        COUNT(DISTINCT oi.order_id) AS rental_count,
        SUM(oi.rental_days) AS total_rental_days,
        SUM(oi.subtotal) AS total_revenue,
        AVG(oi.rental_days) AS avg_rental_days,
        MAX(lo.created_at) AS last_rental_date,
        MAX(lo.customer_name) AS last_customer_name
    FROM order_items oi
    JOIN lease_orders lo ON oi.order_id = lo.order_id
    WHERE lo.is_deleted = 0
    GROUP BY oi.equipment_id
) usage_stats ON e.equipment_id = usage_stats.equipment_id
LEFT JOIN (
    SELECT
        equipment_id,
        COUNT(*) AS maintenance_count,
        SUM(maintenance_cost + parts_cost + labor_cost) AS total_maintenance_cost
    FROM maintenance_records
    WHERE is_deleted = 0
    GROUP BY equipment_id
) maintenance_stats ON e.equipment_id = maintenance_stats.equipment_id
WHERE e.is_deleted = 0;

-- 6. 入库出库汇总视图
CREATE VIEW v_inbound_outbound_summary AS
SELECT
    'inbound' AS record_type,
    ir.inbound_id AS record_id,
    ir.inbound_code AS record_code,
    ir.supplier,
    ir.purchase_date,
    ir.inbound_date AS operation_date,
    ir.operator,
    ir.total_quantity,
    ir.total_amount,
    ir.status::text AS status,
    ir.remarks,
    ir.created_at,
    COUNT(DISTINCT ii.item_id) AS item_count,
    string_agg(DISTINCT ii.equipment_name, ', ') AS equipment_names
FROM inbound_records ir
LEFT JOIN inbound_items ii ON ir.inbound_id = ii.inbound_id
WHERE ir.is_deleted = 0
GROUP BY ir.inbound_id, ir.inbound_code, ir.supplier, ir.purchase_date,
         ir.inbound_date, ir.operator, ir.total_quantity, ir.total_amount,
         ir.status, ir.remarks, ir.created_at

UNION ALL

SELECT
    'outbound' AS record_type,
    or_rec.outbound_id AS record_id,
    or_rec.outbound_code AS record_code,
    NULL AS supplier,
    NULL AS purchase_date,
    or_rec.outbound_date AS operation_date,
    or_rec.operator,
    or_rec.total_quantity,
    0.0::double precision AS total_amount,
    or_rec.status::text AS status,
    or_rec.remarks,
    or_rec.created_at,
    COUNT(DISTINCT oi.item_id) AS item_count,
    string_agg(DISTINCT oi.equipment_name, ', ') AS equipment_names
FROM outbound_records or_rec
LEFT JOIN outbound_items oi ON or_rec.outbound_id = oi.outbound_id
LEFT JOIN lease_orders lo ON or_rec.order_id = lo.order_id
WHERE or_rec.is_deleted = 0
GROUP BY or_rec.outbound_id, or_rec.outbound_code, or_rec.outbound_date,
         or_rec.operator, or_rec.total_quantity, or_rec.status,
         or_rec.remarks, or_rec.created_at;

-- 7. 设备类别统计视图
CREATE VIEW v_equipment_category_stats AS
SELECT
    e.category,
    COUNT(*)::int AS total_count,
    SUM(CASE WHEN e.status = 'IN_STOCK' THEN 1 ELSE 0 END)::int AS in_stock_count,
    SUM(CASE WHEN e.status = 'OUT' THEN 1 ELSE 0 END)::int AS out_stock_count,
    SUM(CASE WHEN e.status = 'MAINTENANCE' THEN 1 ELSE 0 END)::int AS maintenance_count,
    SUM(e.purchase_price) AS total_purchase_value,
    AVG(e.daily_rental_rate) AS avg_daily_rate,
    COALESCE(rental_stats.total_rental_count, 0)::int AS total_rental_count,
    COALESCE(rental_stats.total_revenue, 0.0)::double precision AS total_revenue
FROM equipment e
LEFT JOIN (
    SELECT
        e2.category,
        COUNT(DISTINCT oi.order_id) AS total_rental_count,
        SUM(oi.subtotal) AS total_revenue
    FROM equipment e2
    JOIN order_items oi ON e2.equipment_id = oi.equipment_id
    JOIN lease_orders lo ON oi.order_id = lo.order_id
    WHERE e2.is_deleted = 0 AND lo.is_deleted = 0
    GROUP BY e2.category
) rental_stats ON e.category = rental_stats.category
WHERE e.is_deleted = 0
GROUP BY e.category, rental_stats.total_rental_count, rental_stats.total_revenue;

-- ------------------------------------------------------------
-- 触发器
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_order_item_insert ON order_items;
DROP TRIGGER IF EXISTS trg_order_item_update ON order_items;
DROP TRIGGER IF EXISTS trg_order_item_delete ON order_items;
DROP TRIGGER IF EXISTS trg_order_created ON lease_orders;
DROP TRIGGER IF EXISTS trg_return_record_created ON return_records;
DROP TRIGGER IF EXISTS trg_inspection_record_created ON inspection_records;
DROP TRIGGER IF EXISTS trg_billing_before_insert ON billing;
DROP TRIGGER IF EXISTS trg_billing_before_update ON billing;
DROP TRIGGER IF EXISTS trg_billing_after_update ON billing;
DROP TRIGGER IF EXISTS trg_equipment_status_change ON equipment;
DROP TRIGGER IF EXISTS trg_outbound_record_created ON outbound_records;
DROP TRIGGER IF EXISTS trg_inbound_record_created ON inbound_records;

-- 1. 订单明细增删改：自动更新订单总金额并记录日志
CREATE OR REPLACE FUNCTION fn_order_item_total() RETURNS trigger AS $$
DECLARE
    v_order_id integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.order_id;
    ELSE
        v_order_id := NEW.order_id;
    END IF;

    UPDATE lease_orders
       SET total_amount = COALESCE(
               (SELECT SUM(subtotal) FROM order_items WHERE order_id = v_order_id),
               0.0
           ),
           updated_at = CURRENT_TIMESTAMP
     WHERE order_id = v_order_id;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
        VALUES ('success', '订单金额触发器', 'INSERT', 'order_items', NEW.item_id,
                format('订单明细插入，订单ID: %s，设备: %s，小计: ¥%s',
                       NEW.order_id, COALESCE(NEW.equipment_name, ''), NEW.subtotal),
                CURRENT_TIMESTAMP);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
        VALUES ('info', '订单金额触发器', 'UPDATE', 'order_items', NEW.item_id,
                format('订单明细更新，订单ID: %s，小计从 ¥%s 变更为 ¥%s',
                       NEW.order_id, OLD.subtotal, NEW.subtotal),
                CURRENT_TIMESTAMP);
    ELSE
        INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
        VALUES ('info', '订单金额触发器', 'DELETE', 'order_items', OLD.item_id,
                format('订单明细删除，订单ID: %s，设备: %s',
                       OLD.order_id, COALESCE(OLD.equipment_name, '')),
                CURRENT_TIMESTAMP);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_item_insert AFTER INSERT ON order_items
    FOR EACH ROW EXECUTE FUNCTION fn_order_item_total();
CREATE TRIGGER trg_order_item_update AFTER UPDATE ON order_items
    FOR EACH ROW EXECUTE FUNCTION fn_order_item_total();
CREATE TRIGGER trg_order_item_delete AFTER DELETE ON order_items
    FOR EACH ROW EXECUTE FUNCTION fn_order_item_total();

-- 2. 订单创建：写日志（此时订单明细尚未插入，设备状态在出库时更新）
CREATE OR REPLACE FUNCTION fn_order_created() RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('success', '订单创建触发器', 'INSERT', 'lease_orders', NEW.order_id,
            format('订单创建，订单号: %s，客户: %s，总金额: ¥%s',
                   NEW.order_code, NEW.customer_name, COALESCE(NEW.total_amount, 0)),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_created AFTER INSERT ON lease_orders
    FOR EACH ROW EXECUTE FUNCTION fn_order_created();

-- 3. 归还记录创建：写日志
CREATE OR REPLACE FUNCTION fn_return_record_created() RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('success', '归还记录触发器', 'INSERT', 'return_records', NEW.return_id,
            format('归还记录创建，归还单号: %s，订单ID: %s，设备数量: %s',
                   NEW.return_code, NEW.order_id, NEW.equipment_count),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_return_record_created AFTER INSERT ON return_records
    FOR EACH ROW EXECUTE FUNCTION fn_return_record_created();

-- 4. 质检记录创建：根据质检结果更新设备状态
CREATE OR REPLACE FUNCTION fn_inspection_record_created() RETURNS trigger AS $$
DECLARE
    v_status text;
BEGIN
    IF NEW.repair_needed = 1 OR NEW.function_test = '故障' THEN
        v_status := 'MAINTENANCE';
    ELSE
        v_status := 'IN_STOCK';
    END IF;

    UPDATE equipment
       SET status = v_status::equipmentstatus,
           updated_at = CURRENT_TIMESTAMP
     WHERE equipment_id = NEW.equipment_id
       AND is_deleted = 0;

    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('success', '质检记录触发器', 'INSERT', 'inspection_records', NEW.inspection_id,
            format('质检记录创建，设备: %s，质检结果: %s，设备状态更新为: %s',
                   NEW.equipment_code, COALESCE(NEW.result::text, ''), v_status),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inspection_record_created AFTER INSERT ON inspection_records
    FOR EACH ROW EXECUTE FUNCTION fn_inspection_record_created();

-- 5. 账单金额自动计算
CREATE OR REPLACE FUNCTION fn_billing_before_insert() RETURNS trigger AS $$
BEGIN
    IF NEW.total_amount IS NULL OR NEW.total_amount = 0 THEN
        NEW.total_amount := COALESCE(NEW.rental_fee, 0)
                          + COALESCE(NEW.repair_fee, 0)
                          + COALESCE(NEW.other_fee, 0)
                          - COALESCE(NEW.discount, 0);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_billing_before_insert BEFORE INSERT ON billing
    FOR EACH ROW EXECUTE FUNCTION fn_billing_before_insert();

CREATE OR REPLACE FUNCTION fn_billing_before_update() RETURNS trigger AS $$
BEGIN
    IF NEW.rental_fee IS DISTINCT FROM OLD.rental_fee
       OR NEW.repair_fee IS DISTINCT FROM OLD.repair_fee
       OR NEW.other_fee IS DISTINCT FROM OLD.other_fee
       OR NEW.discount IS DISTINCT FROM OLD.discount THEN
        NEW.total_amount := COALESCE(NEW.rental_fee, 0)
                          + COALESCE(NEW.repair_fee, 0)
                          + COALESCE(NEW.other_fee, 0)
                          - COALESCE(NEW.discount, 0);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_billing_before_update BEFORE UPDATE ON billing
    FOR EACH ROW EXECUTE FUNCTION fn_billing_before_update();

CREATE OR REPLACE FUNCTION fn_billing_after_update() RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('info', '账单更新触发器', 'UPDATE', 'billing', NEW.bill_id,
            format('账单更新，账单号: %s，总金额: ¥%s', NEW.bill_code, NEW.total_amount),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_billing_after_update AFTER UPDATE ON billing
    FOR EACH ROW EXECUTE FUNCTION fn_billing_after_update();

-- 6. 设备状态变更日志
CREATE OR REPLACE FUNCTION fn_equipment_status_change() RETURNS trigger AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
        VALUES ('info', '设备状态触发器', 'STATUS_CHANGE', 'equipment', NEW.equipment_id,
                format('设备状态变更，设备: %s (%s)，状态从 "%s" 变更为 "%s"',
                       NEW.equipment_name, NEW.equipment_code,
                       OLD.status::text, NEW.status::text),
                CURRENT_TIMESTAMP);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_equipment_status_change AFTER UPDATE ON equipment
    FOR EACH ROW EXECUTE FUNCTION fn_equipment_status_change();

-- 7. 出库记录创建：自动更新设备状态为已出库
CREATE OR REPLACE FUNCTION fn_outbound_record_created() RETURNS trigger AS $$
BEGIN
    UPDATE equipment e
       SET status = 'OUT',
           updated_at = CURRENT_TIMESTAMP
     WHERE e.equipment_id IN (
               SELECT oi.equipment_id FROM outbound_items oi
               WHERE oi.outbound_id = NEW.outbound_id
           )
       AND e.status = 'IN_STOCK'
       AND e.is_deleted = 0;

    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('success', '出库记录触发器', 'INSERT', 'outbound_records', NEW.outbound_id,
            format('出库记录创建，出库单号: %s，设备数量: %s',
                   NEW.outbound_code, NEW.total_quantity),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_outbound_record_created AFTER INSERT ON outbound_records
    FOR EACH ROW EXECUTE FUNCTION fn_outbound_record_created();

-- 8. 入库记录创建：自动更新设备状态为在库
CREATE OR REPLACE FUNCTION fn_inbound_record_created() RETURNS trigger AS $$
BEGIN
    UPDATE equipment e
       SET status = 'IN_STOCK',
           updated_at = CURRENT_TIMESTAMP
     WHERE e.equipment_id IN (
               SELECT ii.equipment_id FROM inbound_items ii
               WHERE ii.inbound_id = NEW.inbound_id
           )
       AND e.is_deleted = 0;

    INSERT INTO trigger_logs (log_type, trigger_name, operation, table_name, record_id, description, created_at)
    VALUES ('success', '入库记录触发器', 'INSERT', 'inbound_records', NEW.inbound_id,
            format('入库记录创建，入库单号: %s，供应商: %s，设备数量: %s',
                   NEW.inbound_code, COALESCE(NEW.supplier, '未知'), NEW.total_quantity),
            CURRENT_TIMESTAMP);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inbound_record_created AFTER INSERT ON inbound_records
    FOR EACH ROW EXECUTE FUNCTION fn_inbound_record_created();
