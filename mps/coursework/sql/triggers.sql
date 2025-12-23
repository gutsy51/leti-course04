-- Проверка отсутствия цикла в структуре изделия.
/*
    Проверяет, что добавление связи (parent_id → child_id)
    не приводит к образованию цикла в структуре изделия.

    Вход:
        p_parent_id (integer): изделие, в которое вставляем компонент,
        p_child_id  (integer): изделие-компонент.
    Выход:
        void.
    Эффекты:
        Вызывает ошибку, если будет образован цикл.
    Требования:
        parent_id и child_id должны быть разными.
*/
CREATE OR REPLACE FUNCTION check_bom_cycle(
    p_parent_id integer,
    p_child_id integer
) RETURNS void AS
$$
DECLARE
    is_cycle boolean;
BEGIN
    IF p_parent_id = p_child_id THEN
        RAISE EXCEPTION 'Изделие не может включать само себя';
    END IF;

    WITH RECURSIVE bom_tree AS (
        SELECT parent_id, child_id
        FROM "bom"
        WHERE parent_id = p_child_id

        UNION ALL

        SELECT b.parent_id, b.child_id
        FROM "bom" b
        JOIN bom_tree t ON b.parent_id = t.child_id
    )
    SELECT EXISTS (
        SELECT 1 FROM bom_tree WHERE child_id = p_parent_id
    ) INTO is_cycle;

    IF is_cycle THEN
        RAISE EXCEPTION
            'Добавление компонента приведёт к циклу в структуре изделия';
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Проверка BOM перед вставкой / изменением.
/*
    Эффекты:
        Проверка отсутствия цикла,
        Проверка существования изделий.

    Нормальное завершение:
        Возвращает NEW.
*/
CREATE OR REPLACE FUNCTION trg_check_bom()
RETURNS trigger AS
$$
DECLARE
    exists_parent boolean;
    exists_child boolean;
BEGIN
    SELECT EXISTS(SELECT 1 FROM "products" WHERE id = NEW.parent_id)
    INTO exists_parent;

    SELECT EXISTS(SELECT 1 FROM "products" WHERE id = NEW.child_id)
    INTO exists_child;

    IF NOT exists_parent THEN
        RAISE EXCEPTION 'Изделия % не существует', NEW.parent_id;
    END IF;

    IF NOT exists_child THEN
        RAISE EXCEPTION 'Изделия % не существует', NEW.child_id;
    END IF;

    PERFORM check_bom_cycle(NEW.parent_id, NEW.child_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bom_check ON "bom";
CREATE TRIGGER trg_bom_check
BEFORE INSERT OR UPDATE ON "bom"
FOR EACH ROW
EXECUTE FUNCTION trg_check_bom();

-- Проверяет, удовлетворяет ли набор параметров конфигурации правилу.
/*
    Вход:
        p_rule_id (integer),
        p_config_params (JSONB): { "diameter": 60, "material": 501 }
    Выход:
        boolean: TRUE если все условия правила выполняются.
    Эффекты:
        Чтение rule_condition, rule_predicate, параметров.
    Требования:
        Правило должно существовать.
*/
CREATE OR REPLACE FUNCTION is_rule_satisfied(
    p_rule_id integer,
    p_config_params JSONB
) RETURNS boolean AS $$
DECLARE
    cond_record RECORD;
    param_name TEXT;
    param_value_json JSONB;
    pred_value TEXT;
    op TEXT;
    result BOOLEAN := TRUE;
    first BOOLEAN := TRUE;
BEGIN
    FOR cond_record IN
        SELECT
            par.name AS param_name,
            rp.operator,
            COALESCE(
                rp.value_int::text,
                rp.value_real::text,
                rp.value_str,
                rp.enum_value_id::text
            ) AS pred_value
        FROM rule_condition rc
        JOIN rule_predicate rp ON rp.id = rc.predicate_id
        JOIN parameter par ON par.id = rp.parameter_id
        WHERE rc.rule_id = p_rule_id
        ORDER BY rc."order"
    LOOP
        -- Получаем значение параметра из JSON
        param_value_json := p_config_params -> cond_record.param_name;

        IF param_value_json IS NULL THEN
            RETURN FALSE; -- параметр не задан
        END IF;

        -- Сравниваем
        op := cond_record.operator;
        pred_value := cond_record.pred_value;

        CASE op
            WHEN '=' THEN
                IF param_value_json::text != pred_value THEN result := FALSE; END IF;
            WHEN '!=' THEN
                IF param_value_json::text = pred_value THEN result := FALSE; END IF;
            WHEN '>' THEN
                IF (param_value_json::text)::real <= (pred_value)::real THEN result := FALSE; END IF;
            WHEN '<' THEN
                IF (param_value_json::text)::real >= (pred_value)::real THEN result := FALSE; END IF;
            WHEN '>=' THEN
                IF (param_value_json::text)::real < (pred_value)::real THEN result := FALSE; END IF;
            WHEN '<=' THEN
                IF (param_value_json::text)::real > (pred_value)::real THEN result := FALSE; END IF;
            ELSE
                RAISE NOTICE 'Оператор % не поддерживается', op;
                result := FALSE;
        END CASE;

        IF NOT result THEN
            RETURN FALSE;
        END IF;
    END LOOP;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;