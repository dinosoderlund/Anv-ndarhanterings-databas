--Creating the database 
IF DB_ID('Hederlige_Harrys_Bilar') IS NULL
    CREATE DATABASE Hederlige_Harrys_Bilar;
GO
USE Hederlige_Harrys_Bilar;
GO


--table for users 
IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
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
END
 --table for verification token 
 IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
CREATE TABLE EmailVerificationToken(
    TokenID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    Token NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE
);
END

-- Creating table for the different roles 
IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
CREATE TABLE Roles(
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
END
-- table for user role 
IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
CREATE TABLE UserRoles(
    UserRoleID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    RoleID INT NOT NULL,
    AssignedAt DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE,
    FOREIGN KEY(RoleID) REFERENCES Roles(RoleID) ON DELETE CASCADE
);
END

-- table for keeping track of login attempts 
IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
CREATE TABLE LoginAttempts(
    LoginAttemptID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NULL,
    IPAddress NVARCHAR(45) NOT NULL,
    AttemptedAt DATETIME NOT NULL DEFAULT GETDATE(),
    Success BIT NOT NULL,
    Email NVARCHAR(255) NULL,
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE SET NULL
);
END

--table for resetting password 
IF OBJECT_ID('dbo.USERS', 'U') IS NULL
BEGIN
CREATE TABLE PasswordResetTokens(
    TokenID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    ResetToken NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    ExpiryTime DATETIME NOT NULL,
    FOREIGN KEY(UserID) REFERENCES USERS(UserID) ON DELETE CASCADE
);
END

--creating index for better performance 
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_USERS' AND object_id = OBJECT_ID('dbo.USERS')
)
    CREATE INDEX IX_USERS ON dbo.USERS(Email);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_EmailVerificationToken_UserID' AND object_id = OBJECT_ID('dbo.EmailVerificationToken')
)
    CREATE INDEX IX_EmailVerificationToken_UserID ON dbo.EmailVerificationToken(UserID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_LoginAttempts_UserID' AND object_id = OBJECT_ID('dbo.LoginAttempts')
)
    CREATE INDEX IX_LoginAttempts_UserID ON dbo.LoginAttempts(UserID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_LoginAttempts_AttemptedAt' AND object_id = OBJECT_ID('dbo.LoginAttempts')
)
    CREATE INDEX IX_LoginAttempts_AttemptedAt ON dbo.LoginAttempts(AttemptedAt);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_UserRoles_UserID' AND object_id = OBJECT_ID('dbo.UserRoles')
)
    CREATE INDEX IX_UserRoles_UserID ON dbo.UserRoles(UserID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_UserRoles_RoleID' AND object_id = OBJECT_ID('dbo.UserRoles')
)
    CREATE INDEX IX_UserRoles_RoleID ON dbo.UserRoles(RoleID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_PasswordResetTokens_UserID' AND object_id = OBJECT_ID('dbo.PasswordResetTokens')
)
    CREATE INDEX IX_PasswordResetTokens_UserID ON dbo.PasswordResetTokens(UserID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_PasswordResetTokens_ResetToken' AND object_id = OBJECT_ID('dbo.PasswordResetTokens')
)
    CREATE INDEX IX_PasswordResetTokens_ResetToken ON dbo.PasswordResetTokens(ResetToken);
GO


-- inserting roles 
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = 'Customer')
    INSERT INTO dbo.Roles(RoleName) VALUES ('Customer');

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = 'Admin')
    INSERT INTO dbo.Roles(RoleName) VALUES ('Admin');
GO



-- procedure for registering user 
CREATE OR ALTER PROCEDURE dbo.RegistreraAnvändare
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
    SET NOCOUNT ON;

    DECLARE @UserID INT;
    DECLARE @Token NVARCHAR(255) = NEWID();
    DECLARE @Salt  NVARCHAR(60)  = CONVERT(NVARCHAR(60), CRYPT_GEN_RANDOM(32), 2);

    IF EXISTS(SELECT 1 FROM dbo.USERS WHERE Email = @Email)
    BEGIN
        PRINT N'Epost Adressen är redan registerad i databasen';
        RETURN;
    END;
	--password hashing sha 256
    DECLARE @SaltedPassword NVARCHAR(255) = @Password + @Salt;
    DECLARE @PasswordHash VARBINARY(64)   = HASHBYTES('SHA2_256', @SaltedPassword);

    INSERT INTO dbo.USERS(FirstName, LastName, Email, PasswordHash, Salt,
                          StreetAddress, PostalCode, City, Country, PhoneNumber,
                          IsVerified, IsLockedOut)
    VALUES(@FirstName, @LastName, @Email, @PasswordHash, @Salt,
           @StreetAddress, @PostalCode, @City, @Country, @PhoneNumber,
           0, 0);

    SET @UserID = SCOPE_IDENTITY();

    INSERT INTO dbo.EmailVerificationToken(UserID, Token)
    VALUES(@UserID, @Token);

    PRINT N'Din verifieringslänk: https://exempel.com/verifiera?token=' + @Token;
END;
GO


-- confirming email verification
CREATE OR ALTER PROCEDURE dbo.ConfirmEmailVerification
    @Token NVARCHAR(255)
AS 
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT;

    SELECT @UserID = UserID 
    FROM dbo.EmailVerificationToken 
    WHERE Token = @Token;

    IF @UserID IS NULL
    BEGIN
        PRINT N'Ogiltig token';
        RETURN;
    END;

    UPDATE dbo.USERS 
    SET IsVerified = 1 
    WHERE UserID = @UserID;

    DELETE FROM dbo.EmailVerificationToken 
    WHERE Token = @Token;

    PRINT N'Ditt konto är nu verifierat!';
END;
GO


-- manage login 
CREATE OR ALTER PROCEDURE dbo.LoginManagement
    @Email NVARCHAR(255),
    @Password NVARCHAR(255),
    @IPAddress NVARCHAR(45)
AS 
BEGIN
    SET NOCOUNT ON;

    -- Temp-table for messages
    CREATE TABLE #templogs(
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        Message NVARCHAR(255),
        LogTime DATETIME DEFAULT GETDATE()
    );

    DECLARE @UserID INT,
            @PasswordHash VARBINARY(64),
            @Salt NVARCHAR(60),
            @IsLockedOut BIT,
            @FailedAttempts INT;
	-- 0 = succeded login, -1 = user does not exist, -2 = locked account
    DECLARE @ResultCode  INT = 0;        
    DECLARE @ErrorMessage NVARCHAR(255) = N'';

    SELECT @UserID = UserID,
           @PasswordHash = PasswordHash,
           @Salt = Salt,
           @IsLockedOut = IsLockedOut
    FROM dbo.USERS
    WHERE Email = @Email;

    IF @UserID IS NULL
    BEGIN
        SET @ResultCode  = -1; 
        SET @ErrorMessage = N'Användaren finns inte';
        INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
        PRINT @ErrorMessage;
        SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage;
        RETURN;
    END;

    IF @IsLockedOut = 1
    BEGIN
        SET @ResultCode  = -2;
        SET @ErrorMessage = N'Kontot är låst';
        INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
        PRINT @ErrorMessage;
        SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage;
        RETURN;
    END;
	--hashing
    DECLARE @SaltedPassword NVARCHAR(255) = @Password + @Salt;
    DECLARE @HashedPassword VARBINARY(64) = HASHBYTES('SHA2_256', @SaltedPassword);

    IF @PasswordHash = @HashedPassword
    BEGIN 
        INSERT INTO dbo.LoginAttempts(UserID, IPAddress, Success, AttemptedAt)
        VALUES(@UserID, @IPAddress, 1, GETDATE());
        
        SET @ErrorMessage = N'Inloggningen lyckades';
        INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
        PRINT @ErrorMessage;
    END 
    ELSE
    BEGIN
        INSERT INTO dbo.LoginAttempts(UserID, IPAddress, Success, AttemptedAt)
        VALUES(@UserID, @IPAddress, 0, GETDATE());
        
        SET @ErrorMessage = N'Inloggningen misslyckades';
        INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
        PRINT @ErrorMessage;

        -- locked if tries >= 3 for 15 min 
        SELECT @FailedAttempts = COUNT(*)
        FROM dbo.LoginAttempts
        WHERE UserID = @UserID
          AND Success = 0
          AND AttemptedAt > DATEADD(MINUTE, -15, GETDATE());

        IF @FailedAttempts >= 3
        BEGIN 
            UPDATE dbo.USERS 
            SET IsLockedOut = 1 
            WHERE UserID = @UserID;
            
            SET @ResultCode  = -3;
            SET @ErrorMessage = N'Ditt konto låser sig då inloggning misslyckades tre gånger';
            INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
            PRINT @ErrorMessage;
        END
        ELSE
        BEGIN 
            SET @ResultCode  = -4;
            SET @ErrorMessage = N'Felaktigt lösenord';
            INSERT INTO #templogs (Message) VALUES(@ErrorMessage);
            PRINT @ErrorMessage;
        END;
    END;

    SELECT @ResultCode AS ResultCode, @ErrorMessage AS ErrorMessage;
    SELECT * FROM #templogs; -- shows temp logs for testing 
END;
GO


-- creating token for resetting password 
CREATE OR ALTER PROCEDURE dbo.ForgotPassword
    @Email NVARCHAR(255)
AS 
BEGIN 
    SET NOCOUNT ON;

    DECLARE @UserID INT;

    SELECT @UserID = UserID
    FROM dbo.USERS
    WHERE Email = @Email;

    IF @UserID IS NULL
    BEGIN
        PRINT N'EpostAdressen finns inte';
        RETURN;
    END;

    DECLARE @Token NVARCHAR(255) = NEWID();

    INSERT INTO dbo.PasswordResetTokens (UserID, ResetToken, ExpiryTime)
    VALUES(@UserID, @Token, DATEADD(HOUR, 24, GETDATE()));

    PRINT N'Din token för att återställa kontot är nu skapat: ' + @Token;
END;
GO


-- reset password with token 
CREATE OR ALTER PROCEDURE dbo.FixForgottenPassword
    @Email NVARCHAR(255),
    @NewPassword NVARCHAR(255),
    @Token NVARCHAR(255)
AS 
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT, @ExpirationDate DATETIME, @Salt NVARCHAR(60);

    SELECT @UserID = UserID, @ExpirationDate = ExpiryTime
    FROM dbo.PasswordResetTokens
    WHERE ResetToken = @Token;

    IF @UserID IS NULL OR @ExpirationDate < GETDATE()
    BEGIN 
        PRINT N'Ogiltigt eller expired token';
        RETURN;
    END;
	--hashing
    SET @Salt = CONVERT(NVARCHAR(60), CRYPT_GEN_RANDOM(32), 2);
    DECLARE @SaltedPassword NVARCHAR(255) = @NewPassword + @Salt;
    DECLARE @PasswordHash VARBINARY(64)   = HASHBYTES('SHA2_256', @SaltedPassword);

    UPDATE dbo.USERS
    SET PasswordHash = @PasswordHash,
        Salt = @Salt
    WHERE UserID = @UserID;

    DELETE FROM dbo.PasswordResetTokens 
    WHERE ResetToken = @Token;

    PRINT N'Lösenordet har nu uppdaterats';
END;
GO

--inserting some fake users 
EXEC RegistreraAnvändare
    @Email = 'test@exempel.com',
    @Password = '123',
    @FirstName = 'Di',
    @LastName = 'Söde',
    @StreetAddress = 'exempel address',
    @PostalCode = '54321',
    @City = 'Stockholm',
    @Country = 'Sverige',
    @PhoneNumber = '0701234567';

EXEC ConfirmEmailVerification @Token = 'Genereradtoken1';

EXEC RegistreraAnvändare
    @Email = 'test@exempel2.com',
    @Password = '321@E¤%',
    @FirstName = 'Leonard',
    @LastName = 'ardo',
    @StreetAddress = 'exempel adress 2',
    @PostalCode = '54321',
    @City = 'Malmö',
    @Country = 'Sverige',
    @PhoneNumber = '0702134576';

EXEC ConfirmEmailVerification @Token = 'Genereradtoken2';

EXEC RegistreraAnvändare
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

-- simulating login attempts
EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- success

EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- failed

EXEC LoginManagement
    @Email = 'test@exempel.com',
    @Password = '123',
    @IPAddress = '192.158.1.38'; -- failed

EXEC LoginManagement
    @Email = 'test@exempel2.com',
    @Password = '321@E¤%',
    @IPAddress = '192.168.1.2'; -- success


	--inserting another user to show how locked account works
	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- failed

	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- failed


	EXEC LoginManagement
    @Email = 'test@exempel3.com',
    @Password = '123',
    @IPAddress = '192.158.2.38'; -- failed

-- giving roles to users 
DECLARE @CustomerRoleID INT, @AdminRoleID INT, @User1ID INT, @User2ID INT;

SELECT @CustomerRoleID = RoleID FROM Roles WHERE RoleName = 'Customer';
SELECT @AdminRoleID = RoleID FROM Roles WHERE RoleName = 'Admin';

SELECT @User1ID = UserID FROM USERS WHERE Email = 'test@exempel.com';
SELECT @User2ID = UserID FROM USERS WHERE Email = 'test@exempel2.com';

INSERT INTO UserRoles(UserID, RoleID)
VALUES(@User1ID, @CustomerRoleID),
      (@User2ID, @AdminRoleID);

-- testing to reset password 
EXEC ForgotPassword @Email = 'test@exempel.com';

DECLARE @ResetToken NVARCHAR(255);
SELECT @ResetToken = ResetToken FROM PasswordResetTokens WHERE UserID = @User1ID;

EXEC FixForgottenPassword
    @Email = 'test@exempel.com',
    @NewPassword = '123@13',
    @Token = @ResetToken;



-- views
--success: success = 1, failed: success = 0 
GO
CREATE OR ALTER VIEW dbo.UserLoginSummary
AS
WITH LatestLogins AS (
    SELECT
        la.UserID,
        MAX(CASE WHEN la.Success = 1 THEN la.AttemptedAt END) AS LastSuccessfullLogin,
        MAX(CASE WHEN la.Success = 0 THEN la.AttemptedAt END) AS LastFailedLogin
    FROM dbo.LoginAttempts AS la
    GROUP BY la.UserID
)
SELECT 
    u.Email,
    u.FirstName,
    u.LastName,
    l.LastSuccessfullLogin,
    l.LastFailedLogin
FROM dbo.USERS AS u
LEFT JOIN LatestLogins AS l
    ON u.UserID = l.UserID;
GO


--showing login attempts by ip 
GO
CREATE OR ALTER VIEW dbo.LoginAttemptsByIP
AS
SELECT 
    la.IPAddress, 
    COUNT(*) AS TotalAttempts,
    SUM(CASE WHEN la.Success = 1 THEN 1 ELSE 0 END) AS SuccessfulAttempts,
    SUM(CASE WHEN la.Success = 0 THEN 1 ELSE 0 END) AS FailedAttempts,
    AVG(CASE WHEN la.Success = 1 THEN 1.0 ELSE 0.0 END) AS SuccessRate
FROM dbo.LoginAttempts AS la
GROUP BY la.IPAddress;
GO

-- demo 
SELECT * FROM UserLoginSummary;
SELECT * FROM LoginAttemptsByIP;
SELECT COUNT(*) AS total FROM dbo.LoginAttempts;
SELECT TOP 30 * FROM dbo.LoginAttempts ORDER BY LoginAttemptID DESC;

