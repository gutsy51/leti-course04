import sqlite3
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / 'db.sqlite3'

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

with open('tables.sql', 'r', encoding='utf-8') as f:
    sql_script = f.read()

cur.executescript(sql_script)
conn.commit()
conn.close()

print('База данных создана: db.sqlite3')
