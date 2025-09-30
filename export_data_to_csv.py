import pandas as pd
from database_connect import get_conn

def export_to_csv():
    conn = get_conn()
    query  = "SELECT * FROM dbo.LoginAttempts ORDER BY AttemptedAt DESC"
    df = pd.read_sql(query, conn)
    conn.close()

    df.to_csv("login_attempts.csv", index=False)
    print("Csv fil skapad")

if __name__ == "__main__":
    export_to_csv()