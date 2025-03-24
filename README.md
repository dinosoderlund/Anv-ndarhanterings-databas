# Anv-ndarhanterings-databas
Beskrivning
Företaget behöver en säker och optimerad databas för användarhantering som stödjer inloggning, lösenordshantering och rollbaserad åtkomst.

Funktioner
📝 Registrering & Verifiering
Användare registreras i users-tabellen, där e-post måste vara unik och lösenord hashas med SHA2_256.

Verifiering sker via IsVerified, där 1 betyder godkänd registrering. Misslyckad verifiering returnerar ett felmeddelande.

🔐 Inloggning & Låsning
En procedur hanterar inloggning och returnerar "lyckades" eller "misslyckades".

Efter tre misslyckade försök låses kontot i 15 minuter.

🔄 Lösenordsåterställning
En token genereras vid återställning och lagras i password_reset.

Procedurer hanterar både token-generering och lösenordsändring, med validering av e-post och token.

👥 Rollhantering
Roller definieras i roles och kopplas till användare via user_roles.

📊 Logghantering
user_login_summary: Visar senaste inloggningar (1 = lyckad, 0 = misslyckad).

login_attempts_by_IP: Rapporterar inloggningsförsök per IP.

⚡ Prestandaoptimering
Indexering av UserID, email, attemptedAt, reset_token och RoleID för snabbare sökningar.

