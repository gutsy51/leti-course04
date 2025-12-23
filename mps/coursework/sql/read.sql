-- Возвращает полную маршрутную карту технологического процесса для изделия.
/*
    Вход:
        p_product_id (integer): ID изделия.
    Выход:
        Таблица с полями:
            pos (integer) - порядковый номер операции,
            op_id (integer) - ID операции,
            op_class_name (text) - тип операции,
            gwc_name (text) - наименование ГРЦ,
            entity_name (text) - подразделение,
            work_time (real) - время операции,
            qualification (text) - квалификация.
    Эффекты:
        Чтение данных.
    Требования:
        Изделие должно существовать.
*/
CREATE OR REPLACE FUNCTION get_route_map(p_product_id integer)
RETURNS TABLE (
    pos integer,
    op_id integer,
    op_class_name text,
    gwc_name text,
    entity_name text,
    work_time real,
    qualification text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.pos,
        t.id AS op_id,
        c_op.display_name AS op_class_name,
        g.display_name AS gwc_name,
        be.display_name AS entity_name,
        t.work_time,
        ev.display_name AS qualification
    FROM tech_op t
    JOIN class c_op ON t.op_class_id = c_op.id
    JOIN gwc g ON t.gwc_id = g.id
    JOIN business_entity be ON g.entity_id = be.id
    LEFT JOIN enum_value ev ON t.qualification_id = ev.id
    WHERE t.product_id = p_product_id
    ORDER BY t.pos;

    IF NOT FOUND THEN
        RAISE NOTICE 'Для изделия % не найдено операций', p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql

-- Возвращает суммарные затраты ресурсов на производство изделия.
/*
    Вход:
        p_product_id (integer): ID изделия.
    Выход:
        Таблица с полями:
            product_id (integer) - ID материала,
            product_code (text) - код материала,
            product_name (text) - наименование,
            total_quantity (numeric) - общее количество,
            unit (text) - единица измерения.
    Эффекты:
        Чтение данных из BOM и входных ресурсов.
    Требования:
        Изделие должно существовать.
*/
CREATE OR REPLACE FUNCTION calculate_material_costs(p_product_id integer)
RETURNS TABLE (
    product_id integer,
    product_code text,
    product_name text,
    total_quantity numeric(18,6),
    unit text
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE
        -- Строим BOM изделия с учетом вложенности
        bom_tree AS (
            SELECT
                b.child_id,
                b.quantity::numeric(18,6),
                1 AS level
            FROM bom b
            WHERE b.parent_id = p_product_id

            UNION ALL

            SELECT
                b.child_id,
                (bt.quantity * b.quantity)::numeric(18,6),
                bt.level + 1
            FROM bom b
            JOIN bom_tree bt ON b.parent_id = bt.child_id
        ),
        -- Добавляем входные ресурсы технологических операций
        op_resources AS (
            SELECT
                ir.product_id AS res_product_id,
                SUM(ir.in_quantity) AS total_input_qty
            FROM tech_op t
            JOIN input_resource ir ON ir.out_to_id = t.id
            WHERE t.product_id = p_product_id
            GROUP BY ir.product_id
        ),
        -- Объединяем все затраты: BOM + входные ресурсы
        all_costs AS (
            SELECT child_id AS product_id, SUM(quantity) AS qty FROM bom_tree GROUP BY child_id
            UNION ALL
            SELECT res_product_id, total_input_qty AS qty FROM op_resources
        )
    SELECT
        p.id::integer,
        p.code::text,
        p.name::text,
        SUM(ac.qty)::numeric(18,6),
        m.name_short::text
    FROM all_costs ac
    JOIN products p ON p.id = ac.product_id
    JOIN measure m ON m.id = p.measure_id
    GROUP BY p.id, p.code, p.name, m.name_short
    ORDER BY p.code;
END;
$$ LANGUAGE plpgsql
