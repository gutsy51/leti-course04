DROP TABLE IF EXISTS input_resource, tech_op, gwc, business_entity, enum_value, enum;

-- Справочник перечислений.
CREATE TABLE IF NOT EXISTS enum (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL
);

-- Значения перечислений.
CREATE TABLE IF NOT EXISTS enum_value (
    id SERIAL PRIMARY KEY,
    enum_id INTEGER NOT NULL REFERENCES enum(id),
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    value_int INTEGER,
    value_real REAL,
    value_str TEXT,
    value_class INTEGER REFERENCES class(id)
);

-- Субъекты хозяйственной деятельности (подразделения, организации).
CREATE TABLE IF NOT EXISTS business_entity (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES class(id),  -- Тип подразделения
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    parent_id INTEGER REFERENCES business_entity(id)
);

-- Групповые рабочие центры.
CREATE TABLE IF NOT EXISTS gwc (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES class(id),        -- Тип рабочего центра
    entity_id INTEGER NOT NULL REFERENCES business_entity(id), -- Подразделение
    name TEXT NOT NULL,
    display_name TEXT NOT NULL
);

-- Технологические операции.
CREATE TABLE IF NOT EXISTS tech_op (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id), -- Изделие, к которому относится операция
    pos INTEGER NOT NULL,                                -- Порядок операции в маршруте
    op_class_id INTEGER NOT NULL REFERENCES class(id),   -- Класс операции
    prof_class_id INTEGER NOT NULL REFERENCES class(id), -- Класс профессии/навыка
    gwc_id INTEGER NOT NULL REFERENCES gwc(id),          -- Рабочий центр
    qualification_id INTEGER REFERENCES enum_value(id),  -- Квалификация (через enum_value)
    work_time REAL NOT NULL                              -- Время на операцию
);

-- Входные ресурсы с указанием предыдущей и следующей операции.
CREATE TABLE IF NOT EXISTS input_resource (
    in_to_id  INTEGER NOT NULL REFERENCES tech_op(id),   -- операция, в которую ресурс поступает
    out_to_id INTEGER NOT NULL REFERENCES tech_op(id),   -- операция, из которой ресурс идёт
    product_id INTEGER NOT NULL REFERENCES products(id), -- ресурс / компонент
    in_quantity  NUMERIC(18,6) NOT NULL,                 -- количество, поступающее на in_to_id
    out_quantity NUMERIC(18,6) NOT NULL,                 -- количество, расходуемое из out_to_id
    PRIMARY KEY (in_to_id, out_to_id, product_id)
);

