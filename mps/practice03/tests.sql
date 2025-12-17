-- 1. Очистка БД.
TRUNCATE TABLE
    measure,
    parameter,
    class_parameter,
    product_parameter,
    orders,
    order_pos,
    business_entity,
    class,
    enum_value,
    enum
RESTART IDENTITY CASCADE;

-- 2. Заполнение справочников.
DO $$
DECLARE
    -- Единицы измерения
    m_mm       INT;
    m_m        INT;
    m_pc       INT;

    -- Классы
    c_pipe     INT;
    c_fitting  INT;
    c_department INT;

    -- Подразделение (для entity_id)
    e_welding  INT;

    -- Параметры
    p_diameter INT;
    p_length   INT;

    -- Перечисления (для примера)
    e_material INT;
    v_st3      INT;

    -- Продукты
    p_pipe_25  INT;
    p_pipe_32  INT;
    p_elbow    INT;

    -- Заказы
    o1         INT;
    o2         INT;

    -- Вспомогательные
    cnt        INT;
    rec        RECORD;
BEGIN
    RAISE NOTICE '=== ЗАПОЛНЕНИЕ СПРАВОЧНИКОВ ===';

    -- --- Единицы измерения ---
    -- Проверка и создание, если не существует
    SELECT id INTO m_mm FROM measure WHERE name = 'Миллиметр';
    IF NOT FOUND THEN
        m_mm := create_measure('Миллиметр', 'мм');
    END IF;

    SELECT id INTO m_m FROM measure WHERE name = 'Метр';
    IF NOT FOUND THEN
        m_m := create_measure('Метр', 'м');
    END IF;

    SELECT id INTO m_pc FROM measure WHERE name = 'Штука';
    IF NOT FOUND THEN
        m_pc := create_measure('Штука', 'шт');
    END IF;

    -- --- Классы ---
    SELECT id INTO c_pipe FROM class WHERE name = 'Труба';
    IF NOT FOUND THEN
        c_pipe := create_class('Труба', 'Трубы', m_pc);
    END IF;

    SELECT id INTO c_fitting FROM class WHERE name = 'Фитинг';
    IF NOT FOUND THEN
        c_fitting := create_class('Фитинг', 'Фитинги', m_pc);
    END IF;

    SELECT id INTO c_department FROM class WHERE name = 'Цех';
    IF NOT FOUND THEN
        c_department := create_class('Цех', 'Подразделения', m_pc);
    END IF;

    -- --- Подразделение (для заказов) ---
    SELECT id INTO e_welding FROM business_entity WHERE name = 'welding';
    IF NOT FOUND THEN
        e_welding := create_business_entity(
            p_class_id := c_department,
            p_name := 'welding',
            p_display_name := 'Сварочный цех'
        );
    END IF;
    RAISE NOTICE 'Создано подразделение: Сварочный цех (ID=%)', e_welding;

    -- --- Параметры ---
    SELECT id INTO p_diameter FROM parameter WHERE name = 'diameter';
    IF NOT FOUND THEN
        p_diameter := create_parameter(c_pipe, m_mm, 'diameter', 'Диаметр');
    END IF;

    SELECT id INTO p_length FROM parameter WHERE name = 'length';
    IF NOT FOUND THEN
        p_length := create_parameter(c_pipe, m_m, 'length', 'Длина');
    END IF;

    -- --- Правила для классов ---
    PERFORM add_class_parameter(c_pipe, p_diameter, 10, 100, TRUE);
    PERFORM add_class_parameter(c_pipe, p_length, 0.5, 6.0, TRUE);

    -- --- Продукты ---
    SELECT id INTO p_pipe_25 FROM products WHERE code = 'PIPE-25';
    IF NOT FOUND THEN
        p_pipe_25 := create_product('PIPE-25', 'Труба 25 мм', m_pc, c_pipe);
    END IF;

    SELECT id INTO p_pipe_32 FROM products WHERE code = 'PIPE-32';
    IF NOT FOUND THEN
        p_pipe_32 := create_product('PIPE-32', 'Труба 32 мм', m_pc, c_pipe);
    END IF;

    SELECT id INTO p_elbow FROM products WHERE code = 'ELBOW-90';
    IF NOT FOUND THEN
        p_elbow := create_product('ELBOW-90', 'Отвод 90°', m_pc, c_fitting);
    END IF;

    -- --- Параметры изделий ---
    PERFORM set_product_parameter(p_pipe_25, p_diameter, p_value_real := 25.0);
    PERFORM set_product_parameter(p_pipe_25, p_length,   p_value_real := 2.0);

    PERFORM set_product_parameter(p_pipe_32, p_diameter, p_value_real := 32.0);
    PERFORM set_product_parameter(p_pipe_32, p_length,   p_value_real := 3.0);

    RAISE NOTICE '=== СПРАВОЧНИКИ ЗАПОЛНЕНЫ ===';

    -- 3. Тест CRUD операций
    RAISE NOTICE '=== ТЕСТ CRUD ===';

    -- Создание продукта и параметров
    PERFORM set_product_parameter(p_elbow, p_diameter, p_value_real := 40.0);
    RAISE NOTICE 'Параметр "Диаметр" для отвода установлен';

    -- Обновление параметра
    PERFORM set_product_parameter(p_pipe_25, p_length, p_value_real := 4.0);
    RAISE NOTICE 'Длина трубы PIPE-25 обновлена до 4.0 м';

    -- Попытка установить два значения (ошибка)
    BEGIN
        PERFORM set_product_parameter(p_pipe_25, p_diameter, p_value_int := 50, p_value_real := 50.0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✅ Ожидаемая ошибка при установке двух значений: %', SQLERRM;
    END;

    RAISE NOTICE '=== CRUD ТЕСТЫ ЗАВЕРШЕНЫ ===';

    -- 4. Работа с заказами
    RAISE NOTICE '=== РАБОТА С ЗАКАЗАМИ ===';

    -- Создание заказов
    o1 := create_order(e_welding); -- используем существующий entity_id
    o2 := create_order(e_welding, 'confirmed');
    RAISE NOTICE 'Созданы заказы: % и %', o1, o2;

    -- Добавление позиций
    PERFORM add_order_pos(o1, p_pipe_25, 10);
    PERFORM add_order_pos(o1, p_pipe_32, 5);
    PERFORM add_order_pos(o1, p_elbow, 3);

    PERFORM add_order_pos(o2, p_pipe_25, 2);

    -- Изменение количества
    PERFORM update_order_pos_quantity(o1, p_elbow, 5);
    RAISE NOTICE 'Количество отводов в заказе % увеличено до 5', o1;

    -- Проверка уникальности
    PERFORM add_order_pos(o1, p_pipe_25, 2); -- +2 к уже существующим 10
    SELECT quantity INTO cnt FROM order_pos WHERE order_id = o1 AND product_id = p_pipe_25;
    RAISE NOTICE 'Итоговое количество трубы 25 мм в заказе %: %', o1, cnt;

    RAISE NOTICE '=== ЗАКАЗЫ СФОРМИРОВАНЫ ===';

    -- 5. Тесты чтения
    RAISE NOTICE '=== ТЕСТЫ ФУНКЦИЙ ЧТЕНИЯ ===';

    -- Вывод параметров всех продуктов
    RAISE NOTICE '--- ПАРАМЕТРЫ ИЗДЕЛИЙ ---';
    FOR cnt IN 1..10 LOOP -- ограничение вывода
        FOR rec IN SELECT * FROM get_product_parameters() LIMIT 1 OFFSET cnt-1 LOOP
            RAISE NOTICE '% (%): % = % %',
                rec.product_name, rec.product_code,
                rec.parameter_display_name, rec.value, rec.unit;
        END LOOP;
    END LOOP;

    -- Вывод правил классов
    RAISE NOTICE '--- ПАРАМЕТРЫ КЛАССОВ ---';
    FOR rec IN SELECT * FROM get_class_parameters(c_pipe) LOOP
        RAISE NOTICE '%: % [% - % %], обязательно=%',
            rec.class_display_name,
            rec.parameter_display_name,
            COALESCE(rec.min_value::text, '-'),
            COALESCE(rec.max_value::text, '-'),
            rec.unit,
            rec.is_required;
    END LOOP;

    -- Вывод содержимого заказа
    RAISE NOTICE '--- СОДЕРЖИМОЕ ЗАКАЗА % ---', o1;
    FOR rec IN SELECT * FROM get_order_contents(o1) LOOP
        RAISE NOTICE '[% шт] % (%): % = % %',
            rec.quantity,
            rec.product_name, rec.product_code,
            COALESCE(rec.param_name, 'без параметров'),
            COALESCE(rec.param_value, '-'),
            COALESCE(rec.param_unit, '-');
    END LOOP;

    -- Попытка чтения несуществующего заказа
    BEGIN
        FOR rec IN SELECT * FROM get_order_contents(-1) LOOP
            RAISE NOTICE '%', rec;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✅ Ожидаемая ошибка при чтении несуществующего заказа: %', SQLERRM;
    END;

    RAISE NOTICE '=== ТЕСТЫ ЧТЕНИЯ ЗАВЕРШЕНЫ ===';
END $$;