-- Удалить старые таблицы, если существуют.
DROP TABLE IF EXISTS bom, class, products, measure, material_properties;

-- Единицы измерения.
CREATE TABLE measure (
    id serial NOT NULL,
    name character varying(64) NOT NULL,
    name_short character varying(16) NOT NULL,

    CONSTRAINT measure_id PRIMARY KEY (id),

    CONSTRAINT uq_measure_name UNIQUE (name),
    CONSTRAINT uq_measure_name_short UNIQUE (name_short)
);

-- Классы.
CREATE TABLE class (
    id SERIAL PRIMARY KEY,

    name TEXT NOT NULL,
    display_name TEXT NOT NULL,

    parent_id INTEGER REFERENCES class(id),
    measure_id INTEGER NOT NULL REFERENCES measure(id)
);

-- Справочник изделий.
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,  -- КП25.00.21.221
    name TEXT NOT NULL,         -- Труба 25х2.5

    measure_id INTEGER NOT NULL REFERENCES measure(id),  -- ЕИ измерения
    class_id INTEGER REFERENCES class(id),               -- Класс изделия
    modification_id INTEGER REFERENCES products(id),     -- Родитель модификации
    change_id INTEGER REFERENCES products(id)            -- Родитель изменения
);

-- Связь изделий и их компонентов (parent-Трубопровод, состоит из: child-Труба, состоит из: child-Материал).
CREATE TABLE bom (
    parent_id INTEGER NOT NULL REFERENCES products(id),   -- Изделие
    child_id INTEGER NOT NULL REFERENCES products(id),    -- Компонент

    quantity NUMERIC(18,6) NOT NULL CHECK (quantity > 0), -- Количество

    PRIMARY KEY (parent_id, child_id)
);

CREATE INDEX idx_product_spec_for_product
    ON bom(parent_id);

CREATE INDEX idx_product_spec_use_product
    ON bom(child_id);
