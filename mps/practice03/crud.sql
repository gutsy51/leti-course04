-- =============== PARAMETER ===============

-- Создаёт новый параметр.
/*
    Добавляет запись в таблицу parameter.

    Вход:
        p_class_id (integer): тип параметра (например, "Диаметр"),
        p_measure_id (integer): единица измерения,
        p_name (text): внутреннее имя,
        p_display_name (text): отображаемое имя.
    Выход:
        integer: ID созданного параметра.
    Эффекты:
        Добавление строки в parameter.
    Требования:
        Имя должно быть уникальным, класс и единица измерения должны существовать.
*/
CREATE OR REPLACE FUNCTION create_parameter(
    p_class_id integer,
    p_measure_id integer,
    p_name text,
    p_display_name text
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    IF EXISTS (SELECT 1 FROM parameter WHERE name = p_name) THEN
        RAISE EXCEPTION 'Параметр с именем % уже существует', p_name;
    END IF;

    INSERT INTO parameter (class_id, measure_id, name, display_name)
    VALUES (p_class_id, p_measure_id, p_name, p_display_name)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет параметр.
/*
    Изменяет данные параметра.

    Вход:
        p_id (integer): ID параметра,
        p_class_id (integer): новый тип,
        p_measure_id (integer): новая единица измерения,
        p_name (text): новое имя,
        p_display_name (text): новое отображаемое имя.
    Выход:
        void.
    Эффекты:
        Обновление строки в parameter.
    Требования:
        Параметр должен существовать, класс и единица измерения — существовать.
*/
CREATE OR REPLACE FUNCTION update_parameter(
    p_id integer,
    p_class_id integer,
    p_measure_id integer,
    p_name text,
    p_display_name text
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM parameter WHERE id = p_id) THEN
        RAISE EXCEPTION 'Параметр % не существует', p_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM measure WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения % не существует', p_measure_id;
    END IF;

    UPDATE parameter
    SET class_id = p_class_id,
        measure_id = p_measure_id,
        name = p_name,
        display_name = p_display_name
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаляет параметр.
/*
    Удаляет параметр, если он не используется.

    Вход:
        p_id (integer): ID параметра.
    Выход:
        void.
    Эффекты:
        Удаление строки из parameter.
    Требования:
        Параметр должен существовать и не использоваться в class_parameter или product_parameter.
*/
CREATE OR REPLACE FUNCTION delete_parameter(p_id integer) RETURNS void AS
$$
BEGIN
    IF EXISTS (SELECT 1 FROM class_parameter WHERE parameter_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить параметр %: используется в class_parameter', p_id;
    END IF;

    IF EXISTS (SELECT 1 FROM product_parameter WHERE parameter_id = p_id) THEN
        RAISE EXCEPTION 'Нельзя удалить параметр %: используется в product_parameter', p_id;
    END IF;

    DELETE FROM parameter WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Параметр % не найден', p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== CLASS_PARAMETER ===============

-- Добавляет параметр к классу.
/*
    Определяет, что класс изделий использует данный параметр.

    Вход:
        p_class_id (integer): ID класса,
        p_parameter_id (integer): ID параметра,
        p_min_value (real), p_max_value (real): диапазон значений,
        p_is_required (boolean): обязательность.
    Выход:
        void.
    Эффекты:
        Добавление/обновление записи в class_parameter.
    Требования:
        Класс и параметр должны существовать.
*/
CREATE OR REPLACE FUNCTION add_class_parameter(
    p_class_id integer,
    p_parameter_id integer,
    p_min_value real DEFAULT NULL,
    p_max_value real DEFAULT NULL,
    p_is_required boolean DEFAULT FALSE
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE id = p_class_id) THEN
        RAISE EXCEPTION 'Класс % не существует', p_class_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM parameter WHERE id = p_parameter_id) THEN
        RAISE EXCEPTION 'Параметр % не существует', p_parameter_id;
    END IF;

    INSERT INTO class_parameter (class_id, parameter_id, min_value, max_value, is_required)
    VALUES (p_class_id, p_parameter_id, p_min_value, p_max_value, p_is_required)
    ON CONFLICT (class_id, parameter_id) DO UPDATE SET
        min_value = EXCLUDED.min_value,
        max_value = EXCLUDED.max_value,
        is_required = EXCLUDED.is_required;
END;
$$ LANGUAGE plpgsql;

-- Удаляет параметр из класса.
/*
    Удаляет привязку параметра к классу.

    Вход:
        p_class_id (integer),
        p_parameter_id (integer).
    Выход:
        void.
    Эффекты:
        Удаление строки из class_parameter.
    Требования:
        Такая связь должна существовать.
*/
CREATE OR REPLACE FUNCTION remove_class_parameter(
    p_class_id integer,
    p_parameter_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM class_parameter
    WHERE class_id = p_class_id AND parameter_id = p_parameter_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Связь класса % и параметра % не найдена', p_class_id, p_parameter_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== PRODUCT_PARAMETER ===============

-- Устанавливает значение параметра для изделия.
/*
    Записывает значение параметра для конкретного изделия.

    Вход:
        p_product_id (integer),
        p_parameter_id (integer),
        p_value_int, p_value_real, p_value_str, p_value_enum: значение.
    Выход:
        void.
    Эффекты:
        Вставка или обновление в product_parameter.
    Требования:
        Изделие и параметр должны существовать.
        Только одно значение может быть не NULL.
*/
CREATE OR REPLACE FUNCTION set_product_parameter(
    p_product_id integer,
    p_parameter_id integer,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_str text DEFAULT NULL,
    p_value_enum integer DEFAULT NULL
) RETURNS void AS
$$
DECLARE
    value_count integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Изделие % не существует', p_product_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM parameter WHERE id = p_parameter_id) THEN
        RAISE EXCEPTION 'Параметр % не существует', p_parameter_id;
    END IF;

    -- Проверка: ровно одно значение
    value_count := (p_value_int IS NOT NULL)::int +
                   (p_value_real IS NOT NULL)::int +
                   (p_value_str IS NOT NULL)::int +
                   (p_value_enum IS NOT NULL)::int;

    IF value_count > 1 THEN
        RAISE EXCEPTION 'Можно задать только одно значение';
    END IF;

    INSERT INTO product_parameter (product_id, parameter_id, value_int, value_real, value_str, value_enum)
    VALUES (p_product_id, p_parameter_id, p_value_int, p_value_real, p_value_str, p_value_enum)
    ON CONFLICT (product_id, parameter_id) DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_real = EXCLUDED.value_real,
        value_str = EXCLUDED.value_str,
        value_enum = EXCLUDED.value_enum;
END;
$$ LANGUAGE plpgsql;

-- Удаляет значение параметра у изделия.
/*
    Удаляет запись из product_parameter.

    Вход:
        p_product_id (integer),
        p_parameter_id (integer).
    Выход:
        void.
    Эффекты:
        Удаление строки.
    Требования:
        Такая запись должна существовать.
*/
CREATE OR REPLACE FUNCTION delete_product_parameter(
    p_product_id integer,
    p_parameter_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM product_parameter
    WHERE product_id = p_product_id AND parameter_id = p_parameter_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Параметр изделия (%, %) не найден', p_product_id, p_parameter_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============== ORDERS ===============

-- Создаёт новый заказ.
/*
    Добавляет запись в таблицу orders.

    Вход:
        p_entity_id (integer): кто заказал,
        p_status (text): статус (по умолчанию 'draft').
    Выход:
        integer: ID созданного заказа.
    Эффекты:
        Вставка строки в orders.
    Требования:
        Сущность должна существовать.
*/
CREATE OR REPLACE FUNCTION create_order(
    p_entity_id integer,
    p_status text DEFAULT 'draft'
) RETURNS integer AS
$$
DECLARE new_id integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM business_entity WHERE id = p_entity_id) THEN
        RAISE EXCEPTION 'Сущность % не существует', p_entity_id;
    END IF;

    INSERT INTO orders (entity_id, status)
    VALUES (p_entity_id, p_status)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Обновляет статус заказа.
/*
    Меняет статус заказа.

    Вход:
        p_id (integer): ID заказа,
        p_status (text): новый статус.
    Выход:
        void.
    Эффекты:
        Обновление orders.status.
    Требования:
        Заказ должен существовать.
*/
CREATE OR REPLACE FUNCTION update_order_status(
    p_id integer,
    p_status text
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_id) THEN
        RAISE EXCEPTION 'Заказ % не существует', p_id;
    END IF;

    UPDATE orders SET status = p_status WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- =============== ORDER_POS ===============

-- Добавляет позицию в заказ.
/*
    Добавляет изделие в состав заказа.

    Вход:
        p_order_id (integer),
        p_product_id (integer),
        p_quantity (numeric).
    Выход:
        void.
    Эффекты:
        Вставка в order_pos.
    Требования:
        Заказ и изделие должны существовать, количество > 0.
*/
CREATE OR REPLACE FUNCTION add_order_pos(
    p_order_id integer,
    p_product_id integer,
    p_quantity numeric
) RETURNS void AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id) THEN
        RAISE EXCEPTION 'Заказ % не существует', p_order_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Изделие % не существует', p_product_id;
    END IF;

    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть > 0';
    END IF;

    INSERT INTO order_pos (order_id, product_id, quantity)
    VALUES (p_order_id, p_product_id, p_quantity)
    ON CONFLICT (order_id, product_id) DO UPDATE
        SET quantity = order_pos.quantity + EXCLUDED.quantity;
END;
$$ LANGUAGE plpgsql;

-- Изменяет количество в позиции заказа.
/*
    Обновляет количество изделия в заказе.

    Вход:
        p_order_id (integer),
        p_product_id (integer),
        p_quantity (numeric).
    Выход:
        void.
    Эффекты:
        Обновление order_pos.quantity.
    Требования:
        Позиция должна существовать.
*/
CREATE OR REPLACE FUNCTION update_order_pos_quantity(
    p_order_id integer,
    p_product_id integer,
    p_quantity numeric
) RETURNS void AS
$$
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть > 0';
    END IF;

    UPDATE order_pos
    SET quantity = p_quantity
    WHERE order_id = p_order_id AND product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Позиция (%:%) не найдена', p_order_id, p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Удаляет позицию из заказа.
/*
    Удаляет строку из order_pos.

    Вход:
        p_order_id (integer),
        p_product_id (integer).
    Выход:
        void.
    Эффекты:
        Удаление позиции.
    Требования:
        Позиция должна существовать.
*/
CREATE OR REPLACE FUNCTION delete_order_pos(
    p_order_id integer,
    p_product_id integer
) RETURNS void AS
$$
BEGIN
    DELETE FROM order_pos
    WHERE order_id = p_order_id AND product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Позиция (%:%) не найдена', p_order_id, p_product_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
