DROP TABLE IF EXISTS parameter, class_parameter, product_parameter, orders, order_pos;

-- Справочник параметров (характеристик)
CREATE TABLE IF NOT EXISTS parameter (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES class(id),     -- Тип параметра (например, "Диаметр", "Темп.")
    measure_id INTEGER NOT NULL REFERENCES measure(id), -- Единица измерения
    name TEXT NOT NULL,                                 -- internal_name, e.g. 'diameter'
    display_name TEXT NOT NULL                          -- Отображаемое имя, e.g. 'Диаметр, мм'
);

-- Определяет, какие параметры обязательны для класса и их допустимый диапазон
CREATE TABLE IF NOT EXISTS class_parameter (
    class_id INTEGER NOT NULL REFERENCES class(id),
    parameter_id INTEGER NOT NULL REFERENCES parameter(id),
    min_value REAL,  -- Мин значение
    max_value REAL,  -- Макс значение
    is_required BOOLEAN NOT NULL DEFAULT FALSE, -- Обязательно ли задавать для продукта?

    PRIMARY KEY (class_id, parameter_id)
);

-- Хранит значения параметров для конкретных изделий
CREATE TABLE IF NOT EXISTS product_parameter (
    product_id INTEGER NOT NULL REFERENCES products(id),
    parameter_id INTEGER NOT NULL REFERENCES parameter(id),
    value_int INTEGER,
    value_real REAL,
    value_str TEXT,
    value_enum INTEGER REFERENCES enum_value(id), -- для ссылок на enum

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
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    entity_id INTEGER NOT NULL REFERENCES business_entity(id), -- Кто заказал/выполняет
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'draft' -- draft, confirmed, in_progress, completed
);

-- Позиции заказа
CREATE TABLE IF NOT EXISTS order_pos (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity NUMERIC(18,6) NOT NULL CHECK (quantity > 0),

    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

-- Индекс для быстрого поиска по заказу
CREATE INDEX IF NOT EXISTS idx_order_pos_order ON order_pos(order_id);
