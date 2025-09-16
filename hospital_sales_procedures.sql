-- =====================================================
-- 병원매출현황 화면용 SQL 프로시저 모음 (실제 테이블 구조 반영)
-- =====================================================

-- 1. 병원매출현황 기본 데이터 조회 프로시저
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_DATA
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_hospital_id NVARCHAR(110) = NULL,   -- 병원코드 (선택)
    @p_cell_id NVARCHAR(20) = NULL,  -- 창고코드 (선택)
    @p_item_cd NVARCHAR(20) = NULL        -- 품목코드 (선택)
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
        c.CELL_ID,
        c.CELL_NAME as WAREHOUSE_NM,
        i.ITEM_CD,
        i.ITEM_ALIAS_EN as ITEM_NM,
        i.ITEM_SPEC,
        i.ITEM_UNIT,
        sd.IO_QT as SALES_QT,                    -- 매출 수량
        sd.IO_AMT as SALES_AMT,                 -- 매출 금액
        sd.CHECK_DT as SALES_DT,                -- 매출일
        sd.DATA_TYPE as IO_TYPE,
        sd.REMARK,
        sd.TR_CD,
        sd.SURVEY_ID,
        sd.CREATE_USERID,
        sd.CREATE_DT
    FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
    INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON sd.CELL_ID = c.CELL_ID
    INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
    WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
        AND sd.IO_QT > 0                        -- 매출 수량이 있는 것만
        AND (@p_hospital_id IS NULL OR sd.HOSPITAL_ID = @p_hospital_id)
        AND (@p_cell_id IS NULL OR sd.CELL_ID = @p_cell_id)
        AND (@p_item_cd IS NULL OR sd.ITEM_CD = @p_item_cd)
        AND (
            (@v_user_type = 'HEAD') OR          -- 본사 사용자는 모든 대리점 조회 가능
            (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)  -- 대리점 사용자는 자신의 데이터만
        )
    ORDER BY sd.CHECK_DT DESC, h.의료기관명, i.ITEM_ALIAS_EN;
END;
GO

-- 2. 병원매출현황 통계 프로시저
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_SUMMARY
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_group_by NVARCHAR(20) = 'HOSPITAL' -- 그룹핑 기준 (HOSPITAL, WAREHOUSE, ITEM, DATE)
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
        SELECT 
            h.HOSPITAL_ID,
            h.의료기관명 as HOSPITAL_NM,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY h.HOSPITAL_ID, h.의료기관명
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_group_by = 'WAREHOUSE'
    BEGIN
        SELECT 
            c.CELL_ID,
            c.CELL_NAME as WAREHOUSE_NM,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON sd.CELL_ID = c.CELL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY c.CELL_ID, c.CELL_NAME
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_group_by = 'ITEM'
    BEGIN
        SELECT 
            i.ITEM_CD,
            i.ITEM_ALIAS_EN as ITEM_NM,
            i.ITEM_SPEC,
            i.ITEM_UNIT,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY i.ITEM_CD, i.ITEM_ALIAS_EN, i.ITEM_SPEC, i.ITEM_UNIT
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_group_by = 'DATE'
    BEGIN
        SELECT 
            CAST(sd.CHECK_DT as DATE) as SALES_DATE,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY CAST(sd.CHECK_DT as DATE)
        ORDER BY SALES_DATE DESC;
    END
END;
GO

-- 3. 병원매출현황 분석 프로시저
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_ANALYSIS
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_analysis_type NVARCHAR(20) = 'TREND' -- 분석 유형 (TREND, RANK, COMPARISON)
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
        -- 월별 매출 트렌드 분석
        SELECT 
            YEAR(sd.CHECK_DT) as SALES_YEAR,
            MONTH(sd.CHECK_DT) as SALES_MONTH,
            DATENAME(MONTH, sd.CHECK_DT) as MONTH_NAME,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            AVG(sd.IO_QT) as AVG_SALES_QT,
            AVG(sd.IO_AMT) as AVG_SALES_AMT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY YEAR(sd.CHECK_DT), MONTH(sd.CHECK_DT), DATENAME(MONTH, sd.CHECK_DT)
        ORDER BY SALES_YEAR, SALES_MONTH;
    END
    ELSE IF @p_analysis_type = 'RANK'
    BEGIN
        -- 병원별 매출 순위 분석
        SELECT 
            ROW_NUMBER() OVER (ORDER BY SUM(sd.IO_AMT) DESC) as RANK_NO,
            h.HOSPITAL_ID,
            h.의료기관명 as HOSPITAL_NM,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT,
            SUM(sd.IO_QT) as TOTAL_SALES_QT,
            SUM(sd.IO_AMT) as TOTAL_SALES_AMT,
            ROUND(SUM(sd.IO_AMT) * 100.0 / SUM(SUM(sd.IO_AMT)) OVER (), 2) as SALES_PERCENTAGE
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY h.HOSPITAL_ID, h.의료기관명
        ORDER BY TOTAL_SALES_AMT DESC;
    END
    ELSE IF @p_analysis_type = 'COMPARISON'
    BEGIN
        -- 이전 기간 대비 비교 분석
        DECLARE @v_period_days INT = DATEDIFF(DAY, @p_start_date, @p_end_date) + 1;
        DECLARE @v_prev_start_date DATE = DATEADD(DAY, -@v_period_days, @p_start_date);
        DECLARE @v_prev_end_date DATE = DATEADD(DAY, -1, @p_start_date);
        
        WITH CurrentPeriod AS (
            SELECT 
                SUM(sd.IO_QT) as TOTAL_QT,
                SUM(sd.IO_AMT) as TOTAL_AMT,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
                AND sd.IO_QT > 0
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
        ),
        PreviousPeriod AS (
            SELECT 
                SUM(sd.IO_QT) as TOTAL_QT,
                SUM(sd.IO_AMT) as TOTAL_AMT,
                COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
                COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT
            FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
            WHERE sd.CHECK_DT BETWEEN @v_prev_start_date AND @v_prev_end_date
                AND sd.IO_QT > 0
                AND (
                    (@v_user_type = 'HEAD') OR
                    (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
                )
        )
        SELECT 
            '현재기간' as PERIOD_TYPE,
            @p_start_date as START_DATE,
            @p_end_date as END_DATE,
            c.TOTAL_QT,
            c.TOTAL_AMT,
            c.HOSPITAL_COUNT,
            c.ITEM_COUNT
        FROM CurrentPeriod c
        UNION ALL
        SELECT 
            '이전기간' as PERIOD_TYPE,
            @v_prev_start_date as START_DATE,
            @v_prev_end_date as END_DATE,
            p.TOTAL_QT,
            p.TOTAL_AMT,
            p.HOSPITAL_COUNT,
            p.ITEM_COUNT
        FROM PreviousPeriod p;
    END
END;
GO

-- 4. 병원매출현황 이력 프로시저
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_HISTORY
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_hospital_id NVARCHAR(110) = NULL,   -- 병원코드 (선택)
    @p_item_cd NVARCHAR(20) = NULL,       -- 품목코드 (선택)
    @p_limit INT = 100                   -- 조회 건수 제한
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_user_type NVARCHAR(10);
    
    -- 사용자 타입 확인
    IF @p_user_tr_cd = 'MEK'
        SET @v_user_type = 'HEAD';
    ELSE
        SET @v_user_type = 'AGENCY';
    
    SELECT TOP (@p_limit)
        sd.SURVEY_ID,
        h.HOSPITAL_ID,
        h.의료기관명 as HOSPITAL_NM,
        c.CELL_ID,
        c.CELL_NAME as WAREHOUSE_NM,
        i.ITEM_CD,
        i.ITEM_ALIAS_EN as ITEM_NM,
        i.ITEM_SPEC,
        i.ITEM_UNIT,
        sd.IO_QT as SALES_QT,
        sd.IO_AMT as SALES_AMT,
        sd.CHECK_DT as SALES_DT,
        sd.DATA_TYPE as IO_TYPE,
        sd.REMARK,
        sd.TR_CD,
        sd.CREATE_DT,
        sd.CREATE_USERID
    FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
    INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON sd.CELL_ID = c.CELL_ID
    INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
    WHERE sd.IO_QT > 0
        AND (@p_hospital_id IS NULL OR sd.HOSPITAL_ID = @p_hospital_id)
        AND (@p_item_cd IS NULL OR sd.ITEM_CD = @p_item_cd)
        AND (
            (@v_user_type = 'HEAD') OR
            (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
        )
    ORDER BY sd.CHECK_DT DESC, sd.SURVEY_ID DESC;
END;
GO

-- 5. 병원매출현황 차트 데이터 프로시저
-- =====================================================
CREATE PROCEDURE USP_M_MEK_HOSPITAL_SALES_CHART_DATA
    @p_user_tr_cd NVARCHAR(10),           -- 사용자 대리점코드
    @p_start_date DATE,                  -- 조회 시작일
    @p_end_date DATE,                    -- 조회 종료일
    @p_chart_type NVARCHAR(20) = 'DAILY'  -- 차트 유형 (DAILY, MONTHLY, HOSPITAL, ITEM)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_user_type NVARCHAR(10);
    
    -- 사용자 타입 확인
    IF @p_user_tr_cd = 'MEK'
        SET @v_user_type = 'HEAD';
    ELSE
        SET @v_user_type = 'AGENCY';
    
    IF @p_chart_type = 'DAILY'
    BEGIN
        -- 일별 매출 차트 데이터
        SELECT 
            CAST(sd.CHECK_DT as DATE) as CHART_DATE,
            SUM(sd.IO_QT) as SALES_QT,
            SUM(sd.IO_AMT) as SALES_AMT,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY CAST(sd.CHECK_DT as DATE)
        ORDER BY CHART_DATE;
    END
    ELSE IF @p_chart_type = 'MONTHLY'
    BEGIN
        -- 월별 매출 차트 데이터
        SELECT 
            YEAR(sd.CHECK_DT) as CHART_YEAR,
            MONTH(sd.CHECK_DT) as CHART_MONTH,
            DATENAME(MONTH, sd.CHECK_DT) as MONTH_NAME,
            SUM(sd.IO_QT) as SALES_QT,
            SUM(sd.IO_AMT) as SALES_AMT,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY YEAR(sd.CHECK_DT), MONTH(sd.CHECK_DT), DATENAME(MONTH, sd.CHECK_DT)
        ORDER BY CHART_YEAR, CHART_MONTH;
    END
    ELSE IF @p_chart_type = 'HOSPITAL'
    BEGIN
        -- 병원별 매출 차트 데이터 (상위 10개)
        SELECT TOP 10
            h.의료기관명 as CHART_LABEL,
            SUM(sd.IO_QT) as SALES_QT,
            SUM(sd.IO_AMT) as SALES_AMT,
            COUNT(DISTINCT sd.ITEM_CD) as ITEM_COUNT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_PD_HOSPITAL h ON sd.HOSPITAL_ID = h.HOSPITAL_ID
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY h.의료기관명
        ORDER BY SALES_AMT DESC;
    END
    ELSE IF @p_chart_type = 'ITEM'
    BEGIN
        -- 품목별 매출 차트 데이터 (상위 10개)
        SELECT TOP 10
            i.ITEM_ALIAS_EN as CHART_LABEL,
            SUM(sd.IO_QT) as SALES_QT,
            SUM(sd.IO_AMT) as SALES_AMT,
            COUNT(DISTINCT sd.HOSPITAL_ID) as HOSPITAL_COUNT
        FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL sd
        INNER JOIN M_MEK_COMM_ORDERCODE_M i ON sd.ITEM_CD = i.ITEM_CD
        WHERE sd.CHECK_DT BETWEEN @p_start_date AND @p_end_date
            AND sd.IO_QT > 0
            AND (
                (@v_user_type = 'HEAD') OR
                (@v_user_type = 'AGENCY' AND sd.TR_CD = @p_user_tr_cd)
            )
        GROUP BY i.ITEM_ALIAS_EN
        ORDER BY SALES_AMT DESC;
    END
END;
GO

-- =====================================================
-- 프로시저 사용 예시
-- =====================================================

/*
-- 1. 기본 데이터 조회
EXEC USP_M_MEK_HOSPITAL_SALES_DATA 
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31';

-- 2. 병원별 통계
EXEC USP_M_MEK_HOSPITAL_SALES_SUMMARY 
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_group_by = 'HOSPITAL';

-- 3. 월별 트렌드 분석
EXEC USP_M_MEK_HOSPITAL_SALES_ANALYSIS 
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-12-31',
    @p_analysis_type = 'TREND';

-- 4. 최근 매출 이력
EXEC USP_M_MEK_HOSPITAL_SALES_HISTORY 
    @p_user_tr_cd = 'MEK',
    @p_limit = 50;

-- 5. 일별 차트 데이터
EXEC USP_M_MEK_HOSPITAL_SALES_CHART_DATA 
    @p_user_tr_cd = 'MEK',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-01-31',
    @p_chart_type = 'DAILY';
*/ 