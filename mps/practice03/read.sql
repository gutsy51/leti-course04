-- =============== GET FUNCTIONS ===============

-- Возвращает параметры всех изделий в виде таблицы.
/*
    Вход:
        p_product_id (integer): ID изделия (если NULL — все изделия).
    Выход:
        Таблица с полями:
            product_code, product_name,
            parameter_name, parameter_display_name,
            value, unit.
    Эффекты:
        Чтение данных из product_parameter, parameter, products, measure.
    Требования:
        Если указан p_product_id, он должен существовать.
*/
CREATE OR REPLACE FUNCTION get_product_parameters(
    p_product_id integer DEFAULT NULL
) RETURNS TABLE (
    product_code text,
    product_name text,
    parameter_name text,
    parameter_display_name text,
    value text,
    unit text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pr.code::text,
        pr.name::text,
        p.name::text,
        p.display_name::text,
        COALESCE(
            pp.value_int::text,
            pp.value_real::text,
            pp.value_str,
            ev.display_name
        ) AS value,
        m.name_short::text AS unit
    FROM product_parameter pp
    JOIN products pr ON pr.id = pp.product_id
    JOIN parameter p ON p.id = pp.parameter_id
    JOIN measure m ON m.id = p.measure_id
    LEFT JOIN enum_value ev ON ev.id = pp.value_enum
    WHERE p_product_id IS NULL OR pp.product_id = p_product_id
    ORDER BY pr.code, p.name;

    IF NOT FOUND AND p_product_id IS NOT NULL THEN
        RAISE NOTICE 'Изделие % не найдено или не имеет параметров', p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Возвращает параметры классов изделий.
/*
    Вход:
        p_class_id (integer): ID класса (если NULL — все классы).
    Выход:
        Таблица с полями:
            class_name, class_display_name,
            parameter_name, parameter_display_name,
            min_value, max_value, is_required, unit.
    Эффекты:
        Чтение данных из class_parameter, parameter, class, measure.
    Требования:
        Если указан p_class_id, он должен существовать.
*/
CREATE OR REPLACE FUNCTION get_class_parameters(
    p_class_id integer DEFAULT NULL
) RETURNS TABLE (
    class_name text,
    class_display_name text,
    parameter_name text,
    parameter_display_name text,
    min_value real,
    max_value real,
    is_required boolean,
    unit text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name::text,
        c.display_name::text,
        p.name::text,
        p.display_name::text,
        cp.min_value,
        cp.max_value,
        cp.is_required,
        m.name_short::text AS unit
    FROM class_parameter cp
    JOIN class c ON c.id = cp.class_id
    JOIN parameter p ON p.id = cp.parameter_id
    JOIN measure m ON m.id = p.measure_id
    WHERE p_class_id IS NULL OR cp.class_id = p_class_id
    ORDER BY c.name, p.name;

    IF NOT FOUND AND p_class_id IS NOT NULL THEN
        RAISE NOTICE 'Класс % не найден или не имеет параметров', p_class_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Возвращает содержимое заказа с параметрами изделий.
/*
    Вход:
        p_order_id (integer): ID заказа.
    Выход:
        Таблица с полями:
            order_id, created_at, status,
            product_code, product_name, quantity,
            param_name, param_value, param_unit.
    Эффекты:
        Чтение данных из orders, order_pos, products, product_parameter, parameter, measure.
    Требования:
        Заказ с указанным ID должен существовать.
*/
CREATE OR REPLACE FUNCTION get_order_contents(
    p_order_id integer
) RETURNS TABLE (
    order_id integer,
    created_at timestamp,
    status text,
    product_code text,
    product_name text,
    quantity numeric(18,6),
    param_name text,
    param_value text,
    param_unit text
) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id) THEN
        RAISE EXCEPTION 'Заказ % не существует', p_order_id;
    END IF;

    RETURN QUERY
    SELECT
        o.id::integer,
        o.created_at,
        o.status,
        pr.code::text,
        pr.name::text,
        op.quantity,
        p.name::text,
        COALESCE(
            pp.value_int::text,
            pp.value_real::text,
            pp.value_str,
            ev.display_name
        ) AS param_value,
        m.name_short::text
    FROM orders o
    JOIN order_pos op ON op.order_id = o.id
    JOIN products pr ON pr.id = op.product_id
    LEFT JOIN product_parameter pp ON pp.product_id = pr.id
    LEFT JOIN parameter p ON p.id = pp.parameter_id
    LEFT JOIN measure m ON m.id = p.measure_id
    LEFT JOIN enum_value ev ON ev.id = pp.value_enum
    WHERE o.id = p_order_id
    ORDER BY pr.code, p.name;

    IF NOT FOUND THEN
        RAISE NOTICE 'Заказ % пуст', p_order_id;
    END IF;
END;
$$ LANGUAGE plpgsql;