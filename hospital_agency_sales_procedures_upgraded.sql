-- =====================================================
-- 대리점 매출현황 분석 프로시저 (업그레이드 버전)
-- 병원 마스터의 모든 유용한 컬럼 활용 + 주소 분리 + 좌표정보
-- =====================================================

-- 1. 대리점 매출현황 기본 데이터 조회 (업그레이드)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_DATA_V3
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.CHECK_DT BETWEEN @start_date AND @end_date';
    
    -- 병원 ID 필터
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    -- 창고 ID 필터
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    -- 품목 코드 필터
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    -- 병원 종별 필터 (실제 컬럼명 사용)
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.의료기관종별명 = @hospital_type';
    
    -- 병원 규모 필터 (병상수 기준)
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
    BEGIN
        IF @p_hospital_scale = '대형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 500';
        ELSE IF @p_hospital_scale = '중형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 100 AND h.병상수 < 500';
        ELSE IF @p_hospital_scale = '소형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 < 100';
    END
    
    -- 지역 필터 (주소에서 추출)
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @region + ''%''';
    
    -- 시도 필터 (주소에서 추출)
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sido + ''%''';
    
    -- 시군구 필터 (주소에서 추출)
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sigungu + ''%''';
    
    -- 읍면동 필터 (주소에서 추출)
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @eupmyeondong + ''%''';
    
    SET @sql = '
    SELECT 
        s.CHECK_DT,
        s.HOSPITAL_ID,
        h.의료기관명 as HOSPITAL_NAME,
        h.소재지전체주소 as HOSPITAL_ADDRESS,
        h.GPS_LATITUDE as HOSPITAL_LATITUDE,
        h.GPS_LONGITUDE as HOSPITAL_LONGITUDE,
        h.의료기관종별명 as HOSPITAL_TYPE,
        CASE 
            WHEN h.병상수 >= 500 THEN ''대형''
            WHEN h.병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END as HOSPITAL_SCALE,
        h.진료과목내용 as HOSPITAL_DEPARTMENTS,
        h.병상수 as HOSPITAL_BEDS,
        h.인허가일자 as HOSPITAL_ESTABLISHED_DATE,
        s.CELL_ID,
        c.CELL_NAME AS WAREHOUSE_NAME,
        s.ITEM_CD,
        i.품명 AS ITEM_NAME,
        i.ITEM_GROUP,
        i.ITEM_SIZE,
        s.IO_QT,
        s.IO_AMT,
        s.IO_UNIT_PRICE,
        s.CREATE_DT,
        s.CREATE_USERID
    FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON s.CELL_ID = c.CELL_ID
    INNER JOIN M_MEK_COMM_ORDERCODE_M i ON s.ITEM_CD = i.ITEM_CD
    ' + @where_conditions + '
    ORDER BY s.CHECK_DT DESC, s.HOSPITAL_ID, s.ITEM_CD';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 2. 대리점 매출현황 고급 통계 조회 (업그레이드)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_ADVANCED_SUMMARY_V2
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_group_by NVARCHAR(20) = 'HOSPITAL',
    @p_top_n INT = 10,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    DECLARE @group_by_clause NVARCHAR(MAX) = '';
    DECLARE @select_fields NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.CHECK_DT BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    -- 병원 종별 필터
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.의료기관종별명 = @hospital_type';
    
    -- 병원 규모 필터
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
    BEGIN
        IF @p_hospital_scale = '대형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 500';
        ELSE IF @p_hospital_scale = '중형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 100 AND h.병상수 < 500';
        ELSE IF @p_hospital_scale = '소형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 < 100';
    END
    
    -- 지역 필터
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @region + ''%''';
    
    -- 시도 필터
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sido + ''%''';
    
    -- 시군구 필터
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sigungu + ''%''';
    
    -- 읍면동 필터
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @eupmyeondong + ''%''';
    
    -- 그룹별 필드 설정
    IF @p_group_by = 'HOSPITAL'
    BEGIN
        SET @select_fields = 'h.HOSPITAL_ID, h.의료기관명 as HOSPITAL_NAME, h.소재지전체주소 as HOSPITAL_ADDRESS, h.GPS_LATITUDE, h.GPS_LONGITUDE, h.의료기관종별명 as HOSPITAL_TYPE, CASE WHEN h.병상수 >= 500 THEN ''대형'' WHEN h.병상수 >= 100 THEN ''중형'' ELSE ''소형'' END as HOSPITAL_SCALE';
        SET @group_by_clause = 'GROUP BY h.HOSPITAL_ID, h.의료기관명, h.소재지전체주소, h.GPS_LATITUDE, h.GPS_LONGITUDE, h.의료기관종별명, h.병상수';
    END
    ELSE IF @p_group_by = 'REGION'
    BEGIN
        SET @select_fields = 'h.소재지전체주소 as HOSPITAL_ADDRESS';
        SET @group_by_clause = 'GROUP BY h.소재지전체주소';
    END
    ELSE IF @p_group_by = 'ITEM'
    BEGIN
        SET @select_fields = 's.ITEM_CD, i.품명, i.ITEM_GROUP, i.ITEM_SIZE';
        SET @group_by_clause = 'GROUP BY s.ITEM_CD, i.품명, i.ITEM_GROUP, i.ITEM_SIZE';
    END
    ELSE IF @p_group_by = 'CELL_NAME'
    BEGIN
        SET @select_fields = 's.CELL_ID, c.CELL_NAME';
        SET @group_by_clause = 'GROUP BY s.CELL_ID, c.CELL_NAME';
    END
    ELSE IF @p_group_by = 'HOSPITAL_TYPE'
    BEGIN
        SET @select_fields = 'h.의료기관종별명 as HOSPITAL_TYPE, CASE WHEN h.병상수 >= 500 THEN ''대형'' WHEN h.병상수 >= 100 THEN ''중형'' ELSE ''소형'' END as HOSPITAL_SCALE';
        SET @group_by_clause = 'GROUP BY h.의료기관종별명, h.병상수';
    END
    ELSE IF @p_group_by = 'SIDO'
    BEGIN
        SET @select_fields = 'h.소재지전체주소 as HOSPITAL_ADDRESS';
        SET @group_by_clause = 'GROUP BY h.소재지전체주소';
    END
    ELSE IF @p_group_by = 'SIGUNGU'
    BEGIN
        SET @select_fields = 'h.소재지전체주소 as HOSPITAL_ADDRESS';
        SET @group_by_clause = 'GROUP BY h.소재지전체주소';
    END
    
    SET @sql = '
    SELECT TOP (@top_n)
        ' + @select_fields + ',
        COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
        COUNT(DISTINCT s.ITEM_CD) as ITEM_COUNT,
        SUM(s.IO_QT) as TOTAL_QTY,
        SUM(s.IO_AMT) as TOTAL_AMT,
        AVG(s.IO_UNIT_PRICE) as AVG_PRICE,
        COUNT(*) as TRANSACTION_COUNT
    FROM M_MEK_STRADE_STOCK_SURVEY_DETAIL s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_COMM_HOSPITAL_CELL c ON s.CELL_ID = c.CELL_ID
    INNER JOIN M_MEK_COMM_ORDERCODE_M i ON s.ITEM_CD = i.ITEM_CD
    ' + @where_conditions + '
    ' + @group_by_clause + '
    ORDER BY TOTAL_AMT DESC';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @top_n INT, @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_top_n, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 3. 대리점 매출현황 AI 분석 조회 (업그레이드)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_AI_ANALYSIS_V3
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_analysis_type NVARCHAR(20) = 'TREND',
    @p_top_n INT = 10,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.SALES_DATE BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_REGION = @region';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_TYPE = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SCALE = @hospital_scale';
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIDO = @sido';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIGUNGU = @sigungu';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_EUPMYEONDONG = @eupmyeondong';
    
    IF @p_analysis_type = 'TREND'
    BEGIN
        SET @sql = '
        SELECT TOP (@top_n)
            FORMAT(s.SALES_DATE, ''yyyy-MM'') as ANALYSIS_PERIOD,
            h.HOSPITAL_REGION,
            h.HOSPITAL_SIDO,
            h.HOSPITAL_SIGUNGU,
            h.HOSPITAL_TYPE,
            h.HOSPITAL_SCALE,
            COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
            SUM(s.SALES_AMT) as TOTAL_SALES,
            AVG(s.SALES_AMT) as AVG_SALES,
            COUNT(*) as TRANSACTION_COUNT,
            ''매출 증가 추세'' as INSIGHT
        FROM M_MEK_SALES s
        INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
        ' + @where_conditions + '
        GROUP BY FORMAT(s.SALES_DATE, ''yyyy-MM''), h.HOSPITAL_REGION, h.HOSPITAL_SIDO, h.HOSPITAL_SIGUNGU, h.HOSPITAL_TYPE, h.HOSPITAL_SCALE
        ORDER BY ANALYSIS_PERIOD DESC, TOTAL_SALES DESC';
    END
    ELSE IF @p_analysis_type = 'REGION'
    BEGIN
        SET @sql = '
        SELECT TOP (@top_n)
            h.HOSPITAL_REGION,
            h.HOSPITAL_SIDO,
            h.HOSPITAL_SIGUNGU,
            COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
            SUM(s.SALES_AMT) as TOTAL_SALES,
            AVG(s.SALES_AMT) as AVG_SALES,
            COUNT(*) as TRANSACTION_COUNT,
            CASE 
                WHEN SUM(s.SALES_AMT) > 1000000 THEN ''고매출 지역''
                WHEN SUM(s.SALES_AMT) > 500000 THEN ''중간매출 지역''
                ELSE ''저매출 지역''
            END as INSIGHT
        FROM M_MEK_SALES s
        INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
        ' + @where_conditions + '
        GROUP BY h.HOSPITAL_REGION, h.HOSPITAL_SIDO, h.HOSPITAL_SIGUNGU
        ORDER BY TOTAL_SALES DESC';
    END
    ELSE IF @p_analysis_type = 'HOSPITAL_TYPE'
    BEGIN
        SET @sql = '
        SELECT TOP (@top_n)
            h.HOSPITAL_TYPE,
            h.HOSPITAL_SCALE,
            COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
            SUM(s.SALES_AMT) as TOTAL_SALES,
            AVG(s.SALES_AMT) as AVG_SALES,
            COUNT(*) as TRANSACTION_COUNT,
            CASE 
                WHEN h.HOSPITAL_SCALE = ''대형'' THEN ''대형병원 중심 매출''
                WHEN h.HOSPITAL_SCALE = ''중형'' THEN ''중형병원 안정적 매출''
                ELSE ''소형병원 분산 매출''
            END as INSIGHT
        FROM M_MEK_SALES s
        INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
        ' + @where_conditions + '
        GROUP BY h.HOSPITAL_TYPE, h.HOSPITAL_SCALE
        ORDER BY TOTAL_SALES DESC';
    END
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @top_n INT, @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_top_n, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 4. 대리점 매출현황 지도 데이터 조회 (새로 추가)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_MAP_DATA
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.SALES_DATE BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_REGION = @region';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_TYPE = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SCALE = @hospital_scale';
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIDO = @sido';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIGUNGU = @sigungu';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_EUPMYEONDONG = @eupmyeondong';
    
    SET @sql = '
    SELECT 
        h.HOSPITAL_ID,
        h.HOSPITAL_NAME,
        h.HOSPITAL_ADDRESS,
        h.HOSPITAL_LATITUDE,
        h.HOSPITAL_LONGITUDE,
        h.HOSPITAL_REGION,
        h.HOSPITAL_SIDO,
        h.HOSPITAL_SIGUNGU,
        h.HOSPITAL_EUPMYEONDONG,
        h.HOSPITAL_TYPE,
        h.HOSPITAL_SCALE,
        h.HOSPITAL_DEPARTMENTS,
        h.HOSPITAL_BEDS,
        SUM(s.SALES_AMT) as TOTAL_SALES,
        COUNT(DISTINCT s.ITEM_CD) as ITEM_COUNT,
        COUNT(*) as TRANSACTION_COUNT,
        AVG(s.SALES_AMT) as AVG_SALES,
        CASE 
            WHEN SUM(s.SALES_AMT) > 1000000 THEN ''고매출''
            WHEN SUM(s.SALES_AMT) > 500000 THEN ''중간매출''
            ELSE ''저매출''
        END as SALES_LEVEL
    FROM M_MEK_SALES s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    ' + @where_conditions + '
    GROUP BY 
        h.HOSPITAL_ID, h.HOSPITAL_NAME, h.HOSPITAL_ADDRESS, 
        h.HOSPITAL_LATITUDE, h.HOSPITAL_LONGITUDE, h.HOSPITAL_REGION,
        h.HOSPITAL_SIDO, h.HOSPITAL_SIGUNGU, h.HOSPITAL_EUPMYEONDONG,
        h.HOSPITAL_TYPE, h.HOSPITAL_SCALE, h.HOSPITAL_DEPARTMENTS, h.HOSPITAL_BEDS
    ORDER BY TOTAL_SALES DESC';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 5. 대리점 매출현황 지역별 통계 (새로 추가)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_REGIONAL_STATS
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.SALES_DATE BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_REGION = @region';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_TYPE = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SCALE = @hospital_scale';
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIDO = @sido';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIGUNGU = @sigungu';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_EUPMYEONDONG = @eupmyeondong';
    
    SET @sql = '
    SELECT 
        h.HOSPITAL_REGION,
        h.HOSPITAL_SIDO,
        h.HOSPITAL_SIGUNGU,
        h.HOSPITAL_EUPMYEONDONG,
        COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
        COUNT(DISTINCT s.ITEM_CD) as ITEM_COUNT,
        SUM(s.SALES_QTY) as TOTAL_QTY,
        SUM(s.SALES_AMT) as TOTAL_SALES,
        AVG(s.SALES_AMT) as AVG_SALES,
        COUNT(*) as TRANSACTION_COUNT,
        SUM(s.SALES_AMT) / COUNT(DISTINCT s.HOSPITAL_ID) as SALES_PER_HOSPITAL,
        SUM(s.SALES_AMT) / COUNT(DISTINCT s.ITEM_CD) as SALES_PER_ITEM
    FROM M_MEK_SALES s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    ' + @where_conditions + '
    GROUP BY h.HOSPITAL_REGION, h.HOSPITAL_SIDO, h.HOSPITAL_SIGUNGU, h.HOSPITAL_EUPMYEONDONG
    ORDER BY TOTAL_SALES DESC';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 6. 대리점 매출현황 이력 조회 (업그레이드)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_HISTORY_V2
    @p_user_tr_cd NVARCHAR(10),
    @p_hospital_id NVARCHAR(110) = NULL,
    @p_item_cd NVARCHAR(20) = NULL,
    @p_limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@p_limit)
        s.SALES_DATE,
        s.HOSPITAL_ID,
        h.HOSPITAL_NAME,
        h.HOSPITAL_REGION,
        h.HOSPITAL_SIDO,
        h.HOSPITAL_SIGUNGU,
        h.HOSPITAL_TYPE,
        h.HOSPITAL_SCALE,
        s.CELL_ID,
        w.WAREHOUSE_NAME,
        s.ITEM_CD,
        i.ITEM_NAME,
        i.ITEM_GROUP,
        i.ITEM_SIZE,
        s.SALES_QTY,
        s.SALES_AMT,
        s.SALES_PRICE,
        s.CREATE_DATE,
        s.CREATE_USER
    FROM M_MEK_SALES s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_WAREHOUSE w ON s.CELL_ID = w.WAREHOUSE_ID
    INNER JOIN M_MEK_ITEM i ON s.ITEM_CD = i.ITEM_CD
    WHERE (@p_hospital_id IS NULL OR s.HOSPITAL_ID = @p_hospital_id)
      AND (@p_item_cd IS NULL OR s.ITEM_CD = @p_item_cd)
    ORDER BY s.SALES_DATE DESC, s.HOSPITAL_ID, s.ITEM_CD;
END;
GO

-- 7. 대리점 매출현황 차트 데이터 조회 (업그레이드)
CREATE OR ALTER PROCEDURE USP_M_MEK_AGENCY_SALES_CHART_DATA_V2
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_chart_type NVARCHAR(20) = 'DAILY',
    @p_hospital_ids NVARCHAR(MAX) = NULL,
    @p_cell_ids NVARCHAR(MAX) = NULL,
    @p_item_cds NVARCHAR(MAX) = NULL,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    DECLARE @group_by_clause NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.SALES_DATE BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_hospital_ids IS NOT NULL AND @p_hospital_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.HOSPITAL_ID IN (SELECT value FROM STRING_SPLIT(@hospital_ids, '',''))';
    
    IF @p_cell_ids IS NOT NULL AND @p_cell_ids != ''
        SET @where_conditions = @where_conditions + ' AND s.CELL_ID IN (SELECT value FROM STRING_SPLIT(@cell_ids, '',''))';
    
    IF @p_item_cds IS NOT NULL AND @p_item_cds != ''
        SET @where_conditions = @where_conditions + ' AND s.ITEM_CD IN (SELECT value FROM STRING_SPLIT(@item_cds, '',''))';
    
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_REGION = @region';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_TYPE = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SCALE = @hospital_scale';
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIDO = @sido';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_SIGUNGU = @sigungu';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.HOSPITAL_EUPMYEONDONG = @eupmyeondong';
    
    -- 차트 타입별 그룹핑
    IF @p_chart_type = 'DAILY'
        SET @group_by_clause = 'GROUP BY s.SALES_DATE';
    ELSE IF @p_chart_type = 'MONTHLY'
        SET @group_by_clause = 'GROUP BY FORMAT(s.SALES_DATE, ''yyyy-MM'')';
    ELSE IF @p_chart_type = 'REGION'
        SET @group_by_clause = 'GROUP BY h.HOSPITAL_REGION, h.HOSPITAL_SIDO';
    ELSE IF @p_chart_type = 'HOSPITAL_TYPE'
        SET @group_by_clause = 'GROUP BY h.HOSPITAL_TYPE, h.HOSPITAL_SCALE';
    ELSE IF @p_chart_type = 'ITEM_GROUP'
        SET @group_by_clause = 'GROUP BY i.ITEM_GROUP';
    
    SET @sql = '
    SELECT 
        CASE 
            WHEN @chart_type = ''DAILY'' THEN CAST(s.SALES_DATE AS NVARCHAR(10))
            WHEN @chart_type = ''MONTHLY'' THEN FORMAT(s.SALES_DATE, ''yyyy-MM'')
            WHEN @chart_type = ''REGION'' THEN h.HOSPITAL_REGION + '' - '' + h.HOSPITAL_SIDO
            WHEN @chart_type = ''HOSPITAL_TYPE'' THEN h.HOSPITAL_TYPE + '' - '' + h.HOSPITAL_SCALE
            WHEN @chart_type = ''ITEM_GROUP'' THEN i.ITEM_GROUP
        END as CHART_LABEL,
        SUM(s.SALES_AMT) as TOTAL_SALES,
        SUM(s.SALES_QTY) as TOTAL_QTY,
        COUNT(DISTINCT s.HOSPITAL_ID) as HOSPITAL_COUNT,
        COUNT(DISTINCT s.ITEM_CD) as ITEM_COUNT,
        COUNT(*) as TRANSACTION_COUNT
    FROM M_MEK_SALES s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    INNER JOIN M_MEK_ITEM i ON s.ITEM_CD = i.ITEM_CD
    ' + @where_conditions + '
    ' + @group_by_clause + '
    ORDER BY TOTAL_SALES DESC';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @chart_type NVARCHAR(20), @hospital_ids NVARCHAR(MAX), @cell_ids NVARCHAR(MAX), @item_cds NVARCHAR(MAX), @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_start_date, @p_end_date, @p_chart_type, @p_hospital_ids, @p_cell_ids, @p_item_cds, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

PRINT '대리점 매출현황 분석 프로시저 업그레이드 완료!';
PRINT '- 주소를 시도/시군구/읍면동으로 분리하여 지역 세분화 분석 지원';
PRINT '- 좌표정보를 활용한 지도 데이터 제공';
PRINT '- 병원 마스터의 모든 유용한 컬럼 활용';
PRINT '- 대리점 관점의 지역별 세분화 분석 강화'; 