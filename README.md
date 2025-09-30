Användarhanterings databas
En säker och optimerad databas för användarhantering med stöd för:
Registrering & verifiering,
Inloggning & kontolåsning,
Lösenordsåterställning,
Rollhantering,
Loggning av inloggningsförsök

Projektet använder SQL Server, Python och Azure Blob Storage för att visa en hel mini-pipeline.

Funktioner
SQL: 
Tabeller för användare, roller, loginförsök och lösenordsåterställning etc
Lösenord hashas med SHA2_256 + unikt salt för ökad säkerhet
Procedurer för registrering, inloggning (med kontolåsning vid 3 misslyckade försök), verifiering och lösenordsåterställning
Vyer för att analysera senaste inloggningar per användare och loginförsök per IP

Python:
login_attempts.py → genererar 800 fejkade inloggningsförsök
export_to_csv.py → exporterar data från SQL till CSV
upload_to_blob.py → laddar upp CSV till Azure Blob Storage
Azure: Säker lagring i molnet, secrets hanteras med .env.

Att köra
Klona repot
Skapa .env med din Azure connection string

Kör skripten i turordning:
login_attempts.py
export_to_csv.py
upload_to_blob.py
