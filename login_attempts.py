import random
import datetime as dt
from database_connect import get_conn

#list of fake ips we will randomly use in login attempts
fake_ips = ["192.168.1.2","192.168.1.3","10.0.0.8","172.16.0.22",
    "203.0.113.10","198.51.100.7","203.0.113.11","198.51.100.5"]


def random_attempts(days_back=14):
    """creates a random timestamp within the last days
    60% of the time, it will force the timestamp to fall in office hours(8 am - 5 pm)"""
    now = dt.datetime.utcnow() #get current utc time
    #subtract a random number of days, hours, and minutes to get a past time 
    t = now -dt.timedelta(days=random.randint(0, days_back), hours=random.randint(0,23), minutes=random.randint(0,59))
    #office hours
    #with 60% chance, set the time to office hours
    if random.random() < 0.6: 
        t = t.replace(hour=random.choice([8,9,10,11,12,13,14,15,16,17]), minute=random.randint(0,59), second=random.randint(0,59), microsecond=0)
    return t


def main(n=500):
    """generates n random login attempts and inserts them into database"""
    conn = get_conn() #open db connection
    cur = conn.cursor() #creates a cursor to run sql commands
    #get all existing user ids from the database 
    user_ids = [row[0] for row in cur.execute("SELECT UserID FROM dbo.USERS").fetchall()]
    if not user_ids:
        print("No users in dbo.USERS, please insert users and try again")
        conn.close()
        return
    #sql command for inserting login_attempts
    insert_sql = """
        INSERT INTO dbo.LoginAttempts(UserID, IPAddress, AttemptedAt, Success, Email)
        VALUES (?, ?, ?, ?, NULL)
    """
    rows_inserted = 0 #keeping track of amount of rows we add 
    for _ in range(n):
        #85% of time pick a real user, 15% of the time leave user empty 
        uid = random.choice(user_ids) if random.random() < 0.85 else None
        #picks random ip 
        ip = random.choice(fake_ips)
        #pick random attempt time
        t = random_attempts()
        #if the login during office hours, success is more likely 
        is_office_hour = t.hour in [8,9,10,11,12,13,14,15,16,17]
        success_prob = 0.80 if is_office_hour else 0.55
        success = 1 if random.random() < success_prob else 0
        #run the insert into sql 
        cur.execute(insert_sql, (uid, ip, t, success))
        rows_inserted +=1
    #save all inserts to the database 
    conn.commit()
    conn.close()
    print(f"inserted {rows_inserted} login attempts")
if __name__ == "__main__":
    main(800) # insert 800 fake attempts by default 