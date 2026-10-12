--01_create_database.sql--

USE master;
GO

IF DB_ID('HR_Analytics_DB') IS NULL
BEGIN
    CREATE DATABASE HR_Analytics_DB;
END
GO

USE HR_Analytics_DB;
GO