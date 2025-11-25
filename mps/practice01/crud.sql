-- =============== MEASURE ===============

-- Создаёт единицу измерения.
/*
    Добавляет новую запись в таблицу measure.

    Вход:
        p_name (text): полное название единицы измерения,
        p_short (text): краткое обозначение.
    Выход:
        integer: ID созданной единицы измерения.
    Эффекты:
        Добавление строки в таблицу measure.
    Требования:
        Названия должны быть уникальными.
*/
CREATE OR REPLACE FUNCTION create_measure(
    p_name text,
    p_short text
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    INSERT INTO measure(name, name_short)
    VALUES (p_name, p_short)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- Обновляет существующую единицу измерения.
/*
    Изменяет данные существующей записи таблицы measure.

    Вход:
        p_id (integer): ID изменяемой единицы измерения,
        p_name (text): новое название,
        p_short (text): новое краткое название.
    Выход:
        void.
    Эффекты:
        Модификация строки в таблице measure.
    Требования:
        Единица измерения с указанным ID должна существовать.
*/
CREATE OR REPLACE FUNCTION update_measure(
    p_id integer,
    p_name text,
    p_short text
) RETURNS void AS
$$
BEGIN
    UPDATE measure
    SET name = p_name,
        name_short = p_short
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Единицы измерения % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Удаляет единицу измерения.
/*
    Удаляет запись из таблицы measure.

    Вход:
        p_id (integer): ID удаляемой единицы измерения.
    Выход:
        void.
    Эффекты:
        Удаление строки из таблицы measure.
    Требования:
        Единица измерения должна существовать.
*/
CREATE OR REPLACE FUNCTION delete_measure(p_id integer)
RETURNS void AS
$$
BEGIN
    DELETE FROM measure WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Единицы измерения % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== PRODUCT ===============

-- Создаёт изделие.
/*
    Добавляет новую запись в таблицу products.

    Вход:
        p_code (text): код изделия,
        p_name (text): название изделия,
        p_measure_id (integer, опционально): единица измерения.
    Выход:
        integer: ID созданного изделия.
    Эффекты:
        Добавление строки в таблицу products.
    Требования:
        Название изделия не должно быть пустым,
        Код изделия должен быть уникальным,
        p_measure_id, если указан, должен ссылаться на существующую единицу измерения.
*/
CREATE OR REPLACE FUNCTION create_product(
    p_code text,
    p_name text,
    p_measure_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    INSERT INTO products (code, name, measure_id)
    VALUES (p_code, p_name, p_measure_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_product(
    p_id integer,
    p_code text,
    p_name text,
    p_measure_id integer
) RETURNS void AS
$$
BEGIN
    UPDATE products
    SET code = p_code,
        name = p_name,
        measure_id = p_measure_id
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Изделия % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_product(p_id integer)
RETURNS void AS
$$
BEGIN
    DELETE FROM products WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Изделия % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== PROPERTIES ===============

-- Добавляет свойство материала.
/*
    Добавляет новую запись в таблицу material_properties.

    Вход:
        p_product_id (integer): изделие, к которому относится свойство,
        p_name (text): название свойства,
        p_value (text): значение свойства.
    Выход:
        integer: ID созданного свойства.
    Эффекты:
        Добавление строки в таблицу material_properties.
    Требования:
        product_id должен ссылаться на существующее изделие.
*/
CREATE OR REPLACE FUNCTION add_property(
    p_product_id integer,
    p_name text,
    p_value text
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    INSERT INTO material_properties(product_id, property_name, property_value)
    VALUES (p_product_id, p_name, p_value)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- Обновляет свойство материала.
/*
    Изменяет существующую запись material_properties.

    Вход:
        p_id (integer): ID свойства,
        p_name (text): новое название,
        p_value (text): новое значение.
    Выход:
        void.
    Эффекты:
        Модификация строки таблицы material_properties.
    Требования:
        Свойство материала с таким ID должно существовать.
*/
CREATE OR REPLACE FUNCTION update_property(
    p_id integer,
    p_name text,
    p_value text
) RETURNS void AS
$$
BEGIN
    UPDATE material_properties
    SET property_name = p_name,
        property_value = p_value
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Свойства материала % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Удаляет свойство материала.
/*
    Удаляет запись из material_properties.

    Вход:
        p_id (integer): ID свойства.
    Выход:
        void.
    Эффекты:
        Удаление строки.
    Требования:
        Свойство с таким ID должно существовать.
*/
CREATE OR REPLACE FUNCTION delete_property(p_id integer)
RETURNS void AS
$$
BEGIN
    DELETE FROM material_properties WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Свойства материала % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== BOM ===============

-- Создать связь составного изделия (строку BOM).
/*
    Добавляет строку в таблицу BOM (Bill of Materials).

    Вход:
        p_parent_id (integer): ID изделия, которому добавляется компонент,
        p_child_id  (integer): ID добавляемого компонента,
        p_qty       (numeric): количество компонента,
        p_measure_id (integer): единица измерения количества.
    Выход:
        void.
    Эффекты:
        Проверка на циклические зависимости в спецификации,
        Добавление строки в таблицу bom.
    Требования:
        Оба изделия (родитель и дочерний компонент) должны существовать в таблице products,
        p_measure_id должен соответствовать допустимой единице измерения,
        Добавление компонента не должно создавать цикл в структуре изделия.
*/
CREATE OR REPLACE FUNCTION add_bom_item(
    p_parent_id integer,
    p_child_id integer,
    p_qty numeric,
    p_measure_id integer
) RETURNS void AS
$$
DECLARE
    exists_parent boolean;
    exists_child boolean;
BEGIN
    SELECT EXISTS(SELECT 1 FROM "products" WHERE id = p_parent_id)
    INTO exists_parent;

    SELECT EXISTS(SELECT 1 FROM "products" WHERE id = p_child_id)
    INTO exists_child;

    IF NOT exists_parent THEN
        RAISE EXCEPTION 'Изделие % не существует', p_parent_id;
    END IF;

    IF NOT exists_child THEN
        RAISE EXCEPTION 'Изделие % не существует', p_child_id;
    END IF;

    PERFORM check_bom_cycle(p_parent_id, p_child_id);

    INSERT INTO bom (parent_id, child_id, quantity, measure_id)
    VALUES (p_parent_id, p_child_id, p_qty, p_measure_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_bom_item(
    p_id integer,
    p_parent_id integer,
    p_child_id integer,
    p_qty numeric,
    p_measure_id integer
) RETURNS void AS
$$
BEGIN
    PERFORM check_bom_cycle(p_parent_id, p_child_id);

    UPDATE bom
    SET parent_id = p_parent_id,
        child_id = p_child_id,
        quantity = p_qty,
        measure_id = p_measure_id
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Элемента BOM % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_bom_item(p_id integer)
RETURNS void AS
$$
BEGIN
    DELETE FROM bom WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Элемента BOM % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== READ ===============

-- Получить прямых потомков изделия.
/*
    Возвращает список дочерних компонентов изделия.

    Вход:
        p_parent_id (integer): ID изделия.
    Выход:
        SET_OF (child_id, child_name, qty, measure).
    Эффекты:
        Нет (чтение).
    Требования:
        parent_id может не существовать — вернёт пустой результат.
*/
CREATE OR REPLACE FUNCTION get_bom_children(p_parent_id integer)
RETURNS TABLE (
    child_id int,
    child_name text,
    qty numeric,
    measure text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.child_id,
        p.name,
        b.quantity,
        m.name_short
    FROM bom b
    JOIN products p ON p.id = b.child_id
    JOIN measure m ON m.id = b.measure_id
    WHERE b.parent_id = p_parent_id;
END; $$ LANGUAGE plpgsql;


-- Получить дерево изделия (все уровни вложенности).
/*
    Рекурсивно возвращает полную структуру изделия.

    Вход:
        p_root (integer): ID корневого изделия.
    Выход:
        SET_OF (level, parent_id, child_id, child_name, qty, measure).
    Эффекты:
        Нет (чтение).
    Требования:
        Корневой ID может не иметь детей — вернёт пустой набор.
*/
CREATE OR REPLACE FUNCTION get_bom_tree(p_root int)
RETURNS TABLE (
    level int,
    parent_id int,
    child_id int,
    child_name text,
    qty numeric,
    measure text
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE t AS (
        SELECT 1 AS level,
               b.parent_id,
               b.child_id,
               p.name,
               b.quantity,
               m.name_short::text
        FROM bom b
        JOIN products p ON p.id = b.child_id
        JOIN measure m ON m.id = b.measure_id
        WHERE b.parent_id = p_root

        UNION ALL

        SELECT t.level + 1,
               b.parent_id,
               b.child_id,
               p.name,
               b.quantity,
               m.name_short::text
        FROM bom b
        JOIN products p ON p.id = b.child_id
        JOIN measure m ON m.id = b.measure_id
        JOIN t ON b.parent_id = t.child_id
    )
    SELECT * FROM t;
END; $$ LANGUAGE plpgsql;
