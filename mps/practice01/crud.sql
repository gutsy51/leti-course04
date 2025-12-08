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


-- =============== CLASS ===============

-- Создаёт новый класс.
 /*
    Добавляет запись в таблицу class.

    Вход:
        p_name (text): внутреннее имя класса,
        p_display_name (text): отображаемое имя класса,
        p_parent_id (integer, опционально): родительский класс,
        p_measure_id (integer): единица измерения.
    Выход:
        integer: ID созданного класса.
    Эффекты:
        Добавляется новая запись в таблицу class.
    Требования:
        p_measure_id должен существовать в таблице measure,
        если указан p_parent_id — родительский класс должен существовать.
*/
CREATE OR REPLACE FUNCTION create_class(
    p_name text,
    p_display_name text,
    p_measure_id integer,
    p_parent_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    IF p_parent_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM class WHERE id = p_parent_id) THEN
        RAISE EXCEPTION 'Родительский класс % не существует', p_parent_id;
    END IF;

    INSERT INTO class (name, display_name, parent_id, measure_id)
    VALUES (p_name, p_display_name, p_parent_id, p_measure_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет существующий класс.
 /*
    Изменяет все атрибуты класса.

    Вход:
        p_id (integer): ID класса,
        p_name (text): новое внутреннее имя класса,
        p_display_name (text): новое отображаемое имя,
        p_measure_id (integer): новая единица измерения,
        p_parent_id (integer, опционально): новый родительский класс.
    Выход:
        void.
    Эффекты:
        Обновляет запись в таблице class.
    Требования:
        Класс с указанным p_id должен существовать,
        p_measure_id должен существовать,
        p_parent_id, если указан, должен существовать и не создавать циклических ссылок.
*/
CREATE OR REPLACE FUNCTION update_class(
    p_id integer,
    p_name text,
    p_display_name text,
    p_measure_id integer,
    p_parent_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    IF p_parent_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_parent_id) THEN
            RAISE EXCEPTION 'Родительский класс % не существует', p_parent_id;
        END IF;

        -- Проверка на цикл
        WITH RECURSIVE ancestors AS (
            SELECT id, parent_id FROM class WHERE id = p_parent_id
            UNION ALL
            SELECT c.id, c.parent_id
            FROM class c
            JOIN ancestors a ON c.id = a.parent_id
        )
        SELECT 1 FROM ancestors WHERE id = p_id;
        IF FOUND THEN
            RAISE EXCEPTION 'Нельзя установить родителем класс % — цикл', p_parent_id;
        END IF;
    END IF;

    UPDATE class
    SET name = p_name,
        display_name = p_display_name,
        measure_id = p_measure_id,
        parent_id = p_parent_id
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаляет класс.
 /*
    Удаляет класс из таблицы.

    Вход:
        p_id (integer): ID класса.
    Выход:
        void.
    Эффекты:
        Запись удаляется.
    Требования:
        Класс должен существовать,
        не должно быть дочерних классов.
*/
CREATE OR REPLACE FUNCTION delete_class(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM class WHERE parent_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить класс %, есть дочерние классы', p_id;
    END IF;

    DELETE FROM class WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Класс % не найден', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Получить список всех классов.
 /*
    Возвращает все классы.

    Выход:
        SET_OF (id, name, display_name, parent_id, measure_id).
*/
CREATE OR REPLACE FUNCTION get_classes()
RETURNS TABLE (
    id integer,
    name text,
    display_name text,
    parent_id integer,
    measure_id integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT id, name, display_name, parent_id, measure_id
    FROM class;
END; $$ LANGUAGE plpgsql;


-- =============== PRODUCT ===============

-- Создаёт изделие.
/*
    Добавляет новую запись в таблицу products.

    Вход:
        p_code (text): код изделия,
        p_name (text): название изделия,
        p_measure_id (integer): единица измерения,
        p_class_id (integer, опционально): класс изделия,
        p_modification_id (integer, опционально): родитель модификации,
        p_change_id (integer, опционально): родитель изменения.
    Выход:
        integer: ID созданного изделия.
    Эффекты:
        Добавление строки в таблицу products.
    Требования:
        Название изделия не должно быть пустым,
        Код изделия должен быть уникальным,
        p_measure_id должен существовать,
        p_class_id, если указан, должен существовать,
        p_modification_id, p_change_id, если указаны, должны существовать.
*/
CREATE OR REPLACE FUNCTION create_product(
    p_code text,
    p_name text,
    p_measure_id integer,
    p_class_id integer DEFAULT NULL,
    p_modification_id integer DEFAULT NULL,
    p_change_id integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF p_name IS NULL OR trim(p_name) = '' THEN
        RAISE EXCEPTION 'Название изделия не может быть пустым';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    IF p_class_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс изделия % не существует', p_class_id;
    END IF;

    IF p_modification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM products WHERE id = p_modification_id) THEN
        RAISE EXCEPTION 'Родитель модификации % не существует', p_modification_id;
    END IF;

    IF p_change_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM products WHERE id = p_change_id) THEN
        RAISE EXCEPTION 'Родитель изменения % не существует', p_change_id;
    END IF;

    INSERT INTO products (code, name, measure_id, class_id, modification_id, change_id)
    VALUES (p_code, p_name, p_measure_id, p_class_id, p_modification_id, p_change_id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- Обновляет существующее изделие.
/*
    Изменяет все атрибуты изделия.

    Вход:
        p_id (integer): ID изделия,
        p_code (text): новый код изделия,
        p_name (text): новое название,
        p_measure_id (integer): единица измерения,
        p_class_id (integer, опционально): класс изделия,
        p_modification_id (integer, опционально): родитель модификации,
        p_change_id (integer, опционально): родитель изменения.
    Выход:
        void.
    Эффекты:
        Обновляется запись в таблице products.
    Требования:
        Изделие с указанным p_id должно существовать,
        p_measure_id и p_class_id должны существовать, если указаны,
        p_modification_id и p_change_id должны существовать, если указаны.
*/
CREATE OR REPLACE FUNCTION update_product(
    p_id integer,
    p_code text,
    p_name text,
    p_measure_id integer,
    p_class_id integer DEFAULT NULL,
    p_modification_id integer DEFAULT NULL,
    p_change_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_id) THEN
        RAISE EXCEPTION 'Изделие % не существует', p_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    IF p_class_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс изделия % не существует', p_class_id;
    END IF;

    IF p_modification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM products WHERE id = p_modification_id) THEN
        RAISE EXCEPTION 'Родитель модификации % не существует', p_modification_id;
    END IF;

    IF p_change_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM products WHERE id = p_change_id) THEN
        RAISE EXCEPTION 'Родитель изменения % не существует', p_change_id;
    END IF;

    UPDATE products
    SET code = p_code,
        name = p_name,
        measure_id = p_measure_id,
        class_id = p_class_id,
        modification_id = p_modification_id,
        change_id = p_change_id
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;


-- Удаляет изделие.
/*
    Удаляет запись изделия из таблицы products.

    Вход:
        p_id (integer): ID изделия.
    Выход:
        void.
    Эффекты:
        Запись удаляется.
    Требования:
        Изделие должно существовать,
        не должно быть ссылок в BOM (parent_id или child_id),
        не должно быть дочерних модификаций или изменений.
*/
CREATE OR REPLACE FUNCTION delete_product(p_id integer)
RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM bom WHERE parent_id = p_id OR child_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить изделие %, оно используется в BOM', p_id;
    END IF;

    IF EXISTS (SELECT 1 FROM products WHERE modification_id = p_id OR change_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить изделие %, есть модификации или изменения', p_id;
    END IF;

    DELETE FROM products WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Изделие % не найдено', p_id;
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
