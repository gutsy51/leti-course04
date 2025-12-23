PRAGMA foreign_keys = ON;

-- Единицы измерения.
CREATE TABLE measure
(
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       VARCHAR(64) NOT NULL,
    name_short VARCHAR(16) NOT NULL,

    CONSTRAINT uq_measure_name UNIQUE (name),
    CONSTRAINT uq_measure_name_short UNIQUE (name_short)
);

-- Классы.
CREATE TABLE class
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,
    parent_id    INTEGER,
    measure_id   INTEGER NOT NULL,

    FOREIGN KEY (parent_id) REFERENCES class (id),
    FOREIGN KEY (measure_id) REFERENCES measure (id)
);

-- Справочник изделий.
CREATE TABLE products
(
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT    NOT NULL UNIQUE,
    name            TEXT    NOT NULL,
    measure_id      INTEGER NOT NULL,
    class_id        INTEGER,
    modification_id INTEGER,
    change_id       INTEGER,

    FOREIGN KEY (measure_id) REFERENCES measure (id),
    FOREIGN KEY (class_id) REFERENCES class (id),
    FOREIGN KEY (modification_id) REFERENCES products (id),
    FOREIGN KEY (change_id) REFERENCES products (id)
);

-- BOM — состав изделия
CREATE TABLE bom
(
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id      INTEGER        NOT NULL,
    child_id       INTEGER        NOT NULL,
    quantity       NUMERIC(18, 6) NOT NULL CHECK (quantity > 0),
    config_rule_id INTEGER,

    UNIQUE (parent_id, child_id, config_rule_id),
    FOREIGN KEY (parent_id) REFERENCES products (id),
    FOREIGN KEY (child_id) REFERENCES products (id),
    FOREIGN KEY (config_rule_id) REFERENCES config_rule (id)
);

CREATE INDEX IF NOT EXISTS idx_bom_parent ON bom (parent_id);
CREATE INDEX IF NOT EXISTS idx_bom_child ON bom (child_id);
CREATE INDEX IF NOT EXISTS idx_bom_config_rule ON bom (config_rule_id);

-- Справочник перечислений.
CREATE TABLE enum
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL,
    display_name TEXT NOT NULL
);

-- Значения перечислений.
CREATE TABLE enum_value
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    enum_id      INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,
    value_int    INTEGER,
    value_real   REAL,
    value_str    TEXT,
    value_class  INTEGER,

    FOREIGN KEY (enum_id) REFERENCES enum (id),
    FOREIGN KEY (value_class) REFERENCES class (id)
);

-- Бизнес-субъекты (организации, подразделения)
CREATE TABLE business_entity
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id     INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,
    parent_id    INTEGER,

    FOREIGN KEY (class_id) REFERENCES class (id),
    FOREIGN KEY (parent_id) REFERENCES business_entity (id)
);

-- Групповые рабочие центры
CREATE TABLE gwc
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id     INTEGER NOT NULL,
    entity_id    INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,

    FOREIGN KEY (class_id) REFERENCES class (id),
    FOREIGN KEY (entity_id) REFERENCES business_entity (id)
);

-- Технологические операции
CREATE TABLE tech_op
(
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id       INTEGER NOT NULL,
    pos              INTEGER NOT NULL,
    op_class_id      INTEGER NOT NULL,
    prof_class_id    INTEGER NOT NULL,
    gwc_id           INTEGER NOT NULL,
    qualification_id INTEGER,
    work_time        REAL    NOT NULL,

    FOREIGN KEY (product_id) REFERENCES products (id),
    FOREIGN KEY (op_class_id) REFERENCES class (id),
    FOREIGN KEY (prof_class_id) REFERENCES class (id),
    FOREIGN KEY (gwc_id) REFERENCES gwc (id),
    FOREIGN KEY (qualification_id) REFERENCES enum_value (id)
);

-- Входные ресурсы
CREATE TABLE input_resource
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    in_to        INTEGER        NOT NULL,
    out_to       INTEGER        NOT NULL,
    product_id   INTEGER        NOT NULL,
    in_quantity  NUMERIC(18, 6) NOT NULL,
    out_quantity NUMERIC(18, 6) NOT NULL,

    UNIQUE (in_to, out_to, product_id),
    FOREIGN KEY (in_to) REFERENCES tech_op (id),
    FOREIGN KEY (out_to) REFERENCES tech_op (id),
    FOREIGN KEY (product_id) REFERENCES products (id)
);

-- Параметры (характеристики)
CREATE TABLE parameter
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id     INTEGER NOT NULL,
    measure_id   INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    display_name TEXT    NOT NULL,

    FOREIGN KEY (class_id) REFERENCES class (id),
    FOREIGN KEY (measure_id) REFERENCES measure (id)
);

-- Параметры, обязательные для класса
CREATE TABLE class_parameter
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id     INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,
    min_value    REAL,
    max_value    REAL,
    is_required  BOOLEAN NOT NULL,

    UNIQUE (class_id, parameter_id),
    FOREIGN KEY (class_id) REFERENCES class (id),
    FOREIGN KEY (parameter_id) REFERENCES parameter (id)
);

-- Значения параметров изделий
CREATE TABLE product_parameter
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id   INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,
    value_int    INTEGER,
    value_real   REAL,
    value_str    TEXT,
    value_enum   INTEGER,

    UNIQUE (product_id, parameter_id),
    FOREIGN KEY (product_id) REFERENCES products (id),
    FOREIGN KEY (parameter_id) REFERENCES parameter (id),
    FOREIGN KEY (value_enum) REFERENCES enum_value (id)
);

CREATE INDEX IF NOT EXISTS idx_product_parameter_value ON product_parameter (parameter_id, value_int, value_real);

-- Заказы
CREATE TABLE orders
(
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id  INTEGER   NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status     TEXT      NOT NULL DEFAULT 'draft',

    FOREIGN KEY (entity_id) REFERENCES business_entity (id)
);

-- Позиции заказа
CREATE TABLE order_pos
(
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id   INTEGER        NOT NULL,
    product_id INTEGER        NOT NULL,
    quantity   NUMERIC(18, 6) NOT NULL,

    UNIQUE (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders (id),
    FOREIGN KEY (product_id) REFERENCES products (id)
);

CREATE INDEX IF NOT EXISTS idx_order_pos_order ON order_pos (order_id);

-- Правила конфигурации
CREATE TABLE config_rule
(
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Предикаты (условия)
CREATE TABLE rule_predicate
(
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    parameter_id  INTEGER NOT NULL,
    value_int     INTEGER,
    value_real    REAL,
    value_str     TEXT,
    enum_value_id INTEGER,
    operator      TEXT    NOT NULL CHECK (operator IN ('=', '!=', '>', '<', '>=', '<=', 'IN')),

    FOREIGN KEY (parameter_id) REFERENCES parameter (id),
    FOREIGN KEY (enum_value_id) REFERENCES enum_value (id)
);

-- Условия в правилах
CREATE TABLE rule_condition
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_id      INTEGER NOT NULL,
    predicate_id INTEGER NOT NULL,
    "order"      INTEGER,
    logic_op     TEXT,

    FOREIGN KEY (rule_id) REFERENCES config_rule (id),
    FOREIGN KEY (predicate_id) REFERENCES rule_predicate (id)
);