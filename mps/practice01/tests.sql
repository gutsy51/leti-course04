-- 1. Очистка БД.
TRUNCATE TABLE bom, products, measure
RESTART IDENTITY CASCADE;

-- 2. Заполнение данными.
DO $$
DECLARE
    m_kg  INT;
    m_m   INT;
    m_ton INT;
    m_pc  INT;

    p_pipe_system INT;  -- КП25.00.21.220
    p_ptr1 INT;         -- КП25.00.21.221
    p_ptr2 INT;         -- КП25.00.21.221-01
    p_nipple INT;       -- 31.26.01.028
    p_sht INT;          -- 31.01.07.017
    p_nut INT;          -- 11.01.02.022-01

    -- материалы
    p_wire INT;         -- Проволока
    p_co2  INT;         -- Двуокись углерода
    p_pipe20 INT;       -- Труба 20х2.8
    p_hex41 INT;        -- шестигранник 41
    p_hex36 INT;        -- шестигранник 36
    p_round36 INT;      -- круг 36
BEGIN
    RAISE NOTICE '=== ЗАПОЛНЕНИЕ СПРАВОЧНИКОВ ===';

    RAISE NOTICE '=== СПРАВОЧНИК ЕИ ===';
    SELECT create_measure('Килограмм', 'кг') INTO m_kg;
    SELECT create_measure('Метр', 'м') INTO m_m;
    SELECT create_measure('Тонна', 'т') INTO m_ton;
    SELECT create_measure('Штука', 'шт') INTO m_pc;

    RAISE NOTICE '=== СПРАВОЧНИК МАТЕРИАЛОВ / ИЗДЕЛИЙ ===';
    SELECT create_product('M.WIRE', 'Проволока 1,2 СВ-08Г2с', m_kg) INTO p_wire;
    SELECT create_product('M.CO2', 'Двуокись углерода жидкая ГОСТ 8050-85', m_kg) INTO p_co2;
    SELECT create_product('M.PIPE20', 'Труба усл.прох.20х2,8 черная', m_m) INTO p_pipe20;
    SELECT create_product('M.HEX41', 'Шестигранник 41 СТ45-Б-Т калибр.', m_ton) INTO p_hex41;
    SELECT create_product('M.HEX36', 'Шестигранник 36 СТ45-Б-Т калибр.', m_ton) INTO p_hex36;
    SELECT create_product('M.ROUND36', 'Круг 36-B-I СТ45-2ГП', m_ton) INTO p_round36;

    SELECT create_product('КП25.00.21.220', 'Трубопровод', m_pc) INTO p_pipe_system;
    SELECT create_product('КП25.00.21.221', 'Патрубок', m_pc) INTO p_ptr1;
    SELECT create_modification(p_ptr1, 'КП25.00.21.221-01', 'Патрубок', m_pc) INTO p_ptr2;
    SELECT create_product('31.26.01.028', 'Ниппель', m_pc) INTO p_nipple;
    SELECT create_product('31.01.07.017', 'Штуцер', m_pc) INTO p_sht;
    SELECT create_product('11.01.02.022-01', 'Гайка', m_pc) INTO p_nut;


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
