
-- 테이블 생성: 납품 마스터
CREATE TABLE M_MEK_DELIVERY_MASTER (
    delivery_id VARCHAR(50) PRIMARY KEY,
    tr_cd VARCHAR(50) NOT NULL,
    hospital_id VARCHAR(50) NOT NULL,
    cell_id VARCHAR(50) NOT NULL,
    delivery_dt DATE NOT NULL,
    deliverer VARCHAR(100) NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 테이블 생성: 납품 상세
CREATE TABLE M_MEK_DELIVERY_DETAIL (
    delivery_detail_id VARCHAR(50) PRIMARY KEY,
    delivery_id VARCHAR(50) NOT NULL,
    item_cd VARCHAR(50) NOT NULL,
    delivery_qty INT NOT NULL,
    serial_no VARCHAR(100),
    remark TEXT,
    FOREIGN KEY (delivery_id) REFERENCES M_MEK_DELIVERY_MASTER(delivery_id)
);

-- 테이블 생성: 임시저장
CREATE TABLE M_MEK_DELIVERY_TEMP (
    temp_id VARCHAR(50) PRIMARY KEY,
    tr_cd VARCHAR(50) NOT NULL,
    hospital_id VARCHAR(50) NOT NULL,
    cell_id VARCHAR(50) NOT NULL,
    item_cd VARCHAR(50) NOT NULL,
    delivery_qty INT NOT NULL,
    serial_no VARCHAR(100),
    remark TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 프로시저: 납품 저장
DELIMITER //
CREATE PROCEDURE USP_MK_INS_DELIVERY (
    IN p_delivery_id VARCHAR(50),
    IN p_tr_cd VARCHAR(50),
    IN p_hospital_id VARCHAR(50),
    IN p_cell_id VARCHAR(50),
    IN p_delivery_dt DATE,
    IN p_deliverer VARCHAR(100),
    IN p_description TEXT,
    IN p_items JSON
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;

    INSERT INTO M_MEK_DELIVERY_MASTER (delivery_id, tr_cd, hospital_id, cell_id, delivery_dt, deliverer, description)
    VALUES (p_delivery_id, p_tr_cd, p_hospital_id, p_cell_id, p_delivery_dt, p_deliverer, p_description);

    INSERT INTO M_MEK_DELIVERY_DETAIL (delivery_detail_id, delivery_id, item_cd, delivery_qty, serial_no, remark)
    SELECT UUID(), p_delivery_id, JSON_UNQUOTE(JSON_EXTRACT(item, '$.item_cd')),
           JSON_EXTRACT(item, '$.delivery_qty'), JSON_UNQUOTE(JSON_EXTRACT(item, '$.serial_no')),
           JSON_UNQUOTE(JSON_EXTRACT(item, '$.remark'))
    FROM JSON_TABLE(p_items, '$[*]' COLUMNS (
        item JSON PATH '$'
    )) AS jt;

    COMMIT;
END //
DELIMITER ;

-- 프로시저: 납품 수정
DELIMITER //
CREATE PROCEDURE USP_MK_UPDT_DELIVERY (
    IN p_delivery_id VARCHAR(50),
    IN p_delivery_dt DATE,
    IN p_deliverer VARCHAR(100),
    IN p_description TEXT,
    IN p_items JSON
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;

    UPDATE M_MEK_DELIVERY_MASTER
    SET delivery_dt = p_delivery_dt, deliverer = p_deliverer, description = p_description, updated_at = CURRENT_TIMESTAMP
    WHERE delivery_id = p_delivery_id;

    DELETE FROM M_MEK_DELIVERY_DETAIL WHERE delivery_id = p_delivery_id;

    INSERT INTO M_MEK_DELIVERY_DETAIL (delivery_detail_id, delivery_id, item_cd, delivery_qty, serial_no, remark)
    SELECT UUID(), p_delivery_id, JSON_UNQUOTE(JSON_EXTRACT(item, '$.item_cd')),
           JSON_EXTRACT(item, '$.delivery_qty'), JSON_UNQUOTE(JSON_EXTRACT(item, '$.serial_no')),
           JSON_UNQUOTE(JSON_EXTRACT(item, '$.remark'))
    FROM JSON_TABLE(p_items, '$[*]' COLUMNS (
        item JSON PATH '$'
    )) AS jt;

    COMMIT;
END //
DELIMITER ;

-- 프로시저: 납품 삭제
DELIMITER //
CREATE PROCEDURE USP_MK_DEL_DELIVERY (
    IN p_delivery_id VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;

    DELETE FROM M_MEK_DELIVERY_DETAIL WHERE delivery_id = p_delivery_id;
    DELETE FROM M_MEK_DELIVERY_MASTER WHERE delivery_id = p_delivery_id;

    COMMIT;
END //
DELIMITER ;

-- 프로시저: 납품 조회
DELIMITER //
CREATE PROCEDURE USP_MK_SEL_DELIVERY (
    IN p_tr_cd VARCHAR(50),
    IN p_hospital_id VARCHAR(50),
    IN p_cell_id VARCHAR(50),
    IN p_from_date DATE,
    IN p_to_date DATE
)
BEGIN
    SELECT
        m.delivery_id,
        m.tr_cd,
        m.hospital_id,
        m.cell_id,
        m.delivery_dt,
        m.deliverer,
        m.description,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'item_cd', d.item_cd,
                'delivery_qty', d.delivery_qty,
                'serial_no', d.serial_no,
                'remark', d.remark
            )
        ) AS items
    FROM M_MEK_DELIVERY_MASTER m
    LEFT JOIN M_MEK_DELIVERY_DETAIL d ON m.delivery_id = d.delivery_id
    WHERE m.tr_cd = p_tr_cd
        AND (p_hospital_id IS NULL OR m.hospital_id = p_hospital_id)
        AND (p_cell_id IS NULL OR m.cell_id = p_cell_id)
        AND (p_from_date IS NULL OR m.delivery_dt >= p_from_date)
        AND (p_to_date IS NULL OR m.delivery_dt <= p_to_date)
    GROUP BY m.delivery_id;
END //
DELIMITER ;

-- 프로시저: 임시저장
DELIMITER //
CREATE PROCEDURE USP_MK_INS_DELIVERY_TEMP (
    IN p_tr_cd VARCHAR(50),
    IN p_hospital_id VARCHAR(50),
    IN p_cell_id VARCHAR(50),
    IN p_items JSON
)
BEGIN
    INSERT INTO M_MEK_DELIVERY_TEMP (temp_id, tr_cd, hospital_id, cell_id, item_cd, delivery_qty, serial_no, remark)
    SELECT UUID(), p_tr_cd, p_hospital_id, p_cell_id, JSON_UNQUOTE(JSON_EXTRACT(item, '$.item_cd')),
           JSON_EXTRACT(item, '$.delivery_qty'), JSON_UNQUOTE(JSON_EXTRACT(item, '$.serial_no')),
           JSON_UNQUOTE(JSON_EXTRACT(item, '$.remark'))
    FROM JSON_TABLE(p_items, '$[*]' COLUMNS (
        item JSON PATH '$'
    )) AS jt;
END //
DELIMITER ;

-- 프로시저: 임시저장 조회
DELIMITER //
CREATE PROCEDURE USP_MK_SEL_DELIVERY_TEMP (
    IN p_tr_cd VARCHAR(50),
    IN p_hospital_id VARCHAR(50),
    IN p_cell_id VARCHAR(50)
)
BEGIN
    SELECT
        temp_id,
        tr_cd,
        hospital_id,
        cell_id,
        item_cd,
        delivery_qty,
        serial_no,
        remark
    FROM M_MEK_DELIVERY_TEMP
    WHERE tr_cd = p_tr_cd
        AND hospital_id = p_hospital_id
        AND cell_id = p_cell_id;
END //
DELIMITER ;

-- M_MEK_STRADE_ITEM_IO 테이블에 반출/반납 관련 컬럼 추가
ALTER TABLE M_MEK_STRADE_ITEM_IO 
ADD EXPORTER NVARCHAR(100) NULL,     -- 반출자
    RETURNER NVARCHAR(100) NULL,     -- 반납자
    RECEIVER NVARCHAR(100) NULL;     -- 수령자

-- 컬럼 설명 추가
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'반출자', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_ITEM_IO', 
    @level2type = N'COLUMN', @level2name = N'EXPORTER';

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'반납자', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_ITEM_IO', 
    @level2type = N'COLUMN', @level2name = N'RETURNER';

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'수령자', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_ITEM_IO', 
    @level2type = N'COLUMN', @level2name = N'RECEIVER';

-- 병원별 재고조사 주기 설정을 위한 컬럼 추가
ALTER TABLE M_MEK_STRADE_HOSPITAL_CELL 
ADD SURVEY_CYCLE_TYPE NVARCHAR(20) NULL,     -- 주기 유형: 'DAYS' 또는 'SPECIFIC_DAY'
    SURVEY_CYCLE_VALUE NVARCHAR(50) NULL,    -- 주기값: 일수 또는 특정일
    UPDATED_BY NVARCHAR(100) NULL,           -- 수정자
    UPDATED_AT DATETIME NULL;                -- 수정일

-- 컬럼 설명 추가
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'재고조사 주기 유형 (DAYS: 일수, SPECIFIC_DAY: 특정일)', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_HOSPITAL_CELL', 
    @level2type = N'COLUMN', @level2name = N'SURVEY_CYCLE_TYPE';

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'재고조사 주기값 (일수 또는 특정일)', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_HOSPITAL_CELL', 
    @level2type = N'COLUMN', @level2name = N'SURVEY_CYCLE_VALUE';

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'수정자', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_HOSPITAL_CELL', 
    @level2type = N'COLUMN', @level2name = N'UPDATED_BY';

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'수정일', 
    @level0type = N'SCHEMA', @level0name = N'dbo', 
    @level1type = N'TABLE', @level1name = N'M_MEK_STRADE_HOSPITAL_CELL', 
    @level2type = N'COLUMN', @level2name = N'UPDATED_AT';

-- 프로시저: 병원별 재고조사 주기 설정 저장
DELIMITER //
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SURVEY_CYCLE_SAVE
    @hospitalCode NVARCHAR(50),
    @cellCode NVARCHAR(20),
    @cycleType NVARCHAR(20),
    @cycleValue NVARCHAR(50),
    @updatedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- 기존 설정이 있는지 확인
        IF EXISTS (
            SELECT 1 FROM M_MEK_STRADE_HOSPITAL_CELL 
            WHERE HOSPITAL_ID = @hospitalCode 
              AND CELL_ID = @cellCode
        )
        BEGIN
            -- 기존 설정 업데이트
            UPDATE M_MEK_STRADE_HOSPITAL_CELL
            SET SURVEY_CYCLE_TYPE = @cycleType,
                SURVEY_CYCLE_VALUE = @cycleValue,
                UPDATED_BY = @updatedBy,
                UPDATED_AT = GETDATE()
            WHERE HOSPITAL_ID = @hospitalCode 
              AND CELL_ID = @cellCode;
        END
        ELSE
        BEGIN
            -- 새 설정 추가
            INSERT INTO M_MEK_STRADE_HOSPITAL_CELL (
                HOSPITAL_ID,
                CELL_ID,
                SURVEY_CYCLE_TYPE,
                SURVEY_CYCLE_VALUE,
                UPDATED_BY,
                UPDATED_AT
            )
            VALUES (
                @hospitalCode,
                @cellCode,
                @cycleType,
                @cycleValue,
                @updatedBy,
                GETDATE()
            );
        END
        
        SELECT 1 AS SUCCESS, '설정이 저장되었습니다.' AS MESSAGE;
    END TRY
    BEGIN CATCH
        SELECT 0 AS SUCCESS, ERROR_MESSAGE() AS MESSAGE;
    END CATCH
END;
GO

-- 프로시저: 병원별 재고조사 주기 설정 조회
DELIMITER //
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SURVEY_CYCLE_GET
    @trCd NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        SELECT 
            hc.HOSPITAL_ID,
            hc.CELL_ID,
            h.HOSPITAL_NAME,
            c.CELL_NAME,
            hc.SURVEY_CYCLE_TYPE,
            hc.SURVEY_CYCLE_VALUE,
            hc.UPDATED_BY,
            hc.UPDATED_AT,
            -- 마지막 조사일 (CHECK_DT 사용)
            (SELECT MAX(CHECK_DT) 
             FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
             WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
               AND CELL_ID = hc.CELL_ID) AS LAST_CHECK_DT,
            -- 경과일 (CHECK_DT 사용)
            DATEDIFF(DAY, 
                    (SELECT MAX(CHECK_DT) 
                     FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                     WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                       AND CELL_ID = hc.CELL_ID), 
                    GETDATE()) AS DAYS_SINCE_LAST_SURVEY
        FROM M_MEK_STRADE_HOSPITAL_CELL hc
        LEFT JOIN M_MEK_STRADE_HOSPITAL h ON hc.HOSPITAL_ID = h.HOSPITAL_ID
        LEFT JOIN M_MEK_STRADE_CELL c ON hc.CELL_ID = c.CELL_ID
        WHERE hc.SURVEY_CYCLE_TYPE IS NOT NULL
          AND hc.SURVEY_CYCLE_VALUE IS NOT NULL
        ORDER BY h.HOSPITAL_NAME, c.CELL_NAME;
    END TRY
    BEGIN CATCH
        SELECT NULL AS HOSPITAL_ID, NULL AS CELL_ID, NULL AS HOSPITAL_NAME, 
               NULL AS CELL_NAME, NULL AS SURVEY_CYCLE_TYPE, NULL AS SURVEY_CYCLE_VALUE,
               NULL AS UPDATED_BY, NULL AS UPDATED_AT, NULL AS LAST_CHECK_DT, 
               NULL AS DAYS_SINCE_LAST_SURVEY
        WHERE 1 = 0;
    END CATCH
END;
GO

-- 지능형 재고조사 관리 - 조사가 필요한 병원 조회 프로시저
DELIMITER //
CREATE PROCEDURE USP_M_MEK_SURVEY_NEEDED_HOSPITALS_GET
    @trCd NVARCHAR(10)
AS
BEGIN
    SELECT 
        hc.HOSPITAL_ID,
        hc.CELL_ID,
        h.HOSPITAL_NAME,
        c.CELL_NAME,
        hc.SURVEY_CYCLE_TYPE,
        hc.SURVEY_CYCLE_VALUE,
        -- 마지막 조사일 (CHECK_DT 사용)
        (SELECT MAX(CHECK_DT) 
         FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
         WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
           AND CELL_ID = hc.CELL_ID) AS LAST_CHECK_DT,
        -- 경과일 (CHECK_DT 사용)
        DATEDIFF(DAY, 
                (SELECT MAX(CHECK_DT) 
                 FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                 WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                   AND CELL_ID = hc.CELL_ID), 
                GETDATE()) AS DAYS_SINCE_LAST_SURVEY,
        -- 조사 상태 판단
        CASE 
            WHEN hc.SURVEY_CYCLE_TYPE = 'DAYS' THEN
                CASE 
                    WHEN DATEDIFF(DAY, 
                                 (SELECT MAX(CHECK_DT) 
                                  FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                                  WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                    AND CELL_ID = hc.CELL_ID), 
                                 GETDATE()) >= CAST(hc.SURVEY_CYCLE_VALUE AS INT) THEN 'URGENT'
                    WHEN DATEDIFF(DAY, 
                                 (SELECT MAX(CHECK_DT) 
                                  FROM M_MEK_STRADE_STOCK_SURVEY_MASTER 
                                  WHERE HOSPITAL_ID = hc.HOSPITAL_ID 
                                    AND CELL_ID = hc.CELL_ID), 
                                 GETDATE()) >= CAST(hc.SURVEY_CYCLE_VALUE AS INT) * 0.8 THEN 'RECOMMENDED'
                    ELSE 'NORMAL'
                END
            WHEN hc.SURVEY_CYCLE_TYPE = 'SPECIFIC_DAY' THEN
                CASE 
                    WHEN DAY(GETDATE()) >= CAST(hc.SURVEY_CYCLE_VALUE AS INT) THEN 'URGENT'
                    WHEN DAY(GETDATE()) >= CAST(hc.SURVEY_CYCLE_VALUE AS INT) * 0.8 THEN 'RECOMMENDED'
                    ELSE 'NORMAL'
                END
            ELSE 'NO_SETTING'
        END AS SURVEY_STATUS
    FROM M_MEK_STRADE_HOSPITAL_CELL hc
    LEFT JOIN M_MEK_STRADE_HOSPITAL h ON hc.HOSPITAL_ID = h.HOSPITAL_ID
    LEFT JOIN M_MEK_STRADE_CELL c ON hc.CELL_ID = c.CELL_ID
    WHERE hc.SURVEY_CYCLE_TYPE IS NOT NULL
      AND hc.SURVEY_CYCLE_VALUE IS NOT NULL
    ORDER BY 
        CASE SURVEY_STATUS 
            WHEN 'URGENT' THEN 1 
            WHEN 'RECOMMENDED' THEN 2 
            WHEN 'NORMAL' THEN 3 
            ELSE 4 
        END,
        h.HOSPITAL_NAME, c.CELL_NAME;
END //
DELIMITER ;
GO

CREATE PROCEDURE [dbo].[USP_M_MEK_AUTO_STOCK_CLOSE]
    @TR_CD NVARCHAR(20),
    @CLOSE_DATE DATE,
    @EMP_CD NVARCHAR(20),
    @CLOSE_DESC NVARCHAR(100) = NULL,
    @REMARK NVARCHAR(500) = NULL,
    @CREATE_TYPE NVARCHAR(10) = '자동'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    BEGIN TRY
        IF EXISTS (
            SELECT 1
            FROM M_MEK_STOCK_CLOSE_HISTORY
            WHERE TR_CD = @TR_CD
              AND YEAR(CLOSE_DATE) = YEAR(@CLOSE_DATE)
              AND MONTH(CLOSE_DATE) = MONTH(@CLOSE_DATE)
        )
        BEGIN
            RAISERROR(N'이미 해당 월에 마감이 존재합니다.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END

        IF @CLOSE_DESC IS NULL
            SET @CLOSE_DESC = FORMAT(@CLOSE_DATE, 'yyyy년 MM월 재고마감');

        INSERT INTO M_MEK_STOCK_CLOSE_HISTORY
            (TR_CD, CLOSE_DATE, EMP_CD, CLOSE_DESC, REMARK, CREATE_TYPE, TOTAL_VALUE, AUTO_ORDER_GENERATED, CREATED_AT, STATUS)
        VALUES
            (@TR_CD, @CLOSE_DATE, @EMP_CD, @CLOSE_DESC, @REMARK, @CREATE_TYPE, 0, 0, GETDATE(), NULL);

        DECLARE @STOCK_CLOSE_ID INT = SCOPE_IDENTITY();

        WITH base_stock AS (
          SELECT ITEM_CD, SUM(BASE_QT) AS BASE_QT
          FROM M_MEK_STRADE_BASE_STOCK
          WHERE TR_CD = @TR_CD AND YEAR = YEAR(@CLOSE_DATE) AND MONTH = MONTH(@CLOSE_DATE)
          GROUP BY ITEM_CD
        ),
        in_qty AS (
          SELECT ITEM_CODE, SUM(CASE WHEN IO_TYPE = 'IN' THEN IO_QT ELSE 0 END) AS IN_QT
          FROM M_MEK_STRADE_ITEM_IO
          WHERE TR_CD = @TR_CD AND YEAR(IO_DATE) = YEAR(@CLOSE_DATE) AND MONTH(IO_DATE) = MONTH(@CLOSE_DATE)
          GROUP BY ITEM_CODE
        ),
        out_qty AS (
          SELECT ITEM_CODE, SUM(CASE WHEN IO_TYPE = 'EXPORT' THEN IO_QT ELSE 0 END) AS OUT_QT
          FROM M_MEK_STRADE_ITEM_IO
          WHERE TR_CD = @TR_CD AND YEAR(IO_DATE) = YEAR(@CLOSE_DATE) AND MONTH(IO_DATE) = MONTH(@CLOSE_DATE)
          GROUP BY ITEM_CODE
        ),
        return_qty AS (
          SELECT ITEM_CODE, SUM(CASE WHEN IO_TYPE = 'RETURN' THEN IO_QT ELSE 0 END) AS RETURN_QT
          FROM M_MEK_STRADE_ITEM_IO
          WHERE TR_CD = @TR_CD AND YEAR(IO_DATE) = YEAR(@CLOSE_DATE) AND MONTH(IO_DATE) = MONTH(@CLOSE_DATE)
          GROUP BY ITEM_CODE
        ),
        safe_stock AS (
          SELECT ITEM_CD, SUM(SAFE_QT) AS SAFE_QT  -- 또는 MAX(SAFE_QT), 정책에 따라
          FROM M_MEK_STRADE_SAFE_STOCK
          WHERE TR_CD = @TR_CD
          GROUP BY ITEM_CD
        )
        INSERT INTO M_MEK_STOCK_CLOSE_DETAIL
          (STOCK_CLOSE_ID, ITEM_ID, ITEM_NAME, CLOSE_QTY, TOTAL_PRICE, TR_CD, SAFETY_QTY)
        SELECT
          @STOCK_CLOSE_ID,
          i.ITEM_CD,
          i.ITEM_ALIAS,
          ISNULL(bs.BASE_QT, 0)
          + ISNULL(iq.IN_QT, 0)
          - ISNULL(oq.OUT_QT, 0)
          + ISNULL(rq.RETURN_QT, 0)
          - ISNULL(ssk.SAFE_QT, 0) AS CLOSE_QTY,
          0,
          @TR_CD,
          ISNULL(ssk.SAFE_QT, 0)
        FROM M_MEK_COMM_ORDERCODE_M i
        LEFT JOIN base_stock bs ON i.ITEM_CD = bs.ITEM_CD
        LEFT JOIN in_qty iq ON i.ITEM_CD = iq.ITEM_CODE
        LEFT JOIN out_qty oq ON i.ITEM_CD = oq.ITEM_CODE
        LEFT JOIN return_qty rq ON i.ITEM_CD = rq.ITEM_CODE
        LEFT JOIN safe_stock ssk ON i.ITEM_CD = ssk.ITEM_CD
        WHERE i.ITEM_CD IN (SELECT DISTINCT ITEM_CD FROM M_MEK_STRADE_HOSPITAL_CELL_ITEM WHERE TR_CD = @TR_CD)

        SELECT @STOCK_CLOSE_ID AS STOCK_CLOSE_ID;
        COMMIT TRAN;
    END TRY
   
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

ALTER PROCEDURE [dbo].[USP_M_MEK_AUTO_ORDER_SCHEDULED]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @trCd NVARCHAR(20);
    DECLARE @closeDate DATE;
    DECLARE @stockCloseId INT;
    DECLARE @autoOrderId INT;

    -- 1. 대리점별 최신 마감ID/마감일 추출 커서
    DECLARE tr_cursor CURSOR FOR
    SELECT h.TR_CD, h.CLOSE_DATE, h.STOCK_CLOSE_ID
    FROM M_MEK_STOCK_CLOSE_HISTORY h
    INNER JOIN (
        SELECT TR_CD, MAX(CLOSE_DATE) AS CLOSE_DATE
        FROM M_MEK_STOCK_CLOSE_HISTORY
        GROUP BY TR_CD
    ) latest
      ON h.TR_CD = latest.TR_CD AND h.CLOSE_DATE = latest.CLOSE_DATE;

    OPEN tr_cursor;
    FETCH NEXT FROM tr_cursor INTO @trCd, @closeDate, @stockCloseId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 2. 부족품목 추출 (마감상세 기준)
            DECLARE @shortageItems TABLE (
                itemId NVARCHAR(50),
                itemName NVARCHAR(200),
                closeQty INT,
                safetyQty INT,
                orderQty INT
            );

            INSERT INTO @shortageItems
            SELECT 
                d.ITEM_ID,
                d.ITEM_NAME,
                d.CLOSE_QTY,
                d.SAFETY_QTY,
                (d.SAFETY_QTY - d.CLOSE_QTY) AS orderQty
            FROM M_MEK_STOCK_CLOSE_DETAIL d
            WHERE d.STOCK_CLOSE_ID = @stockCloseId
              AND d.CLOSE_QTY < d.SAFETY_QTY;

            -- 3. 자동주문 마스터 생성 (M_MEK_AUTO_ORDER)
            IF EXISTS (SELECT 1 FROM @shortageItems WHERE orderQty > 0)
            BEGIN
                INSERT INTO M_MEK_AUTO_ORDER
                  (TR_CD, ORDER_DATE, STATUS, TOTAL_VALUE, CREATED_AT, CREATED_USER, ORDER_SUMMARY, AUTO_TYPE)
                OUTPUT INSERTED.ID
                VALUES
                  (
                    @trCd,
                    @closeDate,
                    N'생성',
                    (SELECT SUM(orderQty) FROM @shortageItems WHERE orderQty > 0),
                    GETDATE(),
                    N'SYSTEM',
                    CONCAT(N'부족 품목: ', (SELECT COUNT(*) FROM @shortageItems WHERE orderQty > 0), N'개, 총 주문수량: ', (SELECT SUM(orderQty) FROM @shortageItems WHERE orderQty > 0), N'개'),
                    N'자동'
                  );

                SET @autoOrderId = SCOPE_IDENTITY();

                -- 4. 자동주문 상세 데이터 저장 (M_MEK_AUTO_ORDER_ITEM)
                INSERT INTO M_MEK_AUTO_ORDER_ITEM
                  (AUTO_ORDER_ID, ITEM_CD, ITEM_NAME, CURRENT_QTY, SAFETY_QTY, ORDER_QTY, STATUS, LAST_UPDATED_AT, LAST_UPDATED_USER)
                SELECT 
                    @autoOrderId,
                    itemId,
                    itemName,
                    closeQty,
                    safetyQty,
                    orderQty,
                    N'생성',
                    GETDATE(),
                    N'SYSTEM'
                FROM @shortageItems
                WHERE orderQty > 0;
            END

            COMMIT TRANSACTION;

            PRINT N'자동주문 생성 완료 - 대리점: ' + @trCd + N', 주문ID: ' + CAST(@autoOrderId AS NVARCHAR(20));
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            PRINT N'자동주문 생성 실패 - 대리점: ' + @trCd + N', 오류: ' + ERROR_MESSAGE();
        END CATCH

        FETCH NEXT FROM tr_cursor INTO @trCd, @closeDate, @stockCloseId;
    END

    CLOSE tr_cursor;
    DEALLOCATE tr_cursor;
END
GO