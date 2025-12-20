-- =============== CONFIG_RULE ===============

-- Создаёт новое правило конфигурации.
/*
    Добавляет запись в таблицу config_rule.

    Вход:
        p_name (text): название правила (внутреннее),
        p_description (text): описание правила.
    Выход:
        integer: ID созданного правила.
    Эффекты:
        Добавление строки в таблицу config_rule.
    Требования:
        Имя правила должно быть задано.
*/
CREATE OR REPLACE FUNCTION create_config_rule(
    p_name text,
    p_description text DEFAULT NULL
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Имя правила не может быть пустым';
    END IF;

    INSERT INTO config_rule (name, description)
    VALUES (p_name, p_description)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет правило конфигурации.
/*
    Изменяет имя и описание правила.

    Вход:
        p_id (integer): ID правила,
        p_name (text): новое имя,
        p_description (text): новое описание.
    Выход:
        void.
    Эффекты:
        Обновление строки в таблице config_rule.
    Требования:
        Правило с указанным ID должно существовать.
*/
CREATE OR REPLACE FUNCTION update_config_rule(
    p_id integer,
    p_name text,
    p_description text DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Имя правила не может быть пустым';
    END IF;

    UPDATE config_rule
    SET name = p_name,
        description = p_description
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Правило конфигурации % не существует', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Удаляет правило конфигурации.
/*
    Удаляет запись из таблицы config_rule.

    Вход:
        p_id (integer): ID правила.
    Выход:
        void.
    Эффекты:
        Удаление строки из config_rule.
    Требования:
        Правило должно существовать и не использоваться в таблице bom.
*/
CREATE OR REPLACE FUNCTION delete_config_rule(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM bom WHERE config_rule_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить правило %: оно используется в спецификациях', p_id;
    END IF;

    DELETE FROM config_rule WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Правило конфигурации % не найдено', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== RULE_PREDICATE ===============

-- Создаёт новое атомарное условие (предикат).
/*
    Добавляет условие "параметр = значение" в таблицу rule_predicate.

    Вход:
        p_parameter_id (integer): ID параметра,
        p_value_int, p_value_real, p_value_str, p_enum_value_id — значение (только одно не NULL),
        p_operator (text): оператор сравнения (=, !=, >, < и т.д.).
    Выход:
        integer: ID созданного предиката.
    Эффекты:
        Добавление строки в rule_predicate.
    Требования:
        parameter_id должен существовать,
        значение должно быть одного типа (только одно из value_...),
        оператор должен быть допустимым.
*/
CREATE OR REPLACE FUNCTION create_rule_predicate(
    p_parameter_id integer,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_str text DEFAULT NULL,
    p_enum_value_id integer DEFAULT NULL,
    p_operator text DEFAULT '='
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    -- Проверка существования параметра
    IF NOT EXISTS (SELECT 1 FROM parameter WHERE id = p_parameter_id) THEN
        RAISE EXCEPTION 'Параметр % не существует', p_parameter_id;
    END IF;

    -- Проверка оператора
    IF p_operator NOT IN ('=', '!=', '>', '<', '>=', '<=', 'IN') THEN
        RAISE EXCEPTION 'Недопустимый оператор: %', p_operator;
    END IF;

    -- Проверка, что только одно значение задано
    IF (CASE WHEN p_value_int IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_value_real IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_value_str IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_enum_value_id IS NOT NULL THEN 1 ELSE 0 END
       ) != 1 THEN
        RAISE EXCEPTION 'Должно быть указано ровно одно значение';
    END IF;

    -- Проверка enum_value_id, если используется
    IF p_enum_value_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM enum_value WHERE id = p_enum_value_id) THEN
        RAISE EXCEPTION 'Значение перечисления % не существует', p_enum_value_id;
    END IF;

    INSERT INTO rule_predicate (
        parameter_id,
        value_int, value_real, value_str, enum_value_id,
        operator
    ) VALUES (
        p_parameter_id,
        p_value_int, p_value_real, p_value_str, p_enum_value_id,
        p_operator
    ) RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет предикат.
CREATE OR REPLACE FUNCTION update_rule_predicate(
    p_id integer,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_str text DEFAULT NULL,
    p_enum_value_id integer DEFAULT NULL,
    p_operator text DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования
    IF NOT EXISTS (SELECT 1 FROM rule_predicate WHERE id = p_id) THEN
        RAISE EXCEPTION 'Предикат % не найден', p_id;
    END IF;

    -- Проверка оператора
    IF p_operator IS NOT NULL AND p_operator NOT IN ('=', '!=', '>', '<', '>=', '<=', 'IN') THEN
        RAISE EXCEPTION 'Недопустимый оператор: %', p_operator;
    END IF;

    -- Проверка, что только одно значение задано
    IF (CASE WHEN p_value_int IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_value_real IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_value_str IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN p_enum_value_id IS NOT NULL THEN 1 ELSE 0 END
       ) > 1 THEN
        RAISE EXCEPTION 'Нельзя указать более одного значения';
    END IF;

    -- Проверка enum_value_id
    IF p_enum_value_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM enum_value WHERE id = p_enum_value_id) THEN
        RAISE EXCEPTION 'Значение перечисления % не существует', p_enum_value_id;
    END IF;

    UPDATE rule_predicate SET
        value_int = COALESCE(p_value_int, value_int),
        value_real = COALESCE(p_value_real, value_real),
        value_str = COALESCE(p_value_str, value_str),
        enum_value_id = COALESCE(p_enum_value_id, enum_value_id),
        operator = COALESCE(p_operator, operator)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаляет предикат.
/*
    Удаляет атомарное условие.

    Вход:
        p_id (integer): ID предиката.
    Выход:
        void.
    Эффекты:
        Удаление строки из rule_predicate.
    Требования:
        Предикат не должен использоваться в rule_condition.
*/
CREATE OR REPLACE FUNCTION delete_rule_predicate(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM rule_condition WHERE predicate_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить предикат %: он используется в правилах', p_id;
    END IF;

    DELETE FROM rule_predicate WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Предикат % не найден', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== RULE_CONDITION ===============

-- Добавляет условие в правило.
/*
    Привязывает предикат к правилу с указанием порядка и логического оператора.

    Вход:
        p_rule_id (integer): ID правила,
        p_predicate_id (integer): ID предиката,
        p_order (integer): порядок проверки,
        p_logic_op (text): 'AND' или 'OR'.
    Выход:
        integer: ID созданной связи.
    Эффекты:
        Добавление строки в rule_condition.
    Требования:
        rule_id и predicate_id должны существовать.
*/
CREATE OR REPLACE FUNCTION add_rule_condition(
    p_rule_id integer,
    p_predicate_id integer,
    p_order integer DEFAULT 1,
    p_logic_op text DEFAULT 'AND'
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config_rule WHERE id = p_rule_id) THEN
        RAISE EXCEPTION 'Правило % не существует', p_rule_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM rule_predicate WHERE id = p_predicate_id) THEN
        RAISE EXCEPTION 'Предикат % не существует', p_predicate_id;
    END IF;

    IF p_logic_op NOT IN ('AND', 'OR') THEN
        RAISE EXCEPTION 'Логический оператор должен быть AND или OR';
    END IF;

    INSERT INTO rule_condition (rule_id, predicate_id, "order", logic_op)
    VALUES (p_rule_id, p_predicate_id, p_order, p_logic_op)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет условие в правиле.
CREATE OR REPLACE FUNCTION update_rule_condition(
    p_id integer,
    p_order integer DEFAULT NULL,
    p_logic_op text DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rule_condition WHERE id = p_id) THEN
        RAISE EXCEPTION 'Условие % не найдено', p_id;
    END IF;
    UPDATE rule_condition SET
        "order" = COALESCE(p_order, "order"),
        logic_op = COALESCE(p_logic_op, logic_op)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаляет условие из правила.
/*
    Удаляет связь между правилом и предикатом.

    Вход:
        p_id (integer): ID условия (rule_condition).
    Выход:
        void.
    Эффекты:
        Удаление строки из таблицы rule_condition.
    Требования:
        Условие с указанным ID должно существовать.
*/
CREATE OR REPLACE FUNCTION delete_rule_condition(p_id integer) RETURNS void AS
$$
BEGIN
    DELETE FROM rule_condition WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Условие % не найдено', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============== BOM (расширенный CRUD) ===============

-- Добавляет строку спецификации.
/*
    Добавляет компонент в состав изделия.

    Вход:
        p_parent_product_id (integer): ID изделия (сборки),
        p_child_product_id (integer): ID компонента,
        p_quantity (numeric): количество,
        p_config_rule_id (integer): ID правила включения (NULL — всегда включать).
    Выход:
        void.
    Эффекты:
        Добавление строки в таблицу bom.
    Требования:
        Оба продукта должны существовать,
        количество > 0,
        если указано правило — оно должно существовать.
*/
CREATE OR REPLACE FUNCTION add_bom_component(
    p_parent_product_id integer,
    p_child_product_id integer,
    p_quantity numeric,
    p_config_rule_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования изделий
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_parent_product_id) THEN
        RAISE EXCEPTION 'Изделие-родитель % не существует', p_parent_product_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_child_product_id) THEN
        RAISE EXCEPTION 'Компонент % не существует', p_child_product_id;
    END IF;

    -- Проверка количества
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть больше 0';
    END IF;

    -- Проверка правила
    IF p_config_rule_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM config_rule WHERE id = p_config_rule_id) THEN
        RAISE EXCEPTION 'Правило конфигурации % не существует', p_config_rule_id;
    END IF;

    INSERT INTO bom (parent_id, child_id, quantity, config_rule_id)
    VALUES (p_parent_product_id, p_child_product_id, p_quantity, p_config_rule_id)
    ON CONFLICT (parent_id, child_id, config_rule_id) DO UPDATE
    SET quantity = EXCLUDED.quantity;

END;
$$ LANGUAGE plpgsql;

-- Обновляет строку спецификации.
/*
    Изменяет количество или правило включения компонента.

    Вход:
        p_parent_product_id (integer),
        p_child_product_id (integer),
        p_quantity (numeric) — новое количество,
        p_config_rule_id (integer) — новое правило (может быть NULL).
    Выход:
        void.
    Эффекты:
        Обновление строки в bom.
    Требования:
        Строка должна существовать.
*/
CREATE OR REPLACE FUNCTION update_bom_component(
    p_parent_product_id integer,
    p_child_product_id integer,
    p_quantity numeric DEFAULT NULL,
    p_config_rule_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    IF p_quantity IS NULL AND p_config_rule_id IS NULL THEN
        RAISE EXCEPTION 'Не указаны поля для обновления';
    END IF;

    IF p_quantity IS NOT NULL AND p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть больше 0';
    END IF;

    IF p_config_rule_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM config_rule WHERE id = p_config_rule_id) THEN
        RAISE EXCEPTION 'Правило конфигурации % не существует', p_config_rule_id;
    END IF;

    UPDATE bom SET
        quantity = COALESCE(p_quantity, quantity),
        config_rule_id = COALESCE(p_config_rule_id, config_rule_id)
    WHERE parent_id = p_parent_product_id
      AND child_id = p_child_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Компонент % не найден в спецификации изделия %', p_child_product_id, p_parent_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Удаляет компонент из спецификации.
/*
    Удаляет строку из спецификации.

    Вход:
        p_parent_product_id (integer),
        p_child_product_id (integer).
    Выход:
        void.
    Эффекты:
        Удаление строки из bom.
    Требования:
        Строка должна существовать.
*/
CREATE OR REPLACE FUNCTION remove_bom_component(
    p_parent_product_id integer,
    p_child_product_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM bom
    WHERE parent_id = p_parent_product_id
      AND child_id = p_child_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Компонент % не найден в спецификации изделия %', p_child_product_id, p_parent_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;