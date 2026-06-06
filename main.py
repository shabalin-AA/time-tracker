import sqlite3
import time
from datetime import datetime
import subprocess
import os
from dotenv import load_dotenv


load_dotenv()

project_path = os.getenv('PROJECT_PATH')
db_name = os.getenv('DB_NAME')
interval = int(os.getenv('INTERVAL_SECONDS', '600'))


def get_git_branch():
    try:
        result = subprocess.run(
            ['git', 'branch', '--show-current'],
            cwd=project_path,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip() or "unknown"
    except:
        return "unknown"

conn = sqlite3.connect(db_name)
cursor = conn.cursor()
cursor.execute('''
    CREATE TABLE IF NOT EXISTS time_tracker (
        date DATE,
        task TEXT,
        duration INTEGER
    )
''')
conn.commit()
conn.close()

while True:
    time.sleep(interval)
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()
    today = datetime.now().date()
    branch = get_git_branch()
    cursor.execute(
        "INSERT INTO time_tracker VALUES (?, ?, ?)",
        (today, branch, interval)
    )
    conn.commit()
    conn.close()
