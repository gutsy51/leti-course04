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
