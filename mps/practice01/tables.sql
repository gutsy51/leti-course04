-- Единицы измерения.
CREATE TABLE measure (
    id serial NOT NULL,
    name character varying(64) NOT NULL,
    name_short character varying(16) NOT NULL,
    CONSTRAINT measure_id PRIMARY KEY (id),
    CONSTRAINT uq_measure_name UNIQUE (name),
    CONSTRAINT uq_measure_name_short UNIQUE (name_short)
);

-- Справочник изделий.
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,                 -- КП25.00.21.221
    name TEXT NOT NULL,                        -- Труба 25х2.5
    measure_id INTEGER REFERENCES measure(id)  -- ЕИ измерения
);

-- Связь изделий и их компонентов (parent-Трубопровод, состоит из: child-Труба, состоит из: child-Материал).
CREATE TABLE bom (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER NOT NULL REFERENCES products(id),   -- Изделие
    child_id INTEGER NOT NULL REFERENCES products(id),    -- Компонент
    quantity NUMERIC(18,6) NOT NULL CHECK (quantity > 0), -- Количество
    measure_id INTEGER NOT NULL REFERENCES measure(id)    -- ЕИ количества
);

-- Свойства материалов (для материалов, составляющих изделия).
CREATE TABLE material_properties (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    property_name TEXT NOT NULL,  -- 'Диаметр', 'Марка стали' и т.п.
    property_value TEXT NOT NULL
);
