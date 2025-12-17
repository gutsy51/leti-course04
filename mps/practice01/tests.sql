-- 1. Очистка БД.
TRUNCATE TABLE bom, products, class, measure
RESTART IDENTITY CASCADE;

-- 2. Заполнение справочников.
DO $$
DECLARE
    -- Единицы измерения
    m_default INT;
    m_kg      INT;
    m_m       INT;
    m_ton     INT;
    m_pc      INT;

    -- Классы
    c_material INT;
    c_pipe     INT;
    c_fitting  INT;

    -- Продукты
    p_pipe_system INT;
    p_ptr1 INT;
    p_ptr2 INT;
    p_nipple INT;
    p_sht INT;
    p_nut INT;

    p_wire INT;
    p_co2 INT;
    p_pipe20 INT;
    p_hex41 INT;
    p_hex36 INT;
    p_round36 INT;
BEGIN
    RAISE NOTICE '=== СПРАВОЧНИК ЕДИНИЦ ИЗМЕРЕНИЯ ===';
    m_default := create_measure('Единица', 'ед');
    m_kg      := create_measure('Килограмм', 'кг');
    m_m       := create_measure('Метр', 'м');
    m_ton     := create_measure('Тонна', 'т');
    m_pc      := create_measure('Штука', 'шт');

    RAISE NOTICE '=== СПРАВОЧНИК КЛАССОВ ===';
    c_material := create_class('Материалы', 'Материалы', m_default);
    c_pipe     := create_class('Трубы', 'Трубы', m_default);
    c_fitting  := create_class('Фитинги', 'Фитинги', m_default);

    RAISE NOTICE '=== СПРАВОЧНИК ПРОДУКТОВ ===';
    -- Материалы
    p_wire := create_product('M.WIRE', 'Проволока 1,2 СВ-08Г2с', m_kg, c_material);
    p_co2  := create_product('M.CO2', 'Двуокись углерода жидкая ГОСТ 8050-85', m_kg, c_material);
    p_pipe20 := create_product('M.PIPE20', 'Труба усл.прох.20х2,8 черная', m_m, c_pipe);
    p_hex41 := create_product('M.HEX41', 'Шестигранник 41 СТ45-Б-Т калибр.', m_ton, c_material);
    p_hex36 := create_product('M.HEX36', 'Шестигранник 36 СТ45-Б-Т калибр.', m_ton, c_material);
    p_round36 := create_product('M.ROUND36', 'Круг 36-B-I СТ45-2ГП', m_ton, c_material);

    -- Изделия
    p_pipe_system := create_product('КП25.00.21.220', 'Трубопровод', m_pc, c_pipe);
    p_ptr1       := create_product('КП25.00.21.221', 'Патрубок', m_pc, c_fitting);
    p_ptr2       := create_modification(p_ptr1, 'КП25.00.21.221-01', 'Патрубок', m_pc);
    p_nipple     := create_product('31.26.01.028', 'Ниппель', m_pc, c_fitting);
    p_sht        := create_product('31.01.07.017', 'Штуцер', m_pc, c_fitting);
    p_nut        := create_product('11.01.02.022-01', 'Гайка', m_pc, c_fitting);

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ BOM ===';
    PERFORM add_bom_item(p_pipe_system, p_wire, 0.2);
    PERFORM add_bom_item(p_pipe_system, p_co2, 0.24);
    PERFORM add_bom_item(p_pipe_system, p_ptr2, 1);
    PERFORM add_bom_item(p_pipe_system, p_nipple, 1);
    PERFORM add_bom_item(p_pipe_system, p_sht, 1);
    PERFORM add_bom_item(p_pipe_system, p_nut, 1);
    PERFORM add_bom_item(p_pipe_system, p_ptr1, 1);

    PERFORM add_bom_item(p_ptr1, p_pipe20, 0.0542);
    PERFORM add_bom_item(p_ptr2, p_pipe20, 0.1024);
    PERFORM add_bom_item(p_nut, p_hex41, 0.0004);
    PERFORM add_bom_item(p_sht, p_hex36, 0.0003);
    PERFORM add_bom_item(p_nipple, p_round36, 0.0004);

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ ЗАВЕРШЕНО ===';
END $$;



-- 3. Проверка CRUD.
DO $$
DECLARE
    id_new INT;
BEGIN
    RAISE NOTICE '=== ТЕСТ CRUD ===';

    -- создание
    SELECT create_product('TEST.CODE', 'Тестовый продукт', 1) INTO id_new;
    RAISE NOTICE 'Создан продукт id=%', id_new;

    -- изменение
    PERFORM update_product(id_new, 'TEST.CODE2', 'Тестовое изделие', 1);
    RAISE NOTICE 'Обновлён продукт id=%', id_new;

    -- удаление
    PERFORM delete_product(id_new);
    IF NOT EXISTS(SELECT 1 FROM products WHERE id=id_new) THEN
        RAISE NOTICE 'Удаление продукта — OK';
    ELSE
        RAISE NOTICE 'Удаление продукта — FAIL';
    END IF;
END $$;


-- 4. Проверка ссылочной целостности.
DO $$
BEGIN
    RAISE NOTICE '=== ПРОВЕРКА ЦЕЛОСТНОСТИ ===';

    -- Проверка, что все bom.child_id существуют
    IF EXISTS (
        SELECT 1 FROM bom b LEFT JOIN products p ON b.child_id = p.id
        WHERE p.id IS NULL
    ) THEN
        RAISE NOTICE 'FAIL: есть битые ссылки bom.child_id';
    ELSE
        RAISE NOTICE 'OK: все child_id валидны';
    END IF;

    -- Проверка, что все bom.parent_id существуют
    IF EXISTS (
        SELECT 1 FROM bom b LEFT JOIN products p ON b.parent_id = p.id
        WHERE p.id IS NULL
    ) THEN
        RAISE NOTICE 'FAIL: есть битые ссылки bom.parent_id';
    ELSE
        RAISE NOTICE 'OK: все parent_id валидны';
    END IF;
END $$;

-- 5. Тест: Проверка защиты от циклов в BOM
DO $$
DECLARE
    prod_a INTEGER;
    prod_b INTEGER;
    prod_c INTEGER;
BEGIN
    RAISE NOTICE '=== ТЕСТ: Проверка защиты от циклов в BOM ===';

    prod_a := create_product('CYCLE.A', 'Цикличное изделие A', 1);
    prod_b := create_product('CYCLE.B', 'Цикличное изделие B', 1);
    prod_c := create_product('CYCLE.C', 'Цикличное изделие C', 1);

    PERFORM add_bom_item(prod_a, prod_b, 1);
    PERFORM add_bom_item(prod_b, prod_c, 1);

    RAISE NOTICE 'Создана структура: A → B → C';

    RAISE NOTICE 'Попытка добавить C в A (цикл)';
    BEGIN
        PERFORM add_bom_item(prod_c, prod_a, 1);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ожидаемая ошибка: %', SQLERRM;
    END;

    -- Попытка добавить изделие само в себя
    RAISE NOTICE 'Попытка добавить A в A';
    BEGIN
        PERFORM add_bom_item(prod_a, prod_a, 1);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ожидаемая ошибка: %', SQLERRM;
    END;
END $$;

-- 5. Проверка запросов.
DO $$
DECLARE
    rec RECORD;
    root_id INT;
BEGIN
    RAISE NOTICE '=== ТЕСТ BOM ДЕРЕВО ===';

    -- Корневой элемент: Трубопровод
    SELECT id INTO root_id FROM products WHERE code = 'КП25.00.21.220';

    FOR rec IN SELECT * FROM get_bom_tree(root_id) LOOP
        RAISE NOTICE '[Уровень %] parent_id=% child_id=% name=% qty=%',
            rec.level,
            rec.parent_id,
            rec.child_id,
            rec.child_name,
            rec.qty;
    END LOOP;

    RAISE NOTICE '=== ТЕСТ ЗАВЕРШЁН ===';
END $$;
