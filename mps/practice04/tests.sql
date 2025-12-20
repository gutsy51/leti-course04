DO $$
DECLARE
    -- Справочники
    m_mm           INTEGER;
    m_m            INTEGER;
    m_pc           INTEGER;

    c_pipe         INTEGER;
    c_fitting      INTEGER;
    c_material     INTEGER;

    p_diameter     INTEGER;
    p_length       INTEGER;
    p_mat_grade    INTEGER;

    v_st3          INTEGER;
    v_20           INTEGER;

    -- Правила и условия
    r_diameter_gt25  INTEGER;
    r_grade_is_st3   INTEGER;
    pred_diam      INTEGER;
    pred_grade     INTEGER;

    -- Продукты
    prod_pipe      INTEGER;
    prod_elbow     INTEGER;
    prod_flange    INTEGER;
    prod_steel     INTEGER;

    -- Сборка
    assy_pipeline  INTEGER;

    -- Вспомогательные
    param_json     JSONB;
    rec            RECORD;
BEGIN
    RAISE NOTICE '=== НАЧАЛО ТЕСТИРОВАНИЯ КОНФИГУРИРУЕМОЙ СПЕЦИФИКАЦИИ ===';

    -- 1. Очистка и базовые справочники
    TRUNCATE TABLE
        bom,
        product_parameter,
        products,
        parameter,
        class_parameter,
        class,
        measure,
        enum_value,
        enum
    RESTART IDENTITY CASCADE;

    RAISE NOTICE '--- Инициализация базовых справочников ---';

    -- Единицы измерения
    m_mm  := create_measure('Миллиметр', 'мм');
    m_m   := create_measure('Метр', 'м');
    m_pc  := create_measure('Штука', 'шт');

    -- Классы
    c_pipe     := create_class('Труба', 'Трубы', m_pc);
    c_fitting  := create_class('Фитинг', 'Фитинги', m_pc);
    c_material := create_class('Материал', 'Материалы', m_m);

    -- Параметры
    p_diameter  := create_parameter(c_pipe, m_mm, 'diameter', 'Диаметр');
    p_length    := create_parameter(c_pipe, m_m, 'length', 'Длина');
    p_mat_grade := create_parameter(c_material, m_mm, 'grade', 'Марка стали');

    -- Перечисления
    PERFORM create_enum('steel_grade', 'Марка стали');
    v_st3 := create_enum_value(1, 'st3', 'Сталь Ст3');
    v_20  := create_enum_value(1, '20', 'Сталь 20');

    -- Обязательные параметры классов
    PERFORM add_class_parameter(c_pipe, p_diameter, 10, 100, TRUE);
    PERFORM add_class_parameter(c_pipe, p_length, 0.5, 6.0, TRUE);
    PERFORM add_class_parameter(c_material, p_mat_grade, NULL, NULL, TRUE);

    RAISE NOTICE 'Справочники инициализированы';

    -- 2. Создание изделий
    RAISE NOTICE '--- Создание изделий ---';

    prod_pipe   := create_product('PIPE-25', 'Труба 25 мм', m_pc, c_pipe);
    prod_elbow  := create_product('ELBOW-90', 'Отвод 90°', m_pc, c_fitting);
    prod_flange := create_product('FLANGE-25', 'Фланец 25 мм', m_pc, c_fitting);
    prod_steel  := create_product('STL-ST3', 'Сталь Ст3', m_m, c_material);

    -- Параметры трубы
    PERFORM set_product_parameter(prod_pipe, p_diameter, p_value_real := 25.0);
    PERFORM set_product_parameter(prod_pipe, p_length,   p_value_real := 2.0);

    -- Параметры стали
    PERFORM set_product_parameter(prod_steel, p_mat_grade, p_value_enum := v_st3);

    assy_pipeline := create_product('PL-STD', 'Трубопровод стандартный', m_pc, c_pipe);
    RAISE NOTICE 'Изделия созданы';

    -- 3. Настройка правил конфигурации
    RAISE NOTICE '--- Настройка правил конфигурации ---';

    -- Правило 1: если диаметр > 25, добавить фланцы
    r_diameter_gt25 := create_config_rule('diameter_gt25', 'Фланцы для труб >25мм');
    pred_diam := create_rule_predicate(p_parameter_id := p_diameter, p_value_real := 25.0, p_operator := '>');
    PERFORM add_rule_condition(r_diameter_gt25, pred_diam, 1, 'AND');

    -- Правило 2: если марка стали = Ст3, добавить сталь Ст3
    r_grade_is_st3 := create_config_rule('grade_is_st3', 'Материал для Ст3');
    pred_grade := create_rule_predicate(p_parameter_id := p_mat_grade, p_enum_value_id := v_st3, p_operator := '=');
    PERFORM add_rule_condition(r_grade_is_st3, pred_grade, 1, 'AND');

    RAISE NOTICE 'Правила созданы: diameter_gt25 (ID=%), grade_is_st3 (ID=%)', r_diameter_gt25, r_grade_is_st3;

    -- 4. Формирование спецификации
    RAISE NOTICE '--- Формирование спецификации ---';

    PERFORM add_bom_component(assy_pipeline, prod_pipe,   1.0);                    -- труба — всегда
    PERFORM add_bom_component(assy_pipeline, prod_elbow,  2.0);                    -- отвод — всегда
    PERFORM add_bom_component(assy_pipeline, prod_flange, 2.0, r_diameter_gt25);   -- фланец — если диаметр > 25
    PERFORM add_bom_component(assy_pipeline, prod_steel,  10.0, r_grade_is_st3);   -- сталь — если марка = Ст3

    RAISE NOTICE 'Спецификация сборки PL-STD сформирована';

    -- 5. Демонстрация поведения при разных параметрах
    RAISE NOTICE '=== ДЕМОНСТРАЦИЯ КОНФИГУРАЦИИ ===';

    -- Вариант 1: диаметр = 20, марка = Ст3
    param_json := '{"diameter": 20, "grade": 501}'::JSONB;  -- 501 — ID enum_value Ст3

    RAISE NOTICE '--- Вариант 1: диаметр = 20 мм (фланцы НЕ нужны), марка = Ст3 ---';
    FOR rec IN SELECT * FROM get_full_spec_checked(assy_pipeline, param_json) ORDER BY level, product_name LOOP
        RAISE NOTICE '[L%] % (%): % %', rec.level, rec.product_name, rec.product_code, rec.quantity, rec.unit;
    END LOOP;

    -- Вариант 2: диаметр = 32, марка = Ст3
    param_json := '{"diameter": 32, "grade": 501}'::JSONB;

    RAISE NOTICE '--- Вариант 2: диаметр = 32 мм (фланцы НУЖНЫ), марка = Ст3 ---';
    FOR rec IN SELECT * FROM get_full_spec_checked(assy_pipeline, param_json) ORDER BY level, product_name LOOP
        RAISE NOTICE '[L%] % (%): % %', rec.level, rec.product_name, rec.product_code, rec.quantity, rec.unit;
    END LOOP;

    -- 6. Расчёт сводных норм
    RAISE NOTICE '--- Сводные нормы расхода для варианта с диаметром 32 мм ---';
    FOR rec IN SELECT * FROM get_aggregated_bom(assy_pipeline, param_json) LOOP
        RAISE NOTICE '[%] %: % %', rec.class_name, rec.class_display_name, rec.total_quantity, rec.unit;
    END LOOP;

    -- 7. Проверка устойчивости
    RAISE NOTICE '--- Тесты устойчивости (ожидаемые ошибки) ---';

    -- Попытка удалить используемое правило
    BEGIN
        PERFORM delete_config_rule(r_diameter_gt25);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ожидаемая ошибка при удалении используемого правила: %', SQLERRM;
    END;

    -- Попытка создать предикат с двумя значениями
    BEGIN
        PERFORM create_rule_predicate(p_parameter_id := p_diameter, p_value_int := 10, p_value_real := 10.0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ожидаемая ошибка при двойном значении: %', SQLERRM;
    END;

    -- Попытка добавить компонент с несуществующим правилом
    BEGIN
        PERFORM add_bom_component(assy_pipeline, prod_pipe, 1.0, 99999);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ожидаемая ошибка при неверном rule_id: %', SQLERRM;
    END;

    RAISE NOTICE '=== ТЕСТИРОВАНИЕ ЗАВЕРШЕНО УСПЕШНО ===';
END $$;