DROP TABLE IF EXISTS config_rule, rule_predicate, rule_condition CASCADE;

-- Правило конфигурации
CREATE TABLE config_rule (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Таблица предикатов (атомарных условий)
CREATE TABLE rule_predicate (
    id SERIAL PRIMARY KEY,
    parameter_id INTEGER NOT NULL REFERENCES parameter(id),
    value_int INTEGER,
    value_real REAL,
    value_str TEXT,
    enum_value_id INTEGER REFERENCES enum_value(id),
    operator TEXT NOT NULL CHECK (operator IN ('=', '!=', '>', '<', '>=', '<=', 'IN'))
);

-- Условие внутри правила
CREATE TABLE rule_condition (
    id SERIAL PRIMARY KEY,
    rule_id INTEGER NOT NULL REFERENCES config_rule(id),
    predicate_id INTEGER NOT NULL REFERENCES rule_predicate(id),
    "order" INTEGER DEFAULT 1,
    logic_op TEXT DEFAULT 'AND' CHECK (logic_op IN ('AND', 'OR'))
);

-- Расширяем таблицу bom: добавляем ссылку на config_rule
ALTER TABLE bom ADD COLUMN IF NOT EXISTS config_rule_id INTEGER REFERENCES config_rule(id);
ALTER TABLE bom ADD CONSTRAINT uk_bom_parent_child_rule UNIQUE (parent_id, child_id, config_rule_id);

CREATE INDEX IF NOT EXISTS idx_bom_config_rule ON bom(config_rule_id);