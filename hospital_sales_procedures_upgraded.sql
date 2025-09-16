-- =====================================================
-- 병원매출현황 프로시저 모음 (업그레이드 버전)
-- 병원 상세정보와 JOIN하여 지역별, 종별, 규모별 분석 지원
-- =====================================================

-- 1. 병원매출현황 기본 데이터 조회 프로시저 (업그레이드)
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_DATA_V2
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_hospital_ids NVARCHAR(MAX) = NULL,  -- 병원코드들 (JSON 배열)
    @p_cell_ids NVARCHAR(MAX) = NULL,     -- 창고코드들 (JSON 배열)
    @p_item_cds NVARCHAR(MAX) = NULL,     -- 품목코드들 (JSON 배열)
    @p_region NVARCHAR(50) = NULL,       -- 지역 (선택)
    @p_hospital_type NVARCHAR(50) = NULL -- 병원종별 (선택)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_user_type NVARCHAR(10);
    
    -- 사용자 타입 확인 (MEK: 본사, 기타: 대리점)
    IF @p_user_tr_cd = 'MEK'
        SET @v_user_type = 'HEAD';
    ELSE
        SET @v_user_type = 'AGENCY';
    
    SELECT 
        h.HOSPITAL_ID,
        h.의료기관명 as HOSPITAL_NM,
        h.주소 as HOSPITAL_ADDRESS,
        h.지역 as HOSPITAL_REGION,
        h.종별 as HOSPITAL_TYPE,
        h.규모 as HOSPITAL_SCALE,
        h.진료과목 as HOSPITAL_DEPARTMENTS,
        c.CELL_ID,
        c.CELL_NAME as WAREHOUSE_NM,
        i.ITEM_CD,
        i.ITEM_ALIAS_EN as ITEM_NM,
        i.ITEM_SPEC,
        i.ITEM_UNIT,
        i.ITEM_GROUP as ITEM_CATEGORY,
        sd.IO_QT as SALES_QT,                    -- 매출 수량
        sd.IO_AMT as SALES_AMT,                 -- 매출 금액
        sd.CHECK_DT as SALES_DT,                -- 매출일
        sd.DATA_TYPE as IO_TYPE,
        sd.REMARK,
        sd.TR_CD,
        sd.SURVEY_ID,
        sd.CREATE_USERID,
        sd.CREATE_DT,
        -- 추가 분석 컬럼
        ROUND(sd.IO_AMT / NULLIF(sd.IO_QT, 0), 2) as UNIT_PRICE,  -- 단가
        CASE 
            WHEN sd.IO_QT > 100 THEN 'HIGH'
            WHEN sd.IO_QT > 50 THEN 'MEDIUM'
            ELSE 'LOW'
        END as VOLUME_LEVEL
    FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
    INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON sd.CELL_ID = c.CELL_ID
    INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
    WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
        AND sd.IO_QT > 0                        -- 매출 수량이 있는 것만
        AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
        AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
        AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
        AND (@p_region IS NULL OR h.지역 = @p_region)
        AND (@p_hospital_type IS NULL OR h.종별 = @p_hospital_type)
        AND (
            (@v_user_type = 'HEAD') OR          -- 본사 사용자는 모든 대리점 조회 가능
            (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)  -- 대리점 사용자는 자신의 데이터만
        )
    ORDER BY sd.CHECK_DT DESC, h.의료기관명, i.ITEM_ALIAS_EN;
END;
GO

-- 2. 병원매출현황 고급 통계 프로시저 (업그레이드)
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_ADVANCED_SUMMARY
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_hospital_ids NVARCHAR(MAX) = NULL,  -- 병원코드들 (JSON 배열)
    @p_cell_ids NVARCHAR(MAX) = NULL,     -- 창고코드들 (JSON 배열)
    @p_item_cds NVARCHAR(MAX) = NULL,     -- 품목코드들 (JSON 배열)
    @p_group_by NVARCHAR(20) = 'HOSPITAL', -- 그룹핑 기준 (HOSPITAL, WAREHOUSE, ITEM, DATE, REGION, TYPE)
    @p_top_n INT = 10                    -- 상위 N개 조회 (0이면 전체)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_user_type NVARCHAR(10);
    
    -- 사용자 타입 확인
    IF @p_user_tr_cd = 'MEK'
        SET @v_user_type = 'HEAD';
    ELSE
        SET @v_user_type = 'AGENCY';
    
    IF @p_group_by = 'HOSPITAL'
    BEGIN
        IF @p_top_n > 0
        BEGIN
            SELECT TOP (@p_top_n)
                h.HOSPITAL_ID,
                h.의료기관명 as HOSPITAL_NM,
                h.지역 as HOSPITAL_REGION,
                h.종별 as HOSPITAL_TYPE,
                h.규모 as HOSPITAL_SCALE,
                COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                AVG(sd.IO_QT) as AVG_SALES_QT,
                AVG(sd.IO_AMT) as AVG_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
                COUNT(DISTINCT CAST(sd.CHECK_DT as DATE)) as SALES_DAYS,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY h.HOSPITAL_ID, h.의료기관명, h.지역, h.종별, h.규모
            ORDER BY TOTAL_SALES_AMT DESC;
        END
        ELSE
        BEGIN
            SELECT 
                h.HOSPITAL_ID,
                h.의료기관명 as HOSPITAL_NM,
                h.지역 as HOSPITAL_REGION,
                h.종별 as HOSPITAL_TYPE,
                h.규모 as HOSPITAL_SCALE,
                COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                AVG(sd.IO_QT) as AVG_SALES_QT,
                AVG(sd.IO_AMT) as AVG_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
                COUNT(DISTINCT CAST(sd.CHECK_DT as DATE)) as SALES_DAYS,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY h.HOSPITAL_ID, h.의료기관명, h.지역, h.종별, h.규모
            ORDER BY TOTAL_SALES_AMT DESC;
        END
    END
    ELSE IF @p_group_by = 'REGION'
    BEGIN
        SELECT 
            h.지역 as REGION_NAME,
            COUNT(DISTINCT h.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT,
            ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
            ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
            AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
            AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY h.지역
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_group_by = 'TYPE'
    BEGIN
        SELECT 
            h.종별 as HOSPITAL_TYPE,
            COUNT(DISTINCT h.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT,
            ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
            ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
            AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
            AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY h.종별
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_group_by = 'ITEM'
    BEGIN
        IF @p_top_n > 0
        BEGIN
            SELECT TOP (@p_top_n)
                i.ITEM_CD,
                i.ITEM_ALIAS_EN as ITEM_NM,
                i.ITEM_SPEC,
                i.ITEM_UNIT,
                i.ITEM_GROUP as ITEM_CATEGORY,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                AVG(sd.IO_QT) as AVG_SALES_QT,
                AVG(sd.IO_AMT) as AVG_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY i.ITEM_CD, i.ITEM_ALIAS_EN, i.ITEM_SPEC, i.ITEM_UNIT, i.ITEM_GROUP
            ORDER BY TOTAL_SALES_AMT DESC;
        END
        ELSE
        BEGIN
            SELECT 
                i.ITEM_CD,
                i.ITEM_ALIAS_EN as ITEM_NM,
                i.ITEM_SPEC,
                i.ITEM_UNIT,
                i.ITEM_GROUP as ITEM_CATEGORY,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                AVG(sd.IO_QT) as AVG_SALES_QT,
                AVG(sd.IO_AMT) as AVG_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY i.ITEM_CD, i.ITEM_ALIAS_EN, i.ITEM_SPEC, i.ITEM_UNIT, i.ITEM_GROUP
            ORDER BY TOTAL_SALES_AMT DESC;
        END
    END
    ELSE IF @p_group_by = 'DATE'
    BEGIN
        SELECT 
            CAST(sd.CHECK_DT as DATE) as SALES_DATE,
            DATENAME(WEEKDAY, sd.CHECK_DT) as DAY_NAME,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT,
            ROUND(SUM(sd.IO_AMT) / NULLIF(SUM(sd.IO_QT), 0), 2) as AVG_UNIT_PRICE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
            AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
            AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY CAST(sd.CHECK_DT as DATE), DATENAME(WEEKDAY, sd.CHECK_DT)
        ORDER BY SALES_DATE DESC;
    END
END;
GO

-- 3. 병원매출현황 AI 분석 프로시저 (업그레이드)
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_AI_ANALYSIS_V2
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_hospital_ids NVARCHAR(MAX) = NULL,  -- 병원코드들 (JSON 배열)
    @p_cell_ids NVARCHAR(MAX) = NULL,     -- 창고코드들 (JSON 배열)
    @p_item_cds NVARCHAR(MAX) = NULL,     -- 품목코드들 (JSON 배열)
    @p_analysis_type NVARCHAR(20) = 'TREND', -- 분석 유형 (TREND, PATTERN, PREDICTION, INSIGHT)
    @p_top_n INT = 10                    -- 상위 N개 조회
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_user_type NVARCHAR(10);
    
    -- 사용자 타입 확인
    IF @p_user_tr_cd = 'MEK'
        SET @v_user_type = 'HEAD';
    ELSE
        SET @v_user_type = 'AGENCY';
    
    IF @p_analysis_type = 'TREND'
    BEGIN
        -- 매출 트렌드 분석 (주별, 월별)
        SELECT 
            'WEEKLY' as TREND_TYPE,
            YEAR(sd.CHECK_DT) as YEAR_NO,
            DATEPART(WEEK, sd.CHECK_DT) as WEEK_NO,
            MIN(sd.CHECK_DT) as START_DATE,
            MAX(sd.CHECK_DT) as END_DATE,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT,
            -- 트렌드 계산
            LAG(SUM(sd.IO_AMT)) OVER (ORDER BY YEAR(sd.CHECK_DT), DATEPART(WEEK, sd.CHECK_DT)) as PREV_WEEK_AMT,
            ROUND(
                (SUM(sd.IO_AMT) - LAG(SUM(sd.IO_AMT)) OVER (ORDER BY YEAR(sd.CHECK_DT), DATEPART(WEEK, sd.CHECK_DT))) * 100.0 / 
                NULLIF(LAG(SUM(sd.IO_AMT)) OVER (ORDER BY YEAR(sd.CHECK_DT), DATEPART(WEEK, sd.CHECK_DT)), 0), 2
            ) as GROWTH_RATE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
            AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
            AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY YEAR(sd.CHECK_DT), DATEPART(WEEK, sd.CHECK_DT)
        ORDER BY YEAR_NO, WEEK_NO;
    END
    ELSE IF @p_analysis_type = 'PATTERN'
    BEGIN
        -- 매출 패턴 분석 (요일별, 시간대별)
        SELECT 
            DATENAME(WEEKDAY, sd.CHECK_DT) as DAY_NAME,
            DATEPART(WEEKDAY, sd.CHECK_DT) as DAY_NUMBER,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT,
            COUNT(*) as TRANSACTION_COUNT,
            ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
            AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
            AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY DATENAME(WEEKDAY, sd.CHECK_DT), DATEPART(WEEKDAY, sd.CHECK_DT)
        ORDER BY DAY_NUMBER;
    END
    ELSE IF @p_analysis_type = 'PREDICTION'
    BEGIN
        -- 매출 예측 분석 (이전 데이터 기반)
        WITH MonthlyData AS (
            SELECT 
                YEAR(sd.CHECK_DT) as YEAR_NO,
                MONTH(sd.CHECK_DT) as MONTH_NO,
                SUM(sd.IO_AMT) as MONTHLY_SALES,
                COUNT(DISTINCT sd.HOSPITAL_ID) as MONTHLY_HOSPITALS,
                COUNT(DISTINCT sd.ITEM_CD) as MONTHLY_ITEMS
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY YEAR(sd.CHECK_DT), MONTH(sd.CHECK_DT)
        )
        SELECT 
            YEAR_NO,
            MONTH_NO,
            DATENAME(MONTH, DATEFROMPARTS(YEAR_NO, MONTH_NO, 1)) as MONTH_NAME,
            MONTHLY_SALES,
            MONTHLY_HOSPITALS,
            MONTHLY_ITEMS,
            -- 이동평균 (3개월)
            AVG(MONTHLY_SALES) OVER (
                ORDER BY YEAR_NO, MONTH_NO 
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) as MOVING_AVG_3M,
            -- 성장률
            LAG(MONTHLY_SALES) OVER (ORDER BY YEAR_NO, MONTH_NO) as PREV_MONTH_SALES,
            ROUND(
                (MONTHLY_SALES - LAG(MONTHLY_SALES) OVER (ORDER BY YEAR_NO, MONTH_NO)) * 100.0 / 
                NULLIF(LAG(MONTHLY_SALES) OVER (ORDER BY YEAR_NO, MONTH_NO), 0), 2
            ) as MONTHLY_GROWTH_RATE
        FROM MonthlyData
        ORDER BY YEAR_NO, MONTH_NO;
    END
    ELSE IF @p_analysis_type = 'INSIGHT'
    BEGIN
        -- 인사이트 분석 (핫 아이템, 성장 병원 등)
        IF @p_top_n > 0
        BEGIN
            SELECT TOP (@p_top_n)
                'HOT_ITEMS' as INSIGHT_TYPE,
                i.ITEM_CD,
                i.ITEM_ALIAS_EN as ITEM_NM,
                i.ITEM_GROUP as ITEM_CATEGORY,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE,
                '인기 품목' as INSIGHT_DESC
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY i.ITEM_CD, i.ITEM_ALIAS_EN, i.ITEM_GROUP
            HAVING SUM(sd.IO_AMT) > (SELECT AVG(SUM(IO_AMT)) FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL 
                                     WHERE CHECK_DT BETWEEN @p_start_date AND @p_end_date 
                                       AND IO_QT > 0 
                                       AND (@p_hospital_ids IS NULL OR HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                                       AND (@p_cell_ids IS NULL OR CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                                       AND (@p_item_cds IS NULL OR ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                                       AND ((@v_user_type = 'HEAD') OR (@v_user_type = 'AGENCY' AND TR_CD = @p_user_tr_cd))
                                     GROUP BY ITEM_CD)
            ORDER BY TOTAL_SALES_AMT DESC;
        END
        ELSE
        BEGIN
            SELECT 
                'HOT_ITEMS' as INSIGHT_TYPE,
                i.ITEM_CD,
                i.ITEM_ALIAS_EN as ITEM_NM,
                i.ITEM_GROUP as ITEM_CATEGORY,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                SUM(sd.IO_QT) as TOTAL_SALES_QT,
                SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
                ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE,
                '인기 품목' as INSIGHT_DESC
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (@p_hospital_ids IS NULL OR sd.HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                AND (@p_cell_ids IS NULL OR sd.CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                AND (@p_item_cds IS NULL OR sd.ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
            GROUP BY i.ITEM_CD, i.ITEM_ALIAS_EN, i.ITEM_GROUP
            HAVING SUM(sd.IO_AMT) > (SELECT AVG(SUM(IO_AMT)) FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL 
                                     WHERE CHECK_DT BETWEEN @p_start_date AND @p_end_date 
                                       AND IO_QT > 0 
                                       AND (@p_hospital_ids IS NULL OR HOSPITAL_ID IN (SELECT value FROM OPENJSON(@p_hospital_ids)))
                                       AND (@p_cell_ids IS NULL OR CELL_ID IN (SELECT value FROM OPENJSON(@p_cell_ids)))
                                       AND (@p_item_cds IS NULL OR ITEM_CD IN (SELECT value FROM OPENJSON(@p_item_cds)))
                                       AND ((@v_user_type = 'HEAD') OR (@v_user_type = 'AGENCY' AND TR_CD = @p_user_tr_cd))
                                     GROUP BY ITEM_CD)
            ORDER BY TOTAL_SALES_AMT DESC;
        END
    END
END;
GO

-- =====================================================
-- 프로시저 사용 예시
-- =====================================================

/*
-- 1. 기본 데이터 조회 (업그레이드) - 특정 병원들만
EXEC USP_M_MEK_HOSPITAL_SALES_DATA_V2 
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_hospital_ids = '["H001", "H002", "H003"]',
    @p_item_cds = '["ITEM001", "ITEM002"]';

-- 2. 고급 통계 (병원별 상위 5개)
EXEC USP_M_MEK_HOSPITAL_SALES_ADVANCED_SUMMARY
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_group_by = 'HOSPITAL',
    @p_top_n = 5;

-- 3. AI 분석 (트렌드) - 특정 품목들만
EXEC USP_M_MEK_HOSPITAL_SALES_AI_ANALYSIS_V2
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_item_cds = '["ITEM001", "ITEM002", "ITEM003"]',
    @p_analysis_type = 'TREND';

-- 4. 인사이트 분석 (상위 10개)
EXEC USP_M_MEK_HOSPITAL_SALES_AI_ANALYSIS_V2
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_analysis_type = 'INSIGHT',
    @p_top_n = 10;
*/ 