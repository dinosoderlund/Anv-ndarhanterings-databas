-- Skapar Databas
USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'Hederlige_Harrys_Bilar')
BEGIN
    ALTER DATABASE Hederlige_Harrys_Bilar SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Hederlige_Harrys_Bilar;
END
CREATE DATABASE Hederlige_Harrys_Bilar;
GO

USE Hederlige_Harrys_Bilar;
GO

-- Skapar table f�r anv�ndare
CREATE TABLE USERS(
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Email NVARCHAR(255) NOT NULL UNIQUE,
    PasswordHash VARBINARY(64) NOT NULL,
	--Uppdaterad kod lagt till Salt
	Salt NVARCHAR(60) NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    StreetAddress NVARCHAR(255) NOT NULL,
    PostalCode NVARCHAR(20) NOT NULL,
    City NVARCHAR(100) NOT NULL,
    Country NVARCHAR(100) NOT NULL,
    PhoneNumber NVARCHAR(50),
    IsVerified BIT NOT NULL DEFAULT 0,
    IsLockedOut BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NOT NULL DEFAULT GETDATE()
	
	
);
 

CREATE TABLE EmailVerificationToken(
    TokenID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    Token NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE
);

-- Skapar table f�r olika roller
CREATE TABLE Roles(
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);

-- Skapar table f�r olika roller anv�ndare kan ha
CREATE TABLE UserRoles(
    UserRoleID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    RoleID INT NOT NULL,
    AssignedAt DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE,
    FOREIGN KEY(RoleID) REFERENCES Roles(RoleID) ON DELETE CASCADE
);

-- Skapar table som h�ller koll p� hur m�nga g�nger en anv�ndare har f�rs�kt logga in
CREATE TABLE LoginAttempts(
    LoginAttemptID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NULL,
    IPAddress NVARCHAR(45) NOT NULL,
    AttemptedAt DATETIME NOT NULL DEFAULT GETDATE(),
    Success BIT NOT NULL,
    Email NVARCHAR(255) NULL,
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE SET NULL
);

-- Skapar table f�r att �terst�lla password
CREATE TABLE PasswordResetTokens(
    TokenID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    ResetToken NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    ExpiryTime DATETIME NOT NULL,
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE
);

-- Skapar index
CREATE INDEX IX_USERS ON USERS(Email);
CREATE INDEX IX_EmailVerificationToken_UserID ON EmailVerificationToken(UserID);
CREATE INDEX IX_Loginattempts_UserID ON Loginattempts(UserID);
CREATE INDEX IX_Loginattempts_AttemptedAt ON Loginattempts(AttemptedAt);
CREATE INDEX IX_UserRoles_UserID ON UserRoles(UserID);
CREATE INDEX IX_UserRoles_RoleID ON UserRoles(RoleID);
CREATE INDEX IX_PasswordResetTokens_UserID ON PasswordResetTokens(UserID);
CREATE INDEX IX_PasswordResetTokens_ResetToken ON PasswordResetTokens(ResetToken);

-- L�gger till roller
INSERT INTO Roles(RoleName) VALUES('Customer');
INSERT INTO Roles(RoleName) VALUES('Admin');
GO

-- Procedur f�r att registrera anv�ndare
CREATE PROCEDURE RegistreraAnv�ndare
    @Email NVARCHAR(255),
    @Password NVARCHAR(255),
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @StreetAddress NVARCHAR(255),
    @PostalCode NVARCHAR(20),
    @City NVARCHAR(100),
    @Country NVARCHAR(100),
    @PhoneNumber NVARCHAR(20)
AS
BEGIN
    DECLARE @UserID INT;
    DECLARE @Token NVARCHAR(255) = NEWID();
	--Deklarerar ett slumpm�ssigt Salt 
	--Uppdaterad kod
	DECLARE @Salt NVARCHAR(60) = CONVERT(NVARCHAR(60), CRYPT_GEN_RANDOM(32), 2) 

    IF EXISTS(SELECT 1 FROM USERS WHERE Email = @Email)
    BEGIN
        PRINT 'Epost Adressen �r redan registerad i databasen';
        RETURN;
    END;

    -- Hasha l�senordet
	--Salta l�senordet
	--Uppdaterad kod med salt
	DECLARE @SaltedPassword NVARCHAR(255) = @Password + @Salt;
    DECLARE @PasswordHash VARBINARY(64) = HASHBYTES('SHA2_256', @SaltedPassword);
    INSERT INTO USERS(FirstName, LastName, Email, PasswordHash, Salt, StreetAddress, PostalCode, City, Country, PhoneNumber, IsVerified, IsLockedOut)
    VALUES(@FirstName, @LastName, @Email, @PasswordHash, @Salt, @StreetAddress, @PostalCode, @City, @Country, @PhoneNumber, 0, 0);

    SET @UserID = SCOPE_IDENTITY();

    INSERT INTO EmailVerificationToken(UserID, Token)
    VALUES(@UserID, @Token);

    PRINT 'Din verifieringsl�nk: https://exempel.com/verifiera?token=' + @Token;
END;
GO

-- Procedur f�r att verifiera e-post
CREATE PROCEDURE ConfirmEmailVerification
    @Token NVARCHAR(255)
AS 
BEGIN
    DECLARE @UserID INT;

    SELECT @UserID = UserID 
    FROM EmailVerificationToken 
    WHERE Token = @Token;

    IF @UserID IS NULL
    BEGIN
        PRINT 'Ogiltig token';
        RETURN;
    END;

    UPDATE USERS 
    SET IsVerified = 1 
    WHERE UserID = @UserID;

    DELETE FROM EmailVerificationToken 
    WHERE Token = @Token;

    PRINT 'Ditt konto �r nu verifierat!';
END;
GO

-- Procedur f�r att hantera inloggning
CREATE PROCEDURE LoginManagement
    @Email NVARCHAR(255),
    @Password NVARCHAR(255),
    @IPAddress NVARCHAR(45)
AS 
BEGIN
--Temp tabell
CREATE TABLE #templogs(
LogID INT IDENTITY(1,1) PRIMARY KEY,
Message NVARCHAR(255),
LogTime DATETIME DEFAULT GETDATE()
)
	--Uppdaterad kod med declare @Salt
    DECLARE @UserID INT, @PasswordHash VARBINARY(64), @Salt NVARCHAR(60), @IsLockedOut BIT, @FailedAttempts INT;
	DECLARE @ResultCode INT = 0 --Inneb�r lyckad inloggning
	DECLARE @ErrorMessage NVARCHAR(255) = ''
	--Uppdaterad kod med Salt
    SELECT @UserID = UserID, @PasswordHash = PasswordHash, @Salt = Salt, @IsLockedOut = IsLockedOut
    FROM USERS
    WHERE Email = @Email;

    IF @UserID IS NULL
    BEGIN
        SET @ResultCode = -1 --Ogiltig anv�ndare
		SET @ErrorMessage = 'Anv�ndaren finns inte'
		INSERT INTO #templogs (Message) VALUES(@ErrorMessage)
		PRINT @ErrorMessage
		SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage
        RETURN
    END

    IF @IsLockedOut = 1
    BEGIN
       SET @ResultCode = -2 --L�st konto
	   SET @ErrorMessage = 'Kontot �r l�st'
	   INSERT INTO #templogs(Message) VALUES(@ErrorMessage)
	   PRINT @ErrorMessage
	   SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage
        RETURN;
    END;
	--Uppdaterad kod med declare Saltedpassword

	 DECLARE @SaltedPassword NVARCHAR(255) = @Password + @Salt;
    DECLARE @HashedPassword VARBINARY(64) = HASHBYTES('SHA2_256', @SaltedPassword);
	--Uppdaterad kod d�r jag l�gger till Salt i passwordhash
    IF @PasswordHash = HASHBYTES('SHA2_256', @Password + @Salt)
    BEGIN 
        INSERT INTO LoginAttempts(UserID, IPAddress, Success, AttemptedAt)
        VALUES(@UserID, @IPAddress, 1, GETDATE());
        
		SET @ErrorMessage = 'Inloggningen lyckades'
		INSERT INTO #templogs (Message) VALUES(@ErrorMessage)
		PRINT @ErrorMessage
    END 
    ELSE
    BEGIN
        INSERT INTO LoginAttempts(UserID, IPAddress, Success, AttemptedAt)
        VALUES(@UserID, @IPAddress, 0, GETDATE());
        
		SET @ErrorMessage = 'Inloggningen misslyckades'
		INSERT INTO #templogs(Message) VALUES(@ErrorMessage)
		PRINT @ErrorMessage

        -- Kontrollera om anv�ndarens konto ska bli l�st
        SELECT @FailedAttempts = COUNT(*)
        FROM LoginAttempts
        WHERE UserID = @UserID AND Success = 0 AND AttemptedAt > DATEADD(MINUTE, -15, GETDATE());

        IF @FailedAttempts >= 3
        BEGIN 
            UPDATE USERS 
            SET IsLockedOut = 1 
            WHERE UserID = @UserID;
            
			SET @ResultCode = -3
			SET @ErrorMessage = 'Ditt konto l�ser sig d� inloggning misslyckades tre g�nger'
			INSERT INTO #templogs(Message) VALUES(@ErrorMessage)
			PRINT @ErrorMessage
        END
        ELSE
        BEGIN 
            SET @ResultCode = -4
			SET @ErrorMessage = 'Felaktigt l�senord'
			INSERT INTO #templogs(Message) VALUES(@ErrorMessage)
			PRINT @ErrorMessage
        END;
    END;
	SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage
	SELECT * FROM #templogs --Visar den tempor�ra logg tabel f�r testning
END;
GO

-- Procedur f�r �terst�llning av l�senord
CREATE PROCEDURE ForgotPassword
    @Email NVARCHAR(255)
AS 
BEGIN 
    DECLARE @UserID INT;

    SELECT @UserID = UserID
    FROM USERS
    WHERE Email = @Email;

    IF @UserID IS NULL
    BEGIN
        PRINT 'EpostAdressen finns inte';
        RETURN;
    END;

    DECLARE @Token NVARCHAR(255) = NEWID();

    INSERT INTO PasswordResetTokens (UserID, ResetToken, ExpiryTime)
    VALUES(@UserID, @Token, DATEADD(HOUR, 24, GETDATE()));

    PRINT 'Din token f�r att �terst�lla kontot �r nu skapat: ' + @Token;
END;
GO

-- Procedur f�r att �terst�lla l�senord
CREATE PROCEDURE FixForgottenPassword
    @Email NVARCHAR(255),
    @NewPassword NVARCHAR(255),
    @Token NVARCHAR(255)
AS 
BEGIN
    DECLARE @UserID INT, @ExpirationDate DATETIME, @Salt NVARCHAR(60)

    SELECT @UserID = UserID, @ExpirationDate = ExpiryTime
    FROM PasswordResetTokens
    WHERE ResetToken = @Token;

    IF @UserID IS NULL OR @ExpirationDate < GETDATE()
    BEGIN 
        PRINT 'Ogiltigt eller expired token';
        RETURN;
    END;
	--Uppdaterad kod d�r jag konverterar och genererar slumpm�ssigt salt
	 SET @Salt = CONVERT(NVARCHAR(60), CRYPT_GEN_RANDOM(32), 2)
	 DECLARE @SaltedPassword NVARCHAR(255) = @NewPassword + @Salt;
    DECLARE @PasswordHash VARBINARY(64) = HASHBYTES('SHA2_256', @SaltedPassword);
	--Uppdaterad kod d�r jag l�gger Salt = @Salt
    UPDATE USERS
    SET PasswordHash = @PasswordHash, Salt = @Salt
    WHERE UserID = @UserID;

    DELETE FROM PasswordResetTokens 
    WHERE ResetToken = @Token;

    PRINT 'L�senordet har nu uppdaterats';
END;
GO

EXEC RegistreraAnv�ndare
    @Email = 'test@exempel.com',
    @Password = '123',
    @FirstName = 'Di',
    @LastName = 'S�de',
    @StreetAddress = 'exempel address',
    @PostalCode = '54321',
    @City = 'Stockholm',
    @Country = 'Sverige',
    @PhoneNumber = '0701234567';

EXEC ConfirmEmailVerification @Token = 'Genereradtoken1';

EXEC RegistreraAnv�ndare
    @Email = 'test@exempel2.com',
    @Password = '321@E�%',
    @FirstName = 'Leonard',
    @LastName = 'ardo',
    @StreetAddress = 'exempel adress 2',
    @PostalCode = '54321',
    @City = 'Malm�',
    @Country = 'Sverige',
    @PhoneNumber = '0702134576';

EXEC ConfirmEmailVerification @Token = 'Genereradtoken2';

EXEC RegistreraAnv�ndare
    @Email = 'test@exempel3.com',
    @Password = '510@#',
    @FirstName = 'Exempel',
    @LastName = 'Namn',
    @StreetAddress = 'exempel adress 3',
    @PostalCode = '19321',
    @City = 'Stockholm',
    @Country = 'Sverige',
    @PhoneNumber = '0702214576';

EXEC ConfirmEmailVerification @Token = 'Genereradtoken3';

-- Simulera inloggningsf�rs�k
EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- Lyckat f�rs�k

EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- Misslyckat f�rs�k

EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- Misslyckat f�rs�k

EXEC LoginManagement
    @Email = 'test@exempel2.com',
    @Password = '321@E�%',
    @IPAddress = '192.168.1.2'; -- Lyckat f�rs�k


	--La bara till anv�ndare3 snabbt f�r att visa att konto l�ser sig
	--Anv�nder inte den i resten av testningen f�r den anledningen 
	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- Misslyckat f�rs�k

	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- Misslyckat f�rs�k


	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- Misslyckat f�rs�k

-- Tilldela roller till anv�ndare
DECLARE @CustomerRoleID INT, @AdminRoleID INT, @User1ID INT, @User2ID INT;

SELECT @CustomerRoleID = RoleID FROM Roles WHERE RoleName = 'Customer';
SELECT @AdminRoleID = RoleID FROM Roles WHERE RoleName = 'Admin';

SELECT @User1ID = UserID FROM USERS WHERE Email = 'test@exempel.com';
SELECT @User2ID = UserID FROM USERS WHERE Email = 'test@exempel2.com';

INSERT INTO UserRoles(UserID, RoleID)
VALUES(@User1ID, @CustomerRoleID),
      (@User2ID, @AdminRoleID);

-- Testa �terst�llning av l�senord
EXEC ForgotPassword @Email = 'test@exempel.com';

DECLARE @ResetToken NVARCHAR(255);
SELECT @ResetToken = ResetToken FROM PasswordResetTokens WHERE UserID = @User1ID;

EXEC FixForgottenPassword
    @Email = 'test@exempel.com',
    @NewPassword = '123@13',
    @Token = @ResetToken;



-- Skapa vyer
--Succes �r 1 f�r lyckad inloggning, succes = 0 �r misslyckad inloggning
GO
CREATE VIEW UserLoginSummary AS
WITH LatestLogins AS (
    SELECT
        UserID,
        MAX(CASE WHEN Success = 1 THEN AttemptedAt END) AS LastSuccessfullLogin,
        MAX(CASE WHEN Success = 0 THEN AttemptedAt END) AS LastFailedLogin
    FROM LoginAttempts
    GROUP BY UserID
)
SELECT 
    u.Email,
    u.FirstName,
    u.LastName,
    l.LastSuccessfullLogin,
    l.LastFailedLogin
FROM USERS u
LEFT JOIN LatestLogins l ON u.UserID = l.UserID;
GO
--Liknande view h�r bara att jag fokuserar mer p� ip address
CREATE VIEW LoginAttemptsByIP AS
SELECT 
    IPAddress, 
    COUNT(*) AS TotalAttempts,
    SUM(CASE WHEN Success = 1 THEN 1 ELSE 0 END) AS SuccessfulAttempts,
    SUM(CASE WHEN Success = 0 THEN 1 ELSE 0 END) AS FailedAttempts,
    AVG(CASE WHEN Success = 1 THEN 1.0 ELSE 0.0 END) AS SuccessRate
FROM LoginAttempts 
GROUP BY IPAddress;
GO

-- Testa vyer
SELECT * FROM UserLoginSummary;
SELECT * FROM LoginAttemptsByIP;

