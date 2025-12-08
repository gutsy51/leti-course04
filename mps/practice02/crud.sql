-- =============== ENUM ===============

-- Создаёт новое перечисление.
/*
    Добавляет запись в таблицу enum.

    Вход:
        p_name (text): внутреннее имя перечисления,
        p_display_name (text): отображаемое имя.
    Выход:
        integer: ID созданного перечисления.
    Эффекты:
        Добавление строки в таблицу enum.
    Требования:
        Имя должно быть уникальным.
*/
CREATE OR REPLACE FUNCTION create_enum(
    p_name text,
    p_display_name text
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    INSERT INTO enum (name, display_name)
    VALUES (p_name, p_display_name)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет перечисление.
/*
    Изменяет имя и отображаемое имя перечисления.

    Вход:
        p_id (integer): ID перечисления,
        p_name (text): новое имя,
        p_display_name (text): новое отображаемое имя.
    Выход:
        void.
    Эффекты:
        Обновление строки в таблице enum.
    Требования:
        Перечисление с указанным ID должно существовать.
*/
CREATE OR REPLACE FUNCTION update_enum(
    p_id integer,
    p_name text,
    p_display_name text
) RETURNS void AS
$$
BEGIN
    UPDATE enum
    SET name = p_name,
        display_name = p_display_name
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Перечисление % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Удаляет перечисление.
/*
    Удаляет запись из таблицы enum.

    Вход:
        p_id (integer): ID перечисления.
    Выход:
        void.
    Эффекты:
        Удаление строки в таблице enum.
    Требования:
        Перечисление должно существовать, не должно быть связанных значений.
*/
CREATE OR REPLACE FUNCTION delete_enum(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM enum_value WHERE enum_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить перечисление %, есть связанные значения', p_id;
    END IF;

    DELETE FROM enum WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Перечисление % не найдено', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== ENUM_VALUE ===============

-- Создаёт значение перечисления.
/*
    Добавляет значение в таблицу enum_value.

    Вход:
        p_enum_id (integer): ID перечисления,
        p_name (text), p_display_name (text): имя и отображаемое имя,
        p_value_int (integer), p_value_real (real), p_value_str (text), p_value_class (integer): значение.
    Выход:
        integer: ID созданного значения.
    Эффекты:
        Добавление строки в enum_value.
    Требования:
        enum_id должен существовать, значение должно быть одного типа.
*/
CREATE OR REPLACE FUNCTION create_enum_value(
    p_enum_id integer,
    p_name text,
    p_display_name text,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_str text DEFAULT NULL,
    p_value_class integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM enum WHERE id = p_enum_id) THEN
        RAISE EXCEPTION 'Перечисление % не существует', p_enum_id;
    END IF;

    INSERT INTO enum_value (
        enum_id, name, display_name,
        value_int, value_real, value_str, value_class
    ) VALUES (
        p_enum_id, p_name, p_display_name,
        p_value_int, p_value_real, p_value_str, p_value_class
    ) RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет значение перечисления.
CREATE OR REPLACE FUNCTION update_enum_value(
    p_id integer,
    p_name text,
    p_display_name text,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_str text DEFAULT NULL,
    p_value_class integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    UPDATE enum_value SET
        name = p_name,
        display_name = p_display_name,
        value_int = p_value_int,
        value_real = p_value_real,
        value_str = p_value_str,
        value_class = p_value_class
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Значение перечисления % не найдено', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Удаляет значение перечисления.
CREATE OR REPLACE FUNCTION delete_enum_value(p_id integer) RETURNS void AS
$$
BEGIN
    DELETE FROM enum_value WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Значение перечисления % не найдено', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== BUSINESS_ENTITY ===============

CREATE OR REPLACE FUNCTION create_business_entity(
    p_class_id integer,
    p_name text,
    p_display_name text,
    p_parent_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_class_id;
    END IF;

    IF p_parent_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM business_entity WHERE id = p_parent_id) THEN
        RAISE EXCEPTION 'Родительская сущность % не существует', p_parent_id;
    END IF;

    INSERT INTO business_entity (class_id, name, display_name, parent_id)
    VALUES (p_class_id, p_name, p_display_name, p_parent_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_business_entity(
    p_id integer,
    p_class_id integer,
    p_name text,
    p_display_name text,
    p_parent_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM business_entity WHERE id = p_id) THEN
        RAISE EXCEPTION 'Сущность % не существует', p_id;
    END IF;

    UPDATE business_entity SET
        class_id = p_class_id,
        name = p_name,
        display_name = p_display_name,
        parent_id = p_parent_id
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сущность % не найдена', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_business_entity(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM business_entity WHERE parent_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить сущность %, есть подчинённые', p_id;
    END IF;

    DELETE FROM business_entity WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сущность % не найдена', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== GWC ===============

CREATE OR REPLACE FUNCTION create_gwc(
    p_class_id integer,
    p_entity_id integer,
    p_name text,
    p_display_name text
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM business_entity WHERE id = p_entity_id) THEN
        RAISE EXCEPTION 'Сущность % не существует', p_entity_id;
    END IF;

    INSERT INTO gwc (class_id, entity_id, name, display_name)
    VALUES (p_class_id, p_entity_id, p_name, p_display_name)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_gwc(
    p_id integer,
    p_class_id integer,
    p_entity_id integer,
    p_name text,
    p_display_name text
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM gwc WHERE id = p_id) THEN
        RAISE EXCEPTION 'ГРЦ % не существует', p_id;
    END IF;

    UPDATE gwc SET
        class_id = p_class_id,
        entity_id = p_entity_id,
        name = p_name,
        display_name = p_display_name
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_gwc(p_id integer) RETURNS void AS
$$
BEGIN
    DELETE FROM gwc WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ГРЦ % не найден', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== TECH_OP ===============

CREATE OR REPLACE FUNCTION create_tech_op(
    p_product_id integer,
    p_pos integer,
    p_op_class_id integer,
    p_prof_class_id integer,
    p_gwc_id integer,
    p_qualification_id integer,
    p_work_time real
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Изделие % не существует', p_product_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_op_class_id) THEN
        RAISE EXCEPTION 'Класс операции % не существует', p_op_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_prof_class_id) THEN
        RAISE EXCEPTION 'Класс профессии % не существует', p_prof_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gwc WHERE id = p_gwc_id) THEN
        RAISE EXCEPTION 'ГРЦ % не существует', p_gwc_id;
    END IF;

    IF p_qualification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM enum_value WHERE id = p_qualification_id) THEN
        RAISE EXCEPTION 'Квалификация % не существует', p_qualification_id;
    END IF;

    INSERT INTO tech_op (
        product_id, pos, op_class_id, prof_class_id, gwc_id, qualification_id, work_time
    ) VALUES (
        p_product_id, p_pos, p_op_class_id, p_prof_class_id, p_gwc_id, p_qualification_id, p_work_time
    ) RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tech_op(
    p_id integer,
    p_product_id integer,
    p_pos integer,
    p_op_class_id integer,
    p_prof_class_id integer,
    p_gwc_id integer,
    p_qualification_id integer,
    p_work_time real
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tech_op WHERE id = p_id) THEN
        RAISE EXCEPTION 'Операция % не существует', p_id;
    END IF;

    UPDATE tech_op SET
        product_id = p_product_id,
        pos = p_pos,
        op_class_id = p_op_class_id,
        prof_class_id = p_prof_class_id,
        gwc_id = p_gwc_id,
        qualification_id = p_qualification_id,
        work_time = p_work_time
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_tech_op(p_id integer) RETURNS void AS
$$
BEGIN
    DELETE FROM tech_op WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Операция % не найдена', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== INPUT_RESOURCE ===============

CREATE OR REPLACE FUNCTION create_input_resource(
    p_in_to_id integer,
    p_out_to_id integer,
    p_product_id integer,
    p_in_quantity numeric,
    p_out_quantity numeric
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tech_op WHERE id = p_in_to_id) THEN
        RAISE EXCEPTION 'Операция in_to % не существует', p_in_to_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tech_op WHERE id = p_out_to_id) THEN
        RAISE EXCEPTION 'Операция out_to % не существует', p_out_to_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Продукт % не существует', p_product_id;
    END IF;

    INSERT INTO input_resource (
        in_to_id, out_to_id, product_id, in_quantity, out_quantity
    ) VALUES (
        p_in_to_id, p_out_to_id, p_product_id, p_in_quantity, p_out_quantity
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_input_resource(
    p_in_to_id integer,
    p_out_to_id integer,
    p_product_id integer,
    p_in_quantity numeric,
    p_out_quantity numeric
) RETURNS void AS
$$
BEGIN
    UPDATE input_resource SET
        in_quantity = p_in_quantity,
        out_quantity = p_out_quantity
    WHERE in_to_id = p_in_to_id
      AND out_to_id = p_out_to_id
      AND product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ресурс между операциями % -> % для продукта % не найден', p_out_to_id, p_in_to_id, p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_input_resource(
    p_in_to_id integer,
    p_out_to_id integer,
    p_product_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM input_resource
    WHERE in_to_id = p_in_to_id
      AND out_to_id = p_out_to_id
      AND product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ресурс между операциями % -> % для продукта % не найден', p_out_to_id, p_in_to_id, p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== GET ===============

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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;
