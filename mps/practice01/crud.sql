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
    p_measure_id integer,
    p_modification_id integer DEFAULT NULL,
    p_change_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    INSERT INTO products (code, name, measure_id, modification_id, change_id)
    VALUES (p_code, p_name, p_measure_id, p_modification_id, p_change_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_product(
    p_id integer,
    p_code text,
    p_name text,
    p_measure_id integer,
    p_modification_id integer DEFAULT NULL,
    p_change_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    UPDATE products
    SET code = p_code,
        name = p_name,
        measure_id = p_measure_id,
        modification_id = p_modification_id,
        change_id = p_change_id
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


-- Создаёт модификацию изделия.
/*
    Добавляет новую запись в таблицу products, представляющую модификацию существующего изделия.

    Вход:
        p_base_id (integer): ID базового изделия, от которого создаётся модификация,
        p_code (text): код модификации,
        p_name (text): название модификации,
        p_measure_id (integer, опционально): единица измерения. Если не указано, может быть NULL.
    Выход:
        integer: ID созданной модификации.
    Эффекты:
        Добавление строки в таблицу products с ссылкой на базовое изделие.
    Требования:
        Базовое изделие с указанным p_base_id должно существовать.
*/
CREATE OR REPLACE FUNCTION create_modification(
    p_base_id integer,
    p_code text,
    p_name text,
    p_measure_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Базовое изделие % не существует', p_base_id;
    END IF;

    INSERT INTO products (code, name, measure_id, modification_id)
    VALUES (p_code, p_name, p_measure_id, p_base_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- Создаёт изменение изделия.
/*
    Добавляет новую запись в таблицу products, представляющую изменение (change) существующего изделия.

    Вход:
        p_base_id (integer): ID изделия или модификации, от которого создаётся изменение,
        p_code (text): код изменения,
        p_name (text): название изменения,
        p_measure_id (integer, опционально): единица измерения. Если не указано, может быть NULL.
    Выход:
        integer: ID созданного изменения.
    Эффекты:
        Добавление строки в таблицу products с ссылкой на родительское изделие/модификацию.
    Требования:
        Базовое изделие или модификация с указанным p_base_id должны существовать.
*/

CREATE OR REPLACE FUNCTION create_change(
    p_base_id integer,
    p_code text,
    p_name text,
    p_measure_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Базовое изделие или модификация % не существует', p_base_id;
    END IF;

    INSERT INTO products (code, name, measure_id, change_id)
    VALUES (p_code, p_name, p_measure_id, p_base_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;



-- =============== BOM ===============

-- Создать связь составного изделия (строку BOM).
/*
    Добавляет строку в таблицу BOM (Bill of Materials).

    Вход:
        p_parent_id (integer): ID изделия, которому добавляется компонент,
        p_child_id (integer): ID добавляемого компонента,
        p_qty (numeric): количество компонента,
    Выход:
        void.
    Эффекты:
        Проверка на циклические зависимости в спецификации,
        Добавление строки в таблицу bom.
    Требования:
        Оба изделия (родитель и дочерний компонент) должны существовать в таблице products,
        Добавление компонента не должно создавать цикл в структуре изделия.
*/
CREATE OR REPLACE FUNCTION add_bom_item(
    p_parent_id integer,
    p_child_id integer,
    p_qty numeric
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_parent_id) THEN
        RAISE EXCEPTION 'Родительское изделие % не существует', p_parent_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_child_id) THEN
        RAISE EXCEPTION 'Компонент % не существует', p_child_id;
    END IF;

    INSERT INTO bom (parent_id, child_id, quantity)
    VALUES (p_parent_id, p_child_id, p_qty);
END;
$$ LANGUAGE plpgsql;


-- Обновляет запись компонента в изделии (BOM).
/*
    Изменяет все атрибуты существующей записи BOM.

    Вход:
        p_parent_id (integer): ID родительского изделия,
        p_child_id (integer): ID компонента,
        p_quantity (numeric): новое количество (>0).
    Выход:
        void.
    Эффекты:
        Обновляется вся строка в таблице bom.
    Требования:
        Запись (parent_id, child_id) должна существовать.
*/
CREATE OR REPLACE FUNCTION update_bom_item(
    p_parent_id integer,
    p_child_id integer,
    p_qty numeric
) RETURNS void AS
$$
BEGIN
    PERFORM check_bom_cycle(p_parent_id, p_child_id);

    UPDATE bom
    SET quantity = p_qty
    WHERE parent_id = p_parent_id AND child_id = p_child_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Компонент % в изделии % не найден', p_child_id, p_parent_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Удаляет компонент из BOM.
/*
    Удаляет строку из таблицы bom.

    Вход:
        p_parent_id (integer): ID родительского изделия,
        p_child_id (integer): ID компонента.
    Выход:
        void.
    Эффекты:
        Строка удаляется из таблицы bom.
    Требования:
        Запись (parent_id, child_id) должна существовать.
*/
CREATE OR REPLACE FUNCTION delete_bom_item(
    p_parent_id integer,
    p_child_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM bom
    WHERE parent_id = p_parent_id AND child_id = p_child_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Компонент % в изделии % не найден', p_child_id, p_parent_id;
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
        SET_OF (child_id, child_name, qty).
    Эффекты:
        Нет (чтение).
    Требования:
        parent_id может не существовать — вернёт пустой результат.
*/
CREATE OR REPLACE FUNCTION get_bom_children(p_parent_id integer)
RETURNS TABLE (
    child_id int,
    child_name text,
    qty numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.child_id,
        p.name,
        b.quantity
    FROM bom b
    JOIN products p ON p.id = b.child_id
    WHERE b.parent_id = p_parent_id;
END; $$ LANGUAGE plpgsql;


-- Получить дерево изделия (все уровни вложенности).
/*
    Рекурсивно возвращает полную структуру изделия.

    Вход:
        p_root (integer): ID корневого изделия.
    Выход:
        SET_OF (level, parent_id, child_id, child_name, qty).
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
    qty numeric
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE t AS (
        SELECT 1 AS level,
               b.parent_id,
               b.child_id,
               p.name,
               b.quantity
        FROM bom b
        JOIN products p ON p.id = b.child_id
        WHERE b.parent_id = p_root

        UNION ALL

        SELECT t.level + 1,
               b.parent_id,
               b.child_id,
               p.name,
               b.quantity
        FROM bom b
        JOIN products p ON p.id = b.child_id
        JOIN t ON b.parent_id = t.child_id
    )
    SELECT * FROM t;
END; $$ LANGUAGE plpgsql;
