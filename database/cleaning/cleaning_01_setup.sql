USE HR_Analytics_DB;
GO

IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
GO

DROP TABLE IF EXISTS stg.CleaningLog, stg.RejectedRows;

-- One row per cleaning action: what was wrong, what we did, how many rows
CREATE TABLE stg.CleaningLog (
    log_id        INT IDENTITY(1,1) PRIMARY KEY,
    table_name    VARCHAR(40)  NOT NULL,
    issue         VARCHAR(150) NOT NULL,
    action_taken  VARCHAR(15)  NOT NULL,      -- FIXED / REMOVED / REJECTED / KEPT
    rows_affected INT          NOT NULL,
    logged_at     DATETIME2    NOT NULL DEFAULT SYSDATETIME()
);

-- Quarantine: rows we could not trust, with the reason (for HR follow-up)
CREATE TABLE stg.RejectedRows (
    reject_id   INT IDENTITY(1,1) PRIMARY KEY,
    table_name  VARCHAR(40)  NOT NULL,
    stg_row_id  INT          NULL,            -- links back to the raw staging row
    reason      VARCHAR(150) NOT NULL,
    employee_id VARCHAR(100) NULL,
    raw_value   VARCHAR(300) NULL,
    logged_at   DATETIME2    NOT NULL DEFAULT SYSDATETIME()
);
GO