-- Типовой технологический процесс (шаблон для изделий одного класса)
CREATE TABLE IF NOT EXISTS tech_process_template (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    applies_to_class_id INTEGER NOT NULL REFERENCES class(id),
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Операция в типовом процессе (шаблон операции)
CREATE TABLE IF NOT EXISTS template_op (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES tech_process_template(id) ON DELETE CASCADE,
    pos INTEGER NOT NULL,
    op_class_id INTEGER NOT NULL REFERENCES class(id),
    prof_class_id INTEGER NOT NULL REFERENCES class(id),
    gwc_type_id INTEGER NOT NULL REFERENCES class(id),
    qualification_id INTEGER REFERENCES enum_value(id),
    work_time REAL NOT NULL,
    UNIQUE (template_id, pos)
);

-- Ресурсы (материалы, инструменты, расходники), используемые в типовом процессе
CREATE TABLE IF NOT EXISTS template_resource (
    template_op_id INTEGER NOT NULL REFERENCES template_op(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity NUMERIC(18,6) NOT NULL,
    PRIMARY KEY (template_op_id, product_id)
);