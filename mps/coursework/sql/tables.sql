-- Удалить старые таблицы, если существуют.
DROP TABLE IF EXISTS bom, class, products, measure, material_properties;

-- Единицы измерения.
CREATE TABLE measure
(
    id         serial                NOT NULL,
    name       character varying(64) NOT NULL,
    name_short character varying(16) NOT NULL,

    CONSTRAINT measure_id PRIMARY KEY (id),

    CONSTRAINT uq_measure_name UNIQUE (name),
    CONSTRAINT uq_measure_name_short UNIQUE (name_short)
);

-- Классы.
CREATE TABLE class
(
    id           SERIAL PRIMARY KEY,

    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,

    parent_id    INTEGER REFERENCES class (id),
    measure_id   INTEGER NOT NULL REFERENCES measure (id)
);

-- Справочник изделий.
CREATE TABLE products
(
    id              SERIAL PRIMARY KEY,
    code            TEXT    NOT NULL UNIQUE,                  -- КП25.00.21.221
    name            TEXT    NOT NULL,                         -- Труба 25х2.5

    measure_id      INTEGER NOT NULL REFERENCES measure (id), -- ЕИ измерения
    class_id        INTEGER REFERENCES class (id),            -- Класс изделия
    modification_id INTEGER REFERENCES products (id),         -- Родитель модификации
    change_id       INTEGER REFERENCES products (id)          -- Родитель изменения
);

-- Связь изделий и их компонентов (parent-Трубопровод, состоит из: child-Труба, состоит из: child-Материал).
CREATE TABLE bom
(
    parent_id INTEGER        NOT NULL REFERENCES products (id), -- Изделие
    child_id  INTEGER        NOT NULL REFERENCES products (id), -- Компонент

    quantity  NUMERIC(18, 6) NOT NULL CHECK (quantity > 0),     -- Количество

    PRIMARY KEY (parent_id, child_id)
);

CREATE INDEX idx_product_spec_for_product
    ON bom (parent_id);

CREATE INDEX idx_product_spec_use_product
    ON bom (child_id);
DROP TABLE IF EXISTS input_resource, tech_op, gwc, business_entity, enum_value, enum;

-- Справочник перечислений.
CREATE TABLE IF NOT EXISTS enum
(
    id           SERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    display_name TEXT NOT NULL
);

-- Значения перечислений.
CREATE TABLE IF NOT EXISTS enum_value
(
    id           SERIAL PRIMARY KEY,
    enum_id      INTEGER NOT NULL REFERENCES enum (id),
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,
    value_int    INTEGER,
    value_real   REAL,
    value_str    TEXT,
    value_class  INTEGER REFERENCES class (id)
);

-- Субъекты хозяйственной деятельности (подразделения, организации).
CREATE TABLE IF NOT EXISTS business_entity
(
    id           SERIAL PRIMARY KEY,
    class_id     INTEGER NOT NULL REFERENCES class (id), -- Тип подразделения
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,
    parent_id    INTEGER REFERENCES business_entity (id)
);

-- Групповые рабочие центры.
CREATE TABLE IF NOT EXISTS gwc
(
    id           SERIAL PRIMARY KEY,
    class_id     INTEGER NOT NULL REFERENCES class (id),           -- Тип рабочего центра
    entity_id    INTEGER NOT NULL REFERENCES business_entity (id), -- Подразделение
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL
);

-- Технологические операции.
CREATE TABLE IF NOT EXISTS tech_op
(
    id               SERIAL PRIMARY KEY,
    product_id       INTEGER NOT NULL REFERENCES products (id), -- Изделие, к которому относится операция
    pos              INTEGER NOT NULL,                          -- Порядок операции в маршруте
    op_class_id      INTEGER NOT NULL REFERENCES class (id),    -- Класс операции
    prof_class_id    INTEGER NOT NULL REFERENCES class (id),    -- Класс профессии/навыка
    gwc_id           INTEGER NOT NULL REFERENCES gwc (id),      -- Рабочий центр
    qualification_id INTEGER REFERENCES enum_value (id),        -- Квалификация (через enum_value)
    work_time        REAL    NOT NULL                           -- Время на операцию
);

-- Входные ресурсы с указанием предыдущей и следующей операции.
CREATE TABLE IF NOT EXISTS input_resource
(
    in_to_id     INTEGER        NOT NULL REFERENCES tech_op (id),  -- операция, в которую ресурс поступает
    out_to_id    INTEGER        NOT NULL REFERENCES tech_op (id),  -- операция, из которой ресурс идёт
    product_id   INTEGER        NOT NULL REFERENCES products (id), -- ресурс / компонент
    in_quantity  NUMERIC(18, 6) NOT NULL,                          -- количество, поступающее на in_to_id
    out_quantity NUMERIC(18, 6) NOT NULL,                          -- количество, расходуемое из out_to_id
    PRIMARY KEY (in_to_id, out_to_id, product_id)
);

DROP TABLE IF EXISTS parameter, class_parameter, product_parameter, orders, order_pos;

-- Справочник параметров (характеристик)
CREATE TABLE IF NOT EXISTS parameter
(
    id           SERIAL PRIMARY KEY,
    class_id     INTEGER NOT NULL REFERENCES class (id),   -- Тип параметра (например, "Диаметр", "Темп.")
    measure_id   INTEGER NOT NULL REFERENCES measure (id), -- Единица измерения
    name         TEXT    NOT NULL,                         -- internal_name, e.g. 'diameter'
    display_name TEXT    NOT NULL                          -- Отображаемое имя, e.g. 'Диаметр, мм'
);

-- Определяет, какие параметры обязательны для класса и их допустимый диапазон
CREATE TABLE IF NOT EXISTS class_parameter
(
    class_id     INTEGER NOT NULL REFERENCES class (id),
    parameter_id INTEGER NOT NULL REFERENCES parameter (id),
    min_value    REAL,                           -- Мин значение
    max_value    REAL,                           -- Макс значение
    is_required  BOOLEAN NOT NULL DEFAULT FALSE, -- Обязательно ли задавать для продукта?

    PRIMARY KEY (class_id, parameter_id)
);

-- Хранит значения параметров для конкретных изделий
CREATE TABLE IF NOT EXISTS product_parameter
(
    product_id   INTEGER NOT NULL REFERENCES products (id),
    parameter_id INTEGER NOT NULL REFERENCES parameter (id),
    value_int    INTEGER,
    value_real   REAL,
    value_str    TEXT,
    value_enum   INTEGER REFERENCES enum_value (id), -- для ссылок на enum

    PRIMARY KEY (product_id, parameter_id),

    -- Ограничение: только одно значение может быть не NULL
    CONSTRAINT chk_single_value CHECK (
        (value_int IS NOT NULL)::integer +
        (value_real IS NOT NULL)::integer +
        (value_str IS NOT NULL)::integer +
        (value_enum IS NOT NULL)::integer
            <= 1
        )
);

-- Индекс для поиска по параметрам
CREATE INDEX IF NOT EXISTS idx_product_parameter_value ON product_parameter (parameter_id, value_int, value_real);

-- Заказ (на производство, поставку)
CREATE TABLE IF NOT EXISTS orders
(
    id         SERIAL PRIMARY KEY,
    entity_id  INTEGER   NOT NULL REFERENCES business_entity (id), -- Кто заказал/выполняет
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status     TEXT      NOT NULL DEFAULT 'draft'                  -- draft, confirmed, in_progress, completed
);

-- Позиции заказа
CREATE TABLE IF NOT EXISTS order_pos
(
    id         SERIAL PRIMARY KEY,
    order_id   INTEGER        NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id INTEGER        NOT NULL REFERENCES products (id),
    quantity   NUMERIC(18, 6) NOT NULL CHECK (quantity > 0),

    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

-- Индекс для быстрого поиска по заказу
CREATE INDEX IF NOT EXISTS idx_order_pos_order ON order_pos (order_id);
DROP TABLE IF EXISTS config_rule, rule_predicate, rule_condition CASCADE;

-- Правило конфигурации
CREATE TABLE config_rule
(
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Таблица предикатов (атомарных условий)
CREATE TABLE rule_predicate
(
    id            SERIAL PRIMARY KEY,
    parameter_id  INTEGER NOT NULL REFERENCES parameter (id),
    value_int     INTEGER,
    value_real    REAL,
    value_str     TEXT,
    enum_value_id INTEGER REFERENCES enum_value (id),
    operator      TEXT    NOT NULL CHECK (operator IN ('=', '!=', '>', '<', '>=', '<=', 'IN'))
);

-- Условие внутри правила
CREATE TABLE rule_condition
(
    id           SERIAL PRIMARY KEY,
    rule_id      INTEGER NOT NULL REFERENCES config_rule (id),
    predicate_id INTEGER NOT NULL REFERENCES rule_predicate (id),
    "order"      INTEGER DEFAULT 1,
    logic_op     TEXT    DEFAULT 'AND' CHECK (logic_op IN ('AND', 'OR'))
);

-- Расширяем таблицу bom: добавляем ссылку на config_rule
ALTER TABLE bom
    ADD COLUMN IF NOT EXISTS config_rule_id INTEGER REFERENCES config_rule (id);
ALTER TABLE bom
    ADD CONSTRAINT uk_bom_parent_child_rule UNIQUE (parent_id, child_id, config_rule_id);

CREATE INDEX IF NOT EXISTS idx_bom_config_rule ON bom (config_rule_id);