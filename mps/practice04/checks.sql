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