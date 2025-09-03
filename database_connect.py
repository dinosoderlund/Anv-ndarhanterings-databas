# db.py
import pypyodbc as odbc

DRIVER = "ODBC Driver 17 for SQL Server" 
SERVER = r"DINOPC"                        
DATABASE = "Hederlige_Harrys_Bilar"

CONN_STR = (
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "Encrypt=no;"
)

def get_conn():
    return odbc.connect(CONN_STR)