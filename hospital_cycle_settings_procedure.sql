-- =============================================
-- 병원별 재고조사 주기 설정 프로시저 (SQL Server용)
-- 한 번에 복사해서 실행하세요
-- =============================================

-- 1. 기존 프로시저들 삭제
IF OBJECT_ID('USP_M_MEK_UPDATE_SAVE_HOSPITAL_CYCLE_SETTINGS', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_UPDATE_SAVE_HOSPITAL_CYCLE_SETTINGS
GO

IF OBJECT_ID('USP_M_MEK_GET_HOSPITAL_CYCLE_SETTINGS', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_GET_HOSPITAL_CYCLE_SETTINGS
GO

IF OBJECT_ID('USP_M_MEK_DELETE_HOSPITAL_CYCLE_SETTINGS', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_DELETE_HOSPITAL_CYCLE_SETTINGS
GO

IF OBJECT_ID('USP_M_MEK_UPDATE_HOSPITAL_CYCLE_SETTINGS', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_UPDATE_HOSPITAL_CYCLE_SETTINGS
GO

IF OBJECT_ID('USP_M_MEK_BULK_UPDATE_HOSPITAL_CYCLE_SETTINGS', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_BULK_UPDATE_HOSPITAL_CYCLE_SETTINGS
GO

IF OBJECT_ID('USP_M_MEK_SURVEY_NEEDED_HOSPITALS_GET', 'P') IS NOT NULL
    DROP PROCEDURE USP_M_MEK_SURVEY_NEEDED_HOSPITALS_GET
GO

-- 2. 병원별 재고조사 주기 설정 저장 프로시저
CREATE PROCEDURE [dbo].[USP_M_MEK_UPDATE_SAVE_HOSPITAL_CYCLE_SETTINGS]
    @trCd NVARCHAR(10),
    @cycleSettings NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 기존 설정 삭제 (해당 대리점의 모든 설정)
        UPDATE M_MEK_STRADE_HOSPITAL_CELL 
        SET SURVEY_CYCLE_TYPE = NULL,
            SURVEY_CYCLE_VALUE = NULL,
            UPDATED_BY = 'SYSTEM',
            UPDATED_AT = GETDATE()
        WHERE TR_CD = @trCd;
        
        -- 새로운 설정 저장
        UPDATE M_MEK_STRADE_HOSPITAL_CELL 
        SET SURVEY_CYCLE_TYPE = 'DAYS',
            SURVEY_CYCLE_VALUE = CAST(JSON_VALUE(value, '$.cycle') AS NVARCHAR(50)),
            UPDATED_BY = 'SYSTEM',
            UPDATED_AT = GETDATE()
        FROM M_MEK_STRADE_HOSPITAL_CELL hc
        INNER JOIN OPENJSON(@cycleSettings) ON 
            hc.HOSPITAL_ID = JSON_VALUE(value, '$.hospitalId') 
            AND hc.CELL_ID = JSON_VALUE(value, '$.warehouseId')
        WHERE hc.TR_CD = @trCd;
        
        COMMIT TRANSACTION;
        
        -- 성공 결과 반환
        SELECT 
            'success' AS status,
            '병원별 재고조사 주기 설정이 성공적으로 저장되었습니다.' AS message,
            @@ROWCOUNT AS affectedRows;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();
            
        -- 에러 결과 반환
        SELECT 
            'error' AS status,
            '저장 중 오류가 발생했습니다: ' + @ErrorMessage AS message,
            0 AS affectedRows;
            
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- 3. 병원별 재고조사 주기 설정 조회 프로시저 (수정된 JOIN 구조)
CREATE PROCEDURE [dbo].[USP_M_MEK_GET_HOSPITAL_CYCLE_SETTINGS]
    @trCd NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        SELECT 
            hc.HOSPITAL_ID AS hospitalId,
            hc.CELL_ID AS warehouseId,
            hc.SURVEY_CYCLE_TYPE AS cycleType,
            hc.SURVEY_CYCLE_VALUE AS cycle,
            hc.UPDATED_BY AS updatedBy,
            hc.UPDATED_AT AS updatedAt,
            h.[의료기관명] AS hospitalName,  -- M_MEK_PD_HOSPITAL 테이블의 의료기관명
            c.CELL_NAME AS warehouseName,   -- M_MEK_COMM_HOSPITAL_CELL 테이블의 CELL_NAME
            -- 마지막 조사일
            (SELECT MAX(CHECK_DT) 
             FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
             WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
               AND CELL_ID = hc.CELL_ID) AS lastSurveyDate,
            -- 경과일
            DATEDIFF(DAY, 
                    (SELECT MAX(CHECK_DT) 
                     FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                     WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                       AND CELL_ID = hc.CELL_ID), 
                    GETDATE()) AS daysSinceLastSurvey
        FROM M_MEK_STRADE_HOSPITAL_CELL hc
        INNER JOIN M_MEK_PD_HOSPITAL h ON hc.HOSPITAL_ID = h.HOSPITAL_ID    -- 병원 정보 JOIN
        INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON hc.CELL_ID = c.CELL_ID     -- 창고 정보 JOIN
        WHERE hc.TR_CD = @trCd
          AND hc.SURVEY_CYCLE_TYPE IS NOT NULL
          AND hc.SURVEY_CYCLE_VALUE IS NOT NULL
        ORDER BY h.[의료기관명], c.CELL_NAME;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- 4. 병원별 재고조사 주기 설정 삭제 프로시저
CREATE PROCEDURE [dbo].[USP_M_MEK_DELETE_HOSPITAL_CYCLE_SETTINGS]
    @trCd NVARCHAR(10),
    @hospitalId NVARCHAR(110) = NULL,
    @warehouseId NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMessage NVARCHAR(4000);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF @hospitalId IS NULL AND @warehouseId IS NULL
        BEGIN
            -- 전체 삭제 (해당 대리점의 모든 설정)
            UPDATE M_MEK_STRADE_HOSPITAL_CELL 
            SET SURVEY_CYCLE_TYPE = NULL,
                SURVEY_CYCLE_VALUE = NULL,
                UPDATED_BY = 'SYSTEM',
                UPDATED_AT = GETDATE()
            WHERE TR_CD = @trCd;
        END
        ELSE IF @hospitalId IS NOT NULL AND @warehouseId IS NULL
        BEGIN
            -- 특정 병원의 모든 설정 삭제
            UPDATE M_MEK_STRADE_HOSPITAL_CELL 
            SET SURVEY_CYCLE_TYPE = NULL,
                SURVEY_CYCLE_VALUE = NULL,
                UPDATED_BY = 'SYSTEM',
                UPDATED_AT = GETDATE()
            WHERE TR_CD = @trCd AND HOSPITAL_ID = @hospitalId;
        END
        ELSE IF @hospitalId IS NOT NULL AND @warehouseId IS NOT NULL
        BEGIN
            -- 특정 병원/창고 조합 삭제
            UPDATE M_MEK_STRADE_HOSPITAL_CELL 
            SET SURVEY_CYCLE_TYPE = NULL,
                SURVEY_CYCLE_VALUE = NULL,
                UPDATED_BY = 'SYSTEM',
                UPDATED_AT = GETDATE()
            WHERE TR_CD = @trCd 
              AND HOSPITAL_ID = @hospitalId 
              AND CELL_ID = @warehouseId;
        END
        
        COMMIT TRANSACTION;
        
        -- 성공 결과 반환
        SELECT 
            'success' AS status,
            '병원별 재고조사 주기 설정이 성공적으로 삭제되었습니다.' AS message,
            @@ROWCOUNT AS affectedRows;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT @ErrorMessage = ERROR_MESSAGE();
        
        -- 에러 결과 반환
        SELECT 
            'error' AS status,
            '삭제 중 오류가 발생했습니다: ' + @ErrorMessage AS message,
            0 AS affectedRows;
            
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

-- 5. 병원별 재고조사 주기 설정 업데이트 프로시저
CREATE PROCEDURE [dbo].[USP_M_MEK_UPDATE_HOSPITAL_CYCLE_SETTINGS]
    @trCd NVARCHAR(10),
    @hospitalId NVARCHAR(110),
    @warehouseId NVARCHAR(20),
    @cycleDays INT,
    @updatedBy NVARCHAR(100) = 'SYSTEM'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMessage NVARCHAR(4000);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 기존 데이터가 있는지 확인
        IF EXISTS (
            SELECT 1 FROM M_MEK_STRADE_HOSPITAL_CELL 
            WHERE TR_CD = @trCd 
              AND HOSPITAL_ID = @hospitalId 
              AND CELL_ID = @warehouseId
        )
        BEGIN
            -- 업데이트
            UPDATE M_MEK_STRADE_HOSPITAL_CELL 
            SET 
                SURVEY_CYCLE_TYPE = 'DAYS',
                SURVEY_CYCLE_VALUE = CAST(@cycleDays AS NVARCHAR(50)),
                UPDATED_BY = @updatedBy,
                UPDATED_AT = GETDATE()
            WHERE TR_CD = @trCd 
              AND HOSPITAL_ID = @hospitalId 
              AND CELL_ID = @warehouseId;
        END
        ELSE
        BEGIN
            -- 새로 삽입 (기본 정보와 함께)
            INSERT INTO M_MEK_STRADE_HOSPITAL_CELL 
            (TR_CD, HOSPITAL_ID, CELL_ID, SURVEY_CYCLE_TYPE, SURVEY_CYCLE_VALUE, UPDATED_BY, UPDATED_AT)
            VALUES 
            (@trCd, @hospitalId, @warehouseId, 'DAYS', CAST(@cycleDays AS NVARCHAR(50)), @updatedBy, GETDATE());
        END
        
        COMMIT TRANSACTION;
        
        -- 성공 결과 반환
        SELECT 
            'success' AS status,
            '병원별 재고조사 주기 설정이 성공적으로 업데이트되었습니다.' AS message,
            1 AS affectedRows;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT @ErrorMessage = ERROR_MESSAGE();
        
        -- 에러 결과 반환
        SELECT 
            'error' AS status,
            '업데이트 중 오류가 발생했습니다: ' + @ErrorMessage AS message,
            0 AS affectedRows;
            
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

-- 6-1. 병원별 재고조사 주기 설정 일괄 업데이트 프로시저 (간단 버전)
CREATE PROCEDURE [dbo].[USP_M_MEK_BULK_UPDATE_HOSPITAL_CYCLE_SETTINGS_SIMPLE]
    @trCd NVARCHAR(10),
    @cycleSettings NVARCHAR(MAX),
    @updatedBy NVARCHAR(100) = 'SYSTEM'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @AffectedRows INT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 새로운 설정으로 직접 업데이트 (기존 초기화 없이)
        UPDATE M_MEK_STRADE_HOSPITAL_CELL 
        SET SURVEY_CYCLE_TYPE = 'DAYS',
            SURVEY_CYCLE_VALUE = CAST(JSON_VALUE(value, '$.cycle') AS NVARCHAR(50)),
            UPDATED_BY = @updatedBy,
            UPDATED_AT = GETDATE()
        FROM M_MEK_STRADE_HOSPITAL_CELL hc
        INNER JOIN OPENJSON(@cycleSettings) ON 
            hc.HOSPITAL_ID = JSON_VALUE(value, '$.hospitalId') 
            AND hc.CELL_ID = JSON_VALUE(value, '$.warehouseId')
        WHERE hc.TR_CD = @trCd;
        
        SET @AffectedRows = @@ROWCOUNT;
        
        -- 새로운 레코드 삽입 (기존에 없는 조합)
        INSERT INTO M_MEK_STRADE_HOSPITAL_CELL 
        (TR_CD, HOSPITAL_ID, CELL_ID, SURVEY_CYCLE_TYPE, SURVEY_CYCLE_VALUE, UPDATED_BY, UPDATED_AT)
        SELECT 
            @trCd,
            JSON_VALUE(value, '$.hospitalId'),
            JSON_VALUE(value, '$.warehouseId'),
            'DAYS',
            CAST(JSON_VALUE(value, '$.cycle') AS NVARCHAR(50)),
            @updatedBy,
            GETDATE()
        FROM OPENJSON(@cycleSettings)
        WHERE NOT EXISTS (
            SELECT 1 FROM M_MEK_STRADE_HOSPITAL_CELL hc
            WHERE hc.TR_CD = @trCd
              AND hc.HOSPITAL_ID = JSON_VALUE(value, '$.hospitalId')
              AND hc.CELL_ID = JSON_VALUE(value, '$.warehouseId')
        );
        
        SET @AffectedRows = @AffectedRows + @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        -- 성공 결과 반환
        SELECT 
            'success' AS status,
            '병원별 재고조사 주기 설정이 성공적으로 일괄 업데이트되었습니다.' AS message,
            @AffectedRows AS affectedRows;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT @ErrorMessage = ERROR_MESSAGE();
        
        -- 에러 결과 반환
        SELECT 
            'error' AS status,
            '일괄 업데이트 중 오류가 발생했습니다: ' + @ErrorMessage AS message,
            0 AS affectedRows;
            
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

-- 7. 지능형 재고조사 관리 - 조사가 필요한 병원 조회 프로시저 (파싱 함수 적용)
CREATE PROCEDURE [dbo].[USP_M_MEK_SURVEY_NEEDED_HOSPITALS_GET]
    @trCd NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        SELECT 
            hc.HOSPITAL_ID AS hospitalId,
            hc.CELL_ID AS warehouseId,
            h.[의료기관명] AS hospitalName,  -- M_MEK_PD_HOSPITAL 테이블의 의료기관명
            c.CELL_NAME AS warehouseName,   -- M_MEK_COMM_HOSPITAL_CELL 테이블의 CELL_NAME
            hc.SURVEY_CYCLE_TYPE AS cycleType,
            hc.SURVEY_CYCLE_VALUE AS cycle,
            -- 마지막 조사일
            (SELECT MAX(CHECK_DT) 
             FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
             WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
               AND CELL_ID = hc.CELL_ID) AS lastSurveyDate,
            -- 경과일
            DATEDIFF(DAY, 
                    (SELECT MAX(CHECK_DT) 
                     FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                     WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                       AND CELL_ID = hc.CELL_ID), 
                    GETDATE()) AS daysSinceLastSurvey,
            -- 조사 상태 판단 (파싱 함수 사용)
            CASE 
                WHEN hc.SURVEY_CYCLE_TYPE = 'DAYS' THEN
                    CASE 
                        WHEN DATEDIFF(DAY, 
                                     (SELECT MAX(CHECK_DT) 
                                      FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                                      WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                        AND CELL_ID = hc.CELL_ID), 
                                     GETDATE()) >= dbo.UF_M_MEK_PARSE_DAYS_CYCLE(hc.SURVEY_CYCLE_VALUE) THEN 'URGENT'
                        WHEN DATEDIFF(DAY, 
                                     (SELECT MAX(CHECK_DT) 
                                      FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                                      WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                        AND CELL_ID = hc.CELL_ID), 
                                     GETDATE()) >= dbo.UF_M_MEK_PARSE_DAYS_CYCLE(hc.SURVEY_CYCLE_VALUE) * 0.8 THEN 'RECOMMENDED'
                        ELSE 'NORMAL'
                    END
                ELSE 'NORMAL'
            END AS surveyStatus
        FROM M_MEK_STRADE_HOSPITAL_CELL hc
        INNER JOIN M_MEK_PD_HOSPITAL h ON hc.HOSPITAL_ID = h.HOSPITAL_ID    -- 병원 정보 JOIN
        INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON hc.CELL_ID = c.CELL_ID     -- 창고 정보 JOIN
        WHERE hc.TR_CD = @trCd
          AND hc.SURVEY_CYCLE_TYPE IS NOT NULL
          AND hc.SURVEY_CYCLE_VALUE IS NOT NULL
        ORDER BY 
            CASE 
                WHEN DATEDIFF(DAY, 
                             (SELECT MAX(CHECK_DT) 
                              FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                              WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                AND CELL_ID = hc.CELL_ID), 
                             GETDATE()) >= dbo.UF_M_MEK_PARSE_DAYS_CYCLE(hc.SURVEY_CYCLE_VALUE) THEN 1
                WHEN DATEDIFF(DAY, 
                             (SELECT MAX(CHECK_DT) 
                              FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                              WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                AND CELL_ID = hc.CELL_ID), 
                             GETDATE()) >= dbo.UF_M_MEK_PARSE_DAYS_CYCLE(hc.SURVEY_CYCLE_VALUE) * 0.8 THEN 2
                ELSE 3
            END,
            h.[의료기관명], c.CELL_NAME;
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- 재고마감 번복 요청 테이블 생성
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='STOCK_CLOSE_REVERT_REQUESTS' AND xtype='U')
BEGIN
    CREATE TABLE STOCK_CLOSE_REVERT_REQUESTS (
        REQUEST_ID INT IDENTITY(1,1) PRIMARY KEY,
        TR_CD NVARCHAR(20) NOT NULL,
        CLOSE_DATE DATE NOT NULL,
        REQUEST_REASON NVARCHAR(500) NOT NULL,
        REQUEST_DETAIL NVARCHAR(1000),
        REQUEST_BY NVARCHAR(20) NOT NULL,
        REQUEST_DATE DATETIME DEFAULT GETDATE(),
        STATUS NVARCHAR(20) DEFAULT '대기', -- 대기, 승인, 거부
        ADMIN_COMMENT NVARCHAR(1000),
        PROCESSED_BY NVARCHAR(20),
        PROCESSED_DATE DATETIME,
        CREATE_DT DATETIME DEFAULT GETDATE(),
        UPDATE_DT DATETIME DEFAULT GETDATE()
    );
    
    -- 인덱스 생성
    CREATE INDEX IX_STOCK_CLOSE_REVERT_REQUESTS_TR_CD ON STOCK_CLOSE_REVERT_REQUESTS(TR_CD);
    CREATE INDEX IX_STOCK_CLOSE_REVERT_REQUESTS_CLOSE_DATE ON STOCK_CLOSE_REVERT_REQUESTS(CLOSE_DATE);
    CREATE INDEX IX_STOCK_CLOSE_REVERT_REQUESTS_STATUS ON STOCK_CLOSE_REVERT_REQUESTS(STATUS);
    CREATE INDEX IX_STOCK_CLOSE_REVERT_REQUESTS_REQUEST_DATE ON STOCK_CLOSE_REVERT_REQUESTS(REQUEST_DATE);
    
    PRINT 'STOCK_CLOSE_REVERT_REQUESTS 테이블이 생성되었습니다.';
END
ELSE
BEGIN
    PRINT 'STOCK_CLOSE_REVERT_REQUESTS 테이블이 이미 존재합니다.';
END

-- 재고마감 번복 요청 처리 프로시저
IF EXISTS (SELECT * FROM sysobjects WHERE name='USP_M_MEK_PROCESS_STOCK_CLOSE_REVERT' AND xtype='P')
    DROP PROCEDURE USP_M_MEK_PROCESS_STOCK_CLOSE_REVERT
GO

CREATE PROCEDURE USP_M_MEK_PROCESS_STOCK_CLOSE_REVERT
    @p_request_id INT,
    @p_status NVARCHAR(20), -- 승인, 거부
    @p_admin_comment NVARCHAR(1000),
    @p_processed_by NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 번복 요청 상태 업데이트
        UPDATE STOCK_CLOSE_REVERT_REQUESTS
        SET STATUS = @p_status,
            ADMIN_COMMENT = @p_admin_comment,
            PROCESSED_BY = @p_processed_by,
            PROCESSED_DATE = GETDATE(),
            UPDATE_DT = GETDATE()
        WHERE REQUEST_ID = @p_request_id;
        
        -- 승인된 경우 재고마감 취소 처리
        IF @p_status = '승인'
        BEGIN
            DECLARE @tr_cd NVARCHAR(20), @close_date DATE;
            
            SELECT @tr_cd = TR_CD, @close_date = CLOSE_DATE
            FROM STOCK_CLOSE_REVERT_REQUESTS
            WHERE REQUEST_ID = @p_request_id;
            
            -- 재고마감 취소 처리 (기존 재고마감 데이터 삭제 또는 상태 변경)
            UPDATE STOCK_CLOSE_MASTER
            SET STATUS = '취소',
                UPDATE_DT = GETDATE()
            WHERE TR_CD = @tr_cd AND CLOSE_DATE = @close_date;
            
            -- 재고마감 상세 데이터도 취소 처리
            UPDATE SCD
            SET STATUS = '취소',
                UPDATE_DT = GETDATE()
            FROM STOCK_CLOSE_DETAIL SCD
            INNER JOIN STOCK_CLOSE_MASTER SCM ON SCD.STOCK_CLOSE_ID = SCM.STOCK_CLOSE_ID
            WHERE SCM.TR_CD = @tr_cd AND SCM.CLOSE_DATE = @close_date;
        END
        
        COMMIT TRANSACTION;
        
        SELECT 'SUCCESS' as RESULT, '번복 요청이 성공적으로 처리되었습니다.' as MESSAGE;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SELECT 'ERROR' as RESULT, ERROR_MESSAGE() as MESSAGE;
    END CATCH
END
GO

PRINT 'USP_M_MEK_PROCESS_STOCK_CLOSE_REVERT 프로시저가 생성되었습니다.';

-- 주기유형별 파싱 함수들 생성

-- 1. 일수 파싱 함수 (DAYS 타입)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseDaysCycle' AND xtype='FN')
    DROP FUNCTION ParseDaysCycle
GO

CREATE FUNCTION ParseDaysCycle(@cycleValue NVARCHAR(100))
RETURNS INT
AS
BEGIN
    DECLARE @result INT = NULL;
    
    -- 숫자인지 확인 후 변환
    IF ISNUMERIC(@cycleValue) = 1
        SET @result = TRY_CAST(@cycleValue AS INT);
    
    RETURN @result;
END
GO

-- 2. 월별 파싱 함수 (MONTHLY 타입)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseMonthlyCycle' AND xtype='FN')
    DROP FUNCTION ParseMonthlyCycle
GO

CREATE FUNCTION ParseMonthlyCycle(@cycleValue NVARCHAR(100))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        CASE 
            WHEN CHARINDEX(',', @cycleValue) > 0 
            THEN TRY_CAST(LEFT(@cycleValue, CHARINDEX(',', @cycleValue) - 1) AS INT)
            ELSE NULL 
        END AS month,
        CASE 
            WHEN CHARINDEX(',', @cycleValue) > 0 
            THEN TRY_CAST(SUBSTRING(@cycleValue, CHARINDEX(',', @cycleValue) + 1, LEN(@cycleValue)) AS INT)
            ELSE NULL 
        END AS day
    WHERE @cycleValue IS NOT NULL
)
GO

-- 3. 주별 파싱 함수 (WEEKLY 타입)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseWeeklyCycle' AND xtype='FN')
    DROP FUNCTION ParseWeeklyCycle
GO

CREATE FUNCTION ParseWeeklyCycle(@cycleValue NVARCHAR(100))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        CASE 
            WHEN CHARINDEX(',', @cycleValue) > 0 
            THEN LEFT(@cycleValue, CHARINDEX(',', @cycleValue) - 1)
            ELSE NULL 
        END AS weekday,
        CASE 
            WHEN CHARINDEX(',', @cycleValue) > 0 
            THEN TRY_CAST(SUBSTRING(@cycleValue, CHARINDEX(',', @cycleValue) + 1, LEN(@cycleValue)) AS INT)
            ELSE NULL 
        END AS day
    WHERE @cycleValue IS NOT NULL
)
GO

-- 4. 기간 범위 파싱 함수 (RANGE 타입)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseRangeCycle' AND xtype='FN')
    DROP FUNCTION ParseRangeCycle
GO

CREATE FUNCTION ParseRangeCycle(@cycleValue NVARCHAR(100))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        CASE 
            WHEN CHARINDEX('~', @cycleValue) > 0 
            THEN TRY_CAST(LEFT(@cycleValue, CHARINDEX('~', @cycleValue) - 1) AS DATE)
            ELSE NULL 
        END AS startDate,
        CASE 
            WHEN CHARINDEX('~', @cycleValue) > 0 
            THEN TRY_CAST(SUBSTRING(@cycleValue, CHARINDEX('~', @cycleValue) + 1, LEN(@cycleValue)) AS DATE)
            ELSE NULL 
        END AS endDate
    WHERE @cycleValue IS NOT NULL
)
GO

-- 5. 사용자 정의 파싱 함수 (CUSTOM 타입)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseCustomCycle' AND xtype='FN')
    DROP FUNCTION ParseCustomCycle
GO

CREATE FUNCTION ParseCustomCycle(@cycleValue NVARCHAR(100))
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @result NVARCHAR(100) = NULL;
    
    -- 텍스트 기반 파싱
    IF @cycleValue LIKE '%매월%'
        SET @result = 'MONTHLY';
    ELSE IF @cycleValue LIKE '%분기%'
        SET @result = 'QUARTERLY';
    ELSE IF @cycleValue LIKE '%연간%' OR @cycleValue LIKE '%년%'
        SET @result = 'YEARLY';
    ELSE IF @cycleValue LIKE '%주%'
        SET @result = 'WEEKLY';
    ELSE
        SET @result = @cycleValue; -- 원본 값 반환
    
    RETURN @result;
END
GO

-- 6. 통합 파싱 함수 (모든 타입 처리)
IF EXISTS (SELECT * FROM sysobjects WHERE name='ParseCycleValue' AND xtype='FN')
    DROP FUNCTION ParseCycleValue
GO

CREATE FUNCTION ParseCycleValue(@cycleType NVARCHAR(20), @cycleValue NVARCHAR(100))
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @result NVARCHAR(100) = NULL;
    
    IF @cycleType = 'DAYS'
    BEGIN
        DECLARE @days INT = dbo.ParseDaysCycle(@cycleValue);
        IF @days IS NOT NULL
            SET @result = CAST(@days AS NVARCHAR(10));
    END
    ELSE IF @cycleType = 'MONTHLY'
    BEGIN
        DECLARE @monthly TABLE (month INT, day INT);
        INSERT INTO @monthly SELECT * FROM dbo.ParseMonthlyCycle(@cycleValue);
        
        DECLARE @month INT, @day INT;
        SELECT @month = month, @day = day FROM @monthly;
        
        IF @month IS NOT NULL AND @day IS NOT NULL
            SET @result = CAST(@month AS NVARCHAR(2)) + ',' + CAST(@day AS NVARCHAR(2));
    END
    ELSE IF @cycleType = 'WEEKLY'
    BEGIN
        DECLARE @weekly TABLE (weekday NVARCHAR(10), day INT);
        INSERT INTO @weekly SELECT * FROM dbo.ParseWeeklyCycle(@cycleValue);
        
        DECLARE @weekday NVARCHAR(10), @weekDay INT;
        SELECT @weekday = weekday, @weekDay = day FROM @weekly;
        
        IF @weekday IS NOT NULL AND @weekDay IS NOT NULL
            SET @result = @weekday + ',' + CAST(@weekDay AS NVARCHAR(2));
    END
    ELSE IF @cycleType = 'RANGE'
    BEGIN
        DECLARE @range TABLE (startDate DATE, endDate DATE);
        INSERT INTO @range SELECT * FROM dbo.ParseRangeCycle(@cycleValue);
        
        DECLARE @startDate DATE, @endDate DATE;
        SELECT @startDate = startDate, @endDate = endDate FROM @range;
        
        IF @startDate IS NOT NULL AND @endDate IS NOT NULL
            SET @result = CAST(@startDate AS NVARCHAR(10)) + '~' + CAST(@endDate AS NVARCHAR(10));
    END
    ELSE IF @cycleType = 'CUSTOM'
    BEGIN
        SET @result = dbo.ParseCustomCycle(@cycleValue);
    END
    ELSE
    BEGIN
        SET @result = @cycleValue; -- 원본 값 반환
    END
    
    RETURN @result;
END
GO

PRINT '주기유형별 파싱 함수들이 성공적으로 생성되었습니다.';

PRINT '병원별 재고조사 주기 설정 프로시저가 성공적으로 생성되었습니다.'; 