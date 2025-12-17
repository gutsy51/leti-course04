-- Заполнение данных для маршрутной карты производства трубопровода

-- Очистка таблиц
TRUNCATE TABLE
    input_resource,
    tech_op,
    gwc,
    business_entity,
    enum_value,
    enum,
    bom,
    products,
    class,
    measure
RESTART IDENTITY CASCADE;

-- Заполнение справочников
DO $$
DECLARE
    -- Единицы измерения
    m_pc          INTEGER;
    m_min         INTEGER;
    m_m           INTEGER;
    m_kg          INTEGER;

    -- Классы
    c_department  INTEGER;
    c_gwc         INTEGER;
    c_op_type     INTEGER;
    c_profession  INTEGER;
    c_material    INTEGER;
    c_pipe        INTEGER;
    c_fitting     INTEGER;

    -- Перечисления
    e_qual        INTEGER;
    ev_q1         INTEGER;
    ev_q2         INTEGER;

    -- Подразделения и ГРЦ
    be_welding    INTEGER;
    be_machining  INTEGER;
    gwc_weld      INTEGER;
    gwc_lathe     INTEGER;

    -- Продукты
    p_pipe_sys    INTEGER;
    p_pipe        INTEGER;
    p_fitting     INTEGER;
    p_wire        INTEGER;
    p_co2         INTEGER;

    -- Операции
    op1           INTEGER;
    op2           INTEGER;
    op3           INTEGER;

    -- Переменная для вывода
    rec RECORD;
BEGIN
    RAISE NOTICE '=== ЗАПОЛНЕНИЕ СПРАВОЧНИКОВ ===';

    -- Единицы измерения
    m_pc   := create_measure('Штука', 'шт');
    m_min  := create_measure('Минута', 'мин');
    m_m    := create_measure('Метр', 'м');
    m_kg   := create_measure('Килограмм', 'кг');

    -- Классы
    c_department := create_class('Подразделение', 'Подразделение', m_pc);
    c_gwc        := create_class('ГРЦ', 'Групповой рабочий центр', m_pc);
    c_op_type    := create_class('Операция', 'Тип технологической операции', m_pc);
    c_profession := create_class('Профессия', 'Профессия', m_pc);
    c_material   := create_class('Материал', 'Материал', m_pc);
    c_pipe       := create_class('Труба', 'Труба', m_m);
    c_fitting    := create_class('Фитинг', 'Фитинг', m_pc);

    -- Перечисление "Квалификация"
    e_qual := create_enum('qualification', 'Квалификация');
    ev_q1  := create_enum_value(e_qual, 'q1', '4 разряд', p_value_int => 4);
    ev_q2  := create_enum_value(e_qual, 'q2', '5 разряд', p_value_int => 5);

    -- Подразделения
    be_welding   := create_business_entity(c_department, 'welding', 'Сварочный цех', NULL);
    be_machining := create_business_entity(c_department, 'machining', 'Механический цех', NULL);

    -- ГРЦ
    gwc_weld  := create_gwc(c_gwc, be_welding,   'weld1', 'Сварочный пост 1');
    gwc_lathe := create_gwc(c_gwc, be_machining, 'lathe1', 'Токарный станок 1');

    -- Продукты
    p_wire     := create_product('M.WIRE',  'Проволока СВ-08Г2С', m_kg, c_material);
    p_co2      := create_product('M.CO2',   'Сварочная смесь CO2', m_kg, c_material);
    p_pipe     := create_product('T.20.800', 'Труба 20x2.8, L=800мм', m_m, c_pipe);
    p_fitting  := create_product('F.32.01',  'Фитинг переходной 32-01', m_pc, c_fitting);
    p_pipe_sys := create_product('PIPE_SYS_01', 'Трубопровод узел 1', m_pc, c_pipe);

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ BOM ===';
    PERFORM add_bom_item(p_pipe_sys, p_pipe, 2.5);      -- 2.5 м трубы
    PERFORM add_bom_item(p_pipe_sys, p_fitting, 3);     -- 3 фитинга
    PERFORM add_bom_item(p_pipe_sys, p_wire, 0.15);     -- 0.15 кг проволоки
    PERFORM add_bom_item(p_pipe_sys, p_co2, 0.3);       -- 0.3 кг газа

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ ТЕХНОЛОГИЧЕСКИХ ОПЕРАЦИЙ ===';

    -- Операция 1: Резка трубы
    op1 := create_tech_op(
        p_product_id => p_pipe_sys,
        p_pos => 1,
        p_op_class_id => create_class('cutting', 'Резка', m_pc),
        p_prof_class_id => create_class('sawyer', 'Резчик', m_pc),
        p_gwc_id => gwc_lathe,
        p_qualification_id => ev_q1,
        p_work_time => 15.0
    );

    -- Операция 2: Подготовка к сварке
    op2 := create_tech_op(
        p_product_id => p_pipe_sys,
        p_pos => 2,
        p_op_class_id => create_class('fitup', 'Сборка', m_pc),
        p_prof_class_id => create_class('fitter', 'Слесарь-сборщик', m_pc),
        p_gwc_id => gwc_weld,
        p_qualification_id => ev_q2,
        p_work_time => 25.0
    );

    -- Операция 3: Сварка
    op3 := create_tech_op(
        p_product_id => p_pipe_sys,
        p_pos => 3,
        p_op_class_id => create_class('welding', 'Сварка', m_pc),
        p_prof_class_id => create_class('welder', 'Сварщик', m_pc),
        p_gwc_id => gwc_weld,
        p_qualification_id => ev_q2,
        p_work_time => 40.0
    );

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ ВХОДНЫХ РЕСУРСОВ (связи между операциями) ===';

    -- Проволока подаётся в сварку
    PERFORM create_input_resource(
        p_in_to_id => op3,
        p_out_to_id => op1,
        p_product_id => p_wire,
        p_in_quantity => 0.15,
        p_out_quantity => 0.15
    );

    -- Газ подаётся в сварку
    PERFORM create_input_resource(
        p_in_to_id => op3,
        p_out_to_id => op1,
        p_product_id => p_co2,
        p_in_quantity => 0.3,
        p_out_quantity => 0.3
    );

    -- Готовая труба поступает в сборку
    PERFORM create_input_resource(
        p_in_to_id => op2,
        p_out_to_id => op1,
        p_product_id => p_pipe,
        p_in_quantity => 2.5,
        p_out_quantity => 2.5
    );

    -- Фитинги поступают в сборку
    PERFORM create_input_resource(
        p_in_to_id => op2,
        p_out_to_id => op2,
        p_product_id => p_fitting,
        p_in_quantity => 3,
        p_out_quantity => 3
    );

    -- Собранный узел поступает на сварку
    PERFORM create_input_resource(
        p_in_to_id => op3,
        p_out_to_id => op2,
        p_product_id => p_pipe_sys,
        p_in_quantity => 1,
        p_out_quantity => 1
    );

    RAISE NOTICE '=== ТЕСТИРОВАНИЕ МАРШРУТНОЙ КАРТЫ ===';
    RAISE NOTICE 'Маршрутная карта для изделия: PIPE_SYS_01';
    FOR rec IN SELECT * FROM get_route_map(p_pipe_sys) LOOP
        RAISE NOTICE '[%] % на % (% мин), квалификация: %',
            rec.pos, rec.op_class_name, rec.gwc_name, rec.work_time, rec.qualification;
    END LOOP;

    RAISE NOTICE '=== ТЕСТ: Подсчёт затрат на производство ===';
    RAISE NOTICE 'Затраты на изделие PIPE_SYS_01:';
    FOR rec IN SELECT * FROM calculate_material_costs(p_pipe_sys) LOOP
        RAISE NOTICE 'Материал: % (%), количество: % %',
            rec.product_name,
            rec.product_code,
            rec.total_quantity,
            rec.unit;
    END LOOP;
END $$;

DO $$
DECLARE
    c_tool          INTEGER;
    p_wrench        INTEGER;
    p_pipe_sys      INTEGER;
    op_assembly     INTEGER;
    gwc_weld        INTEGER;
    c_operation     INTEGER;
    c_profession    INTEGER;
BEGIN
    RAISE NOTICE '=== ДОБАВЛЕНИЕ ИНСТРУМЕНТА В КАЧЕСТВЕ РЕСУРСА ===';

    -- Создаём класс "Инструмент", если ещё не существует
    IF NOT EXISTS (SELECT 1 FROM class WHERE name = 'tool') THEN
        c_tool := create_class('tool', 'Инструмент', (SELECT id FROM measure WHERE name_short = 'шт'));
    ELSE
        SELECT id INTO c_tool FROM class WHERE name = 'tool';
    END IF;

    -- Создаём изделие — "Гаечный ключ 10 мм"
    IF NOT EXISTS (SELECT 1 FROM products WHERE code = 'TOOL.WRENCH.10') THEN
        p_wrench := create_product(
            p_code => 'TOOL.WRENCH.10',
            p_name => 'Гаечный ключ 10 мм',
            p_measure_id => (SELECT id FROM measure WHERE name_short = 'шт'),
            p_class_id => c_tool
        );
        RAISE NOTICE 'Инструмент "Гаечный ключ" создан с ID = %', p_wrench;
    ELSE
        SELECT id INTO p_wrench FROM products WHERE code = 'TOOL.WRENCH.10';
    END IF;

    -- Получаем ID изделия "Трубопровод узел 1"
    SELECT id INTO p_pipe_sys FROM products WHERE code = 'PIPE_SYS_01';
    IF p_pipe_sys IS NULL THEN
        RAISE EXCEPTION 'Изделие PIPE_SYS_01 не найдено';
    END IF;

    -- Получаем операцию "Сборка" (pos = 2)
    SELECT id INTO op_assembly FROM tech_op WHERE product_id = p_pipe_sys AND pos = 2;
    IF op_assembly IS NULL THEN
        RAISE EXCEPTION 'Операция "Сборка" для изделия % не найдена', p_pipe_sys;
    END IF;

    -- Добавляем инструмент как входной ресурс на операцию "Сборка"
    -- Инструмент поступает "на" операцию (in_to_id) и "используется" в ней (out_to_id = in_to_id)
    IF NOT EXISTS (
        SELECT 1 FROM input_resource
        WHERE in_to_id = op_assembly
          AND product_id = p_wrench
    ) THEN
        PERFORM create_input_resource(
            p_in_to_id => op_assembly,
            p_out_to_id => op_assembly,
            p_product_id => p_wrench,
            p_in_quantity => 1,
            p_out_quantity => 1
        );
        RAISE NOTICE 'Инструмент "Гаечный ключ" добавлен как ресурс для операции "Сборка"';
    ELSE
        RAISE NOTICE 'Инструмент уже добавлен как ресурс';
    END IF;

    -- Проверяем, что инструмент участвует в расчёте затрат
    RAISE NOTICE 'Теперь инструмент будет отображаться в результатах calculate_material_costs()';
END $$;

-- Вывод результатов GET-функций после заполнения данных

DO $$
DECLARE
    p_pipe_sys INTEGER;
    rec RECORD;
BEGIN
    -- Получаем ID изделия "Трубопровод узел 1"
    SELECT id INTO p_pipe_sys FROM products WHERE code = 'PIPE_SYS_01';
    IF p_pipe_sys IS NULL THEN
        RAISE EXCEPTION 'Изделие PIPE_SYS_01 не найдено';
    END IF;

    -- === ВЫВОД МАРШРУТНОЙ КАРТЫ ===
    RAISE NOTICE '=== МАРШРУТНАЯ КАРТА ДЛЯ ИЗДЕЛИЯ: PIPE_SYS_01 (ID=%) ===', p_pipe_sys;
    FOR rec IN SELECT * FROM get_route_map(p_pipe_sys) LOOP
        RAISE NOTICE '[%] % на % (% мин), квалификация: %',
            rec.pos,
            rec.op_class_name,
            rec.gwc_name,
            rec.work_time,
            COALESCE(rec.qualification, 'не требуется');
    END LOOP;

    -- === ВЫВОД ЗАТРАТ НА ПРОИЗВОДСТВО ===
    RAISE NOTICE '=== ЗАТРАТЫ НА ПРОИЗВОДСТВО ИЗДЕЛИЯ: PIPE_SYS_01 ===';
    FOR rec IN SELECT * FROM calculate_material_costs(p_pipe_sys) LOOP
        RAISE NOTICE 'Материал: "%", код: %, количество: % %',
            rec.product_name,
            rec.product_code,
            rec.total_quantity,
            rec.unit;
    END LOOP;
END $$;
