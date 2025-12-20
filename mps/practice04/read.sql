-- Возвращает список правил конфигурации.
/*
    Вход:
        p_rule_id (integer): ID правила (если NULL — все правила).
    Выход:
        Таблица с полями:
            rule_id, rule_name, rule_description,
            parameter_name, parameter_display_name,
            operator, value, enum_display_name.
    Эффекты:
        Чтение данных из config_rule, rule_condition, rule_predicate, parameter, enum_value.
    Требования:
        Если указан p_rule_id, он должен существовать.
*/
CREATE OR REPLACE FUNCTION get_config_rule(
    p_rule_id integer DEFAULT NULL
) RETURNS TABLE (
    rule_id integer,
    rule_name text,
    rule_description text,
    parameter_name text,
    parameter_display_name text,
    operator text,
    value text,
    enum_display_name text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cr.id::integer,
        cr.name::text,
        cr.description::text,
        par.name::text,
        par.display_name::text,
        rp.operator::text,
        COALESCE(
            rp.value_int::text,
            rp.value_real::text,
            rp.value_str
        ) AS value,
        ev.display_name::text
    FROM config_rule cr
    JOIN rule_condition rc ON rc.rule_id = cr.id
    JOIN rule_predicate rp ON rp.id = rc.predicate_id
    JOIN parameter par ON par.id = rp.parameter_id
    LEFT JOIN enum_value ev ON ev.id = rp.enum_value_id
    WHERE p_rule_id IS NULL OR cr.id = p_rule_id
    ORDER BY cr.id, rc."order";

    IF NOT FOUND AND p_rule_id IS NOT NULL THEN
        RAISE NOTICE 'Правило конфигурации % не найдено', p_rule_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Возвращает полную спецификацию изделия без проверки условий (вся вложенность).
/*
    Вход:
        p_product_id (integer): ID изделия.
    Выход:
        Таблица с полями:
            level (уровень вложенности),
            product_id, product_code, product_name,
            quantity (количество на уровень),
            unit (единица измерения),
            config_rule_id (если условный).
    Эффекты:
        Рекурсивное чтение BOM.
    Требования:
        Изделие должно существовать.
*/
CREATE OR REPLACE FUNCTION get_full_spec(
    p_product_id integer
) RETURNS TABLE (
    level integer,
    product_id integer,
    product_code text,
    product_name text,
    quantity numeric(18,6),
    unit text,
    config_rule_id integer
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE bom_tree AS (
        -- База: прямые компоненты
        SELECT
            b.child_id AS product_id,
            b.quantity::numeric(18,6),
            1 AS level,
            b.config_rule_id
        FROM bom b
        WHERE b.parent_id = p_product_id

        UNION ALL

        -- Рекурсия: вложенные компоненты
        SELECT
            b.child_id,
            (bt.quantity * b.quantity)::numeric(18,6),
            bt.level + 1,
            b.config_rule_id
        FROM bom b
        JOIN bom_tree bt ON b.parent_id = bt.product_id
    )
    SELECT
        bt.level::integer,
        pr.id::integer,
        pr.code::text,
        pr.name::text,
        bt.quantity,
        m.name_short::text,
        bt.config_rule_id::integer
    FROM bom_tree bt
    JOIN products pr ON pr.id = bt.product_id
    JOIN measure m ON m.id = pr.measure_id
    ORDER BY bt.level, pr.code;
END;
$$ LANGUAGE plpgsql;

-- Возвращает полную спецификацию изделия с проверкой условий.
/*
    Учитывает только те строки, для которых:
        - config_rule_id IS NULL (всегда включать), ИЛИ
        - config_rule_id ссылается на правило, все условия которого выполняются
          при заданных параметрах.

    Вход:
        p_product_id (integer): ID изделия,
        p_config_params JSONB: параметры конфигурации в формате
            { "param_name": "value", "diameter": 60, "temp": 501 }
            (где значение — int, real или enum_value_id).
    Выход:
        Таблица с полями:
            level, product_id, product_code, product_name, quantity, unit.
    Эффекты:
        Рекурсивное чтение BOM с фильтрацией по правилам.
    Требования:
        Изделие должно существовать.
*/
CREATE OR REPLACE FUNCTION get_full_spec_checked(
    p_product_id integer,
    p_config_params JSONB
) RETURNS TABLE (
    level integer,
    product_id integer,
    product_code text,
    product_name text,
    quantity numeric(18,6),
    unit text
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE bom_tree AS (
        SELECT
            b.child_id AS product_id,
            b.quantity::numeric(18,6),
            1 AS level,
            b.config_rule_id
        FROM bom b
        WHERE b.parent_id = p_product_id
          AND (b.config_rule_id IS NULL OR is_rule_satisfied(b.config_rule_id, p_config_params))

        UNION ALL

        SELECT
            b.child_id,
            (bt.quantity * b.quantity)::numeric(18,6),
            bt.level + 1,
            b.config_rule_id
        FROM bom b
        JOIN bom_tree bt ON b.parent_id = bt.product_id
        WHERE (b.config_rule_id IS NULL OR is_rule_satisfied(b.config_rule_id, p_config_params))
    )
    SELECT
        bt.level::integer,
        pr.id::integer,
        pr.code::text,
        pr.name::text,
        bt.quantity,
        m.name_short::text
    FROM bom_tree bt
    JOIN products pr ON pr.id = bt.product_id
    JOIN measure m ON m.id = pr.measure_id
    ORDER BY bt.level, pr.code;
END;
$$ LANGUAGE plpgsql;

-- Возвращает сводные нормы расхода по классам изделий.
/*
    Агрегирует компоненты из полной спецификации (с проверкой условий)
    по классам.

    Вход:
        p_product_id (integer): ID изделия,
        p_config_params JSONB: параметры конфигурации.
    Выход:
        Таблица с полями:
            class_name, class_display_name,
            total_quantity, unit.
    Эффекты:
        Чтение и агрегация BOM.
    Требования:
        Изделие должно существовать.
*/
CREATE OR REPLACE FUNCTION get_aggregated_bom(
    p_product_id integer,
    p_config_params JSONB
) RETURNS TABLE (
    class_name text,
    class_display_name text,
    total_quantity numeric(18,6),
    unit text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name::text,
        c.display_name::text,
        SUM(fs.quantity)::numeric(18,6),
        m.name_short::text
    FROM get_full_spec_checked(p_product_id, p_config_params) fs
    JOIN products pr ON pr.id = fs.product_id
    JOIN class c ON c.id = pr.class_id
    JOIN measure m ON m.id = pr.measure_id
    GROUP BY c.name, c.display_name, m.name_short
    ORDER BY c.name;
END;
$$ LANGUAGE plpgsql;
