-- =====================================================
-- 병원 마스터 정보 프로시저 (실제 테이블 구조 반영)
-- 병원 목록, 상세정보, 통계, 검색 기능
-- =====================================================

-- 1. 병원 목록 조회 (검색/필터링 지원)
CREATE OR ALTER PROCEDURE USP_M_MEK_HOSPITAL_DETAIL_INFO_LIST
    @p_user_tr_cd NVARCHAR(10),
    @p_search_keyword NVARCHAR(100) = NULL,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL,
    @p_limit INT = 100,
    @p_offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE 1=1';
    
    -- 검색 키워드 필터
    IF @p_search_keyword IS NOT NULL AND @p_search_keyword != ''
        SET @where_conditions = @where_conditions + ' AND (사업장명 LIKE ''%'' + @search_keyword + ''%'' OR 소재지전체주소 LIKE ''%'' + @search_keyword + ''%'' OR 의료기관명 LIKE ''%'' + @search_keyword + ''%'')';
    
    -- 지역 필터 (주소에서 추출)
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @region + ''%''';
    
    -- 병원 종별 필터
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND 의료기관종별명 = @hospital_type';
    
    -- 병원 규모 필터 (병상수 기준)
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
    BEGIN
        IF @p_hospital_scale = '대형'
            SET @where_conditions = @where_conditions + ' AND 병상수 >= 300';
        ELSE IF @p_hospital_scale = '중형'
            SET @where_conditions = @where_conditions + ' AND 병상수 >= 100 AND 병상수 < 300';
        ELSE IF @p_hospital_scale = '소형'
            SET @where_conditions = @where_conditions + ' AND 병상수 < 100';
    END
    
    -- 시도 필터
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @sido + ''%''';
    
    -- 시군구 필터
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @sigungu + ''%''';
    
    -- 읍면동 필터
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @eupmyeondong + ''%''';
    
    SET @sql = '
    SELECT 
        HOSPITAL_ID,
        사업장명 as HOSPITAL_NAME,
        의료기관명 as HOSPITAL_FULL_NAME,
        기관명약칭 as HOSPITAL_SHORT_NAME,
        소재지전체주소 as HOSPITAL_ADDRESS,
        도로명전체주소 as HOSPITAL_ROAD_ADDRESS,
        소재지우편번호 as HOSPITAL_POSTCODE,
        소재지전화 as HOSPITAL_TEL,
        의료기관종별명 as HOSPITAL_TYPE,
        병상수 as HOSPITAL_BEDS,
        허가병상수 as HOSPITAL_LICENSED_BEDS,
        입원실수 as HOSPITAL_ROOMS,
        의료인수 as HOSPITAL_DOCTORS,
        총면적 as HOSPITAL_AREA,
        진료과목내용 as HOSPITAL_DEPARTMENTS,
        진료과목내용명 as HOSPITAL_DEPARTMENTS_DETAIL,
        업태구분명 as HOSPITAL_CATEGORY,
        GPS_LATITUDE as HOSPITAL_LATITUDE,
        GPS_LONGITUDE as HOSPITAL_LONGITUDE,
        인허가일자 as HOSPITAL_ESTABLISHED_DATE,
        영업상태명 as HOSPITAL_STATUS,
        최종수정시점 as UPDATE_DATE,
        데이터갱신일자 as DATA_UPDATE_DATE,
        -- 주소 분리 (시도/시군구/읍면동 추출)
        CASE 
            WHEN 소재지전체주소 LIKE ''서울%'' THEN ''서울특별시''
            WHEN 소재지전체주소 LIKE ''부산%'' THEN ''부산광역시''
            WHEN 소재지전체주소 LIKE ''대구%'' THEN ''대구광역시''
            WHEN 소재지전체주소 LIKE ''인천%'' THEN ''인천광역시''
            WHEN 소재지전체주소 LIKE ''광주%'' THEN ''광주광역시''
            WHEN 소재지전체주소 LIKE ''대전%'' THEN ''대전광역시''
            WHEN 소재지전체주소 LIKE ''울산%'' THEN ''울산광역시''
            WHEN 소재지전체주소 LIKE ''세종%'' THEN ''세종특별자치시''
            WHEN 소재지전체주소 LIKE ''경기%'' THEN ''경기도''
            WHEN 소재지전체주소 LIKE ''강원%'' THEN ''강원도''
            WHEN 소재지전체주소 LIKE ''충북%'' THEN ''충청북도''
            WHEN 소재지전체주소 LIKE ''충남%'' THEN ''충청남도''
            WHEN 소재지전체주소 LIKE ''전북%'' THEN ''전라북도''
            WHEN 소재지전체주소 LIKE ''전남%'' THEN ''전라남도''
            WHEN 소재지전체주소 LIKE ''경북%'' THEN ''경상북도''
            WHEN 소재지전체주소 LIKE ''경남%'' THEN ''경상남도''
            WHEN 소재지전체주소 LIKE ''제주%'' THEN ''제주특별자치도''
            ELSE ''기타''
        END as HOSPITAL_SIDO,
        -- 병원 규모 분류
        CASE 
            WHEN 병상수 >= 300 THEN ''대형''
            WHEN 병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END as HOSPITAL_SCALE
    FROM M_MEK_PD_HOSPITAL
    ' + @where_conditions + '
    ORDER BY 사업장명
    OFFSET @offset ROWS
    FETCH NEXT @limit ROWS ONLY';
    
    EXEC sp_executesql @sql, 
        N'@search_keyword NVARCHAR(100), @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30), @limit INT, @offset INT',
        @p_search_keyword, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong, @p_limit, @p_offset;
END;
GO

-- 2. 병원 상세 정보 조회
CREATE OR ALTER PROCEDURE USP_M_MEK_HOSPITAL_DETAIL_INFO_DETAIL
    @p_user_tr_cd NVARCHAR(10),
    @p_hospital_id NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        HOSPITAL_ID,
        사업장명 as HOSPITAL_NAME,
        의료기관명 as HOSPITAL_FULL_NAME,
        기관명약칭 as HOSPITAL_SHORT_NAME,
        소재지전체주소 as HOSPITAL_ADDRESS,
        도로명전체주소 as HOSPITAL_ROAD_ADDRESS,
        소재지우편번호 as HOSPITAL_POSTCODE,
        소재지전화 as HOSPITAL_TEL,
        의료기관종별명 as HOSPITAL_TYPE,
        병상수 as HOSPITAL_BEDS,
        허가병상수 as HOSPITAL_LICENSED_BEDS,
        입원실수 as HOSPITAL_ROOMS,
        의료인수 as HOSPITAL_DOCTORS,
        총면적 as HOSPITAL_AREA,
        진료과목내용 as HOSPITAL_DEPARTMENTS,
        진료과목내용명 as HOSPITAL_DEPARTMENTS_DETAIL,
        업태구분명 as HOSPITAL_CATEGORY,
        GPS_LATITUDE as HOSPITAL_LATITUDE,
        GPS_LONGITUDE as HOSPITAL_LONGITUDE,
        인허가일자 as HOSPITAL_ESTABLISHED_DATE,
        영업상태명 as HOSPITAL_STATUS,
        최종수정시점 as UPDATE_DATE,
        데이터갱신일자 as DATA_UPDATE_DATE,
        -- 주소 분리
        CASE 
            WHEN 소재지전체주소 LIKE '서울%' THEN '서울특별시'
            WHEN 소재지전체주소 LIKE '부산%' THEN '부산광역시'
            WHEN 소재지전체주소 LIKE '대구%' THEN '대구광역시'
            WHEN 소재지전체주소 LIKE '인천%' THEN '인천광역시'
            WHEN 소재지전체주소 LIKE '광주%' THEN '광주광역시'
            WHEN 소재지전체주소 LIKE '대전%' THEN '대전광역시'
            WHEN 소재지전체주소 LIKE '울산%' THEN '울산광역시'
            WHEN 소재지전체주소 LIKE '세종%' THEN '세종특별자치시'
            WHEN 소재지전체주소 LIKE '경기%' THEN '경기도'
            WHEN 소재지전체주소 LIKE '강원%' THEN '강원도'
            WHEN 소재지전체주소 LIKE '충북%' THEN '충청북도'
            WHEN 소재지전체주소 LIKE '충남%' THEN '충청남도'
            WHEN 소재지전체주소 LIKE '전북%' THEN '전라북도'
            WHEN 소재지전체주소 LIKE '전남%' THEN '전라남도'
            WHEN 소재지전체주소 LIKE '경북%' THEN '경상북도'
            WHEN 소재지전체주소 LIKE '경남%' THEN '경상남도'
            WHEN 소재지전체주소 LIKE '제주%' THEN '제주특별자치도'
            ELSE '기타'
        END as HOSPITAL_SIDO,
        -- 병원 규모 분류
        CASE 
            WHEN 병상수 >= 300 THEN '대형'
            WHEN 병상수 >= 100 THEN '중형'
            ELSE '소형'
        END as HOSPITAL_SCALE
    FROM M_MEK_PD_HOSPITAL
    WHERE HOSPITAL_ID = @p_hospital_id;
END;
GO

-- 3. 병원 통계 정보 조회
CREATE OR ALTER PROCEDURE [dbo].[USP_M_MEK_HOSPITAL_DETAIL_INFO_STATS]
    @p_user_tr_cd NVARCHAR(10),
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL,
    @p_group_by NVARCHAR(20) = 'REGION'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    DECLARE @group_by_clause NVARCHAR(MAX) = '';
    DECLARE @select_fields NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE 1=1';
    
    -- 필터 조건들 추가
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @region + ''%''';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND 의료기관종별명 = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
    BEGIN
        IF @p_hospital_scale = '대형'
            SET @where_conditions = @where_conditions + ' AND 병상수 >= 300';
        ELSE IF @p_hospital_scale = '중형'
            SET @where_conditions = @where_conditions + ' AND 병상수 >= 100 AND 병상수 < 300';
        ELSE IF @p_hospital_scale = '소형'
            SET @where_conditions = @where_conditions + ' AND 병상수 < 100';
    END
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @sido + ''%''';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @sigungu + ''%''';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND 소재지전체주소 LIKE ''%'' + @eupmyeondong + ''%''';
    
    -- 그룹별 필드 설정
    IF @p_group_by = 'REGION'
    BEGIN
        SET @select_fields = '
        CASE 
            WHEN 소재지전체주소 LIKE ''서울%'' THEN ''서울특별시''
            WHEN 소재지전체주소 LIKE ''부산%'' THEN ''부산광역시''
            WHEN 소재지전체주소 LIKE ''대구%'' THEN ''대구광역시''
            WHEN 소재지전체주소 LIKE ''인천%'' THEN ''인천광역시''
            WHEN 소재지전체주소 LIKE ''광주%'' THEN ''광주광역시''
            WHEN 소재지전체주소 LIKE ''대전%'' THEN ''대전광역시''
            WHEN 소재지전체주소 LIKE ''울산%'' THEN ''울산광역시''
            WHEN 소재지전체주소 LIKE ''세종%'' THEN ''세종특별자치시''
            WHEN 소재지전체주소 LIKE ''경기%'' THEN ''경기도''
            WHEN 소재지전체주소 LIKE ''강원%'' THEN ''강원도''
            WHEN 소재지전체주소 LIKE ''충북%'' THEN ''충청북도''
            WHEN 소재지전체주소 LIKE ''충남%'' THEN ''충청남도''
            WHEN 소재지전체주소 LIKE ''전북%'' THEN ''전라북도''
            WHEN 소재지전체주소 LIKE ''전남%'' THEN ''전라남도''
            WHEN 소재지전체주소 LIKE ''경북%'' THEN ''경상북도''
            WHEN 소재지전체주소 LIKE ''경남%'' THEN ''경상남도''
            WHEN 소재지전체주소 LIKE ''제주%'' THEN ''제주특별자치도''
            ELSE ''기타''
        END as HOSPITAL_REGION';
        SET @group_by_clause = 'GROUP BY 
        CASE 
            WHEN 소재지전체주소 LIKE ''서울%'' THEN ''서울특별시''
            WHEN 소재지전체주소 LIKE ''부산%'' THEN ''부산광역시''
            WHEN 소재지전체주소 LIKE ''대구%'' THEN ''대구광역시''
            WHEN 소재지전체주소 LIKE ''인천%'' THEN ''인천광역시''
            WHEN 소재지전체주소 LIKE ''광주%'' THEN ''광주광역시''
            WHEN 소재지전체주소 LIKE ''대전%'' THEN ''대전광역시''
            WHEN 소재지전체주소 LIKE ''울산%'' THEN ''울산광역시''
            WHEN 소재지전체주소 LIKE ''세종%'' THEN ''세종특별자치시''
            WHEN 소재지전체주소 LIKE ''경기%'' THEN ''경기도''
            WHEN 소재지전체주소 LIKE ''강원%'' THEN ''강원도''
            WHEN 소재지전체주소 LIKE ''충북%'' THEN ''충청북도''
            WHEN 소재지전체주소 LIKE ''충남%'' THEN ''충청남도''
            WHEN 소재지전체주소 LIKE ''전북%'' THEN ''전라북도''
            WHEN 소재지전체주소 LIKE ''전남%'' THEN ''전라남도''
            WHEN 소재지전체주소 LIKE ''경북%'' THEN ''경상북도''
            WHEN 소재지전체주소 LIKE ''경남%'' THEN ''경상남도''
            WHEN 소재지전체주소 LIKE ''제주%'' THEN ''제주특별자치도''
            ELSE ''기타''
        END';
    END
    ELSE IF @p_group_by = 'HOSPITAL_TYPE'
    BEGIN
        SET @select_fields = '의료기관종별명 as HOSPITAL_TYPE,
        CASE 
            WHEN 병상수 >= 300 THEN ''대형''
            WHEN 병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END as HOSPITAL_SCALE';
        SET @group_by_clause = 'GROUP BY 의료기관종별명,
        CASE 
            WHEN 병상수 >= 300 THEN ''대형''
            WHEN 병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END';
    END
    ELSE IF @p_group_by = 'HOSPITAL_SCALE'
    BEGIN
        SET @select_fields = '
        CASE 
            WHEN 병상수 >= 300 THEN ''대형''
            WHEN 병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END as HOSPITAL_SCALE';
        SET @group_by_clause = 'GROUP BY 
        CASE 
            WHEN 병상수 >= 300 THEN ''대형''
            WHEN 병상수 >= 100 THEN ''중형''
            ELSE ''소형''
        END';
    END
    
    SET @sql = '
    SELECT 
        ' + @select_fields + ',
        COUNT(*) as HOSPITAL_COUNT,
        AVG(CAST(병상수 AS FLOAT)) as AVG_BEDS,
        SUM(CAST(병상수 AS INT)) as TOTAL_BEDS,
        AVG(CAST(의료인수 AS FLOAT)) as AVG_DOCTORS,
        SUM(CAST(의료인수 AS INT)) as TOTAL_DOCTORS
    FROM M_MEK_PD_HOSPITAL
    ' + @where_conditions + '
    ' + @group_by_clause + '
    ORDER BY HOSPITAL_COUNT DESC';
    
    EXEC sp_executesql @sql, 
        N'@region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30)',
        @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong;
END;
GO

-- 4. 병원별 매출 통계 조회 (선택사항)
CREATE OR ALTER PROCEDURE USP_M_MEK_HOSPITAL_SALES_STATS
    @p_user_tr_cd NVARCHAR(10),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_region NVARCHAR(50) = NULL,
    @p_hospital_type NVARCHAR(50) = NULL,
    @p_hospital_scale NVARCHAR(20) = NULL,
    @p_sido NVARCHAR(20) = NULL,
    @p_sigungu NVARCHAR(30) = NULL,
    @p_eupmyeondong NVARCHAR(30) = NULL,
    @p_top_n INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where_conditions NVARCHAR(MAX) = '';
    
    -- 기본 조건
    SET @where_conditions = 'WHERE s.SALES_DATE BETWEEN @start_date AND @end_date';
    
    -- 필터 조건들 추가
    IF @p_region IS NOT NULL AND @p_region != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @region + ''%''';
    
    IF @p_hospital_type IS NOT NULL AND @p_hospital_type != ''
        SET @where_conditions = @where_conditions + ' AND h.의료기관종별명 = @hospital_type';
    
    IF @p_hospital_scale IS NOT NULL AND @p_hospital_scale != ''
    BEGIN
        IF @p_hospital_scale = '대형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 300';
        ELSE IF @p_hospital_scale = '중형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 >= 100 AND h.병상수 < 300';
        ELSE IF @p_hospital_scale = '소형'
            SET @where_conditions = @where_conditions + ' AND h.병상수 < 100';
    END
    
    IF @p_sido IS NOT NULL AND @p_sido != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sido + ''%''';
    
    IF @p_sigungu IS NOT NULL AND @p_sigungu != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @sigungu + ''%''';
    
    IF @p_eupmyeondong IS NOT NULL AND @p_eupmyeondong != ''
        SET @where_conditions = @where_conditions + ' AND h.소재지전체주소 LIKE ''%'' + @eupmyeondong + ''%''';
    
    SET @sql = '
    SELECT TOP (@top_n)
        h.HOSPITAL_ID,
        h.사업장명 as HOSPITAL_NAME,
        h.의료기관명 as HOSPITAL_FULL_NAME,
        h.소재지전체주소 as HOSPITAL_ADDRESS,
        h.의료기관종별명 as HOSPITAL_TYPE,
        h.병상수 as HOSPITAL_BEDS,
        h.GPS_LATITUDE as HOSPITAL_LATITUDE,
        h.GPS_LONGITUDE as HOSPITAL_LONGITUDE,
        COUNT(DISTINCT s.ITEM_CD) as ITEM_COUNT,
        SUM(s.SALES_QTY) as TOTAL_QTY,
        SUM(s.SALES_AMT) as TOTAL_SALES,
        COUNT(*) as TRANSACTION_COUNT,
        AVG(s.SALES_AMT) as AVG_SALES
    FROM M_MEK_SALES s
    INNER JOIN M_MEK_PD_HOSPITAL h ON s.HOSPITAL_ID = h.HOSPITAL_ID
    ' + @where_conditions + '
    GROUP BY 
        h.HOSPITAL_ID, h.사업장명, h.의료기관명, h.소재지전체주소, 
        h.의료기관종별명, h.병상수, h.GPS_LATITUDE, h.GPS_LONGITUDE
    ORDER BY TOTAL_SALES DESC';
    
    EXEC sp_executesql @sql, 
        N'@start_date DATE, @end_date DATE, @region NVARCHAR(50), @hospital_type NVARCHAR(50), @hospital_scale NVARCHAR(20), @sido NVARCHAR(20), @sigungu NVARCHAR(30), @eupmyeondong NVARCHAR(30), @top_n INT',
        @p_start_date, @p_end_date, @p_region, @p_hospital_type, @p_hospital_scale, @p_sido, @p_sigungu, @p_eupmyeondong, @p_top_n;
END;
GO

-- 5. 병원 검색 (자동완성용)
CREATE OR ALTER PROCEDURE USP_M_MEK_HOSPITAL_SEARCH
    @p_user_tr_cd NVARCHAR(10),
    @p_keyword NVARCHAR(100),
    @p_limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@p_limit)
        HOSPITAL_ID,
        사업장명 as HOSPITAL_NAME,
        의료기관명 as HOSPITAL_FULL_NAME,
        소재지전체주소 as HOSPITAL_ADDRESS,
        의료기관종별명 as HOSPITAL_TYPE,
        병상수 as HOSPITAL_BEDS,
        GPS_LATITUDE as HOSPITAL_LATITUDE,
        GPS_LONGITUDE as HOSPITAL_LONGITUDE
    FROM M_MEK_PD_HOSPITAL
    WHERE 사업장명 LIKE '%' + @p_keyword + '%'
       OR 의료기관명 LIKE '%' + @p_keyword + '%'
       OR 소재지전체주소 LIKE '%' + @p_keyword + '%'
       OR HOSPITAL_ID LIKE '%' + @p_keyword + '%'
    ORDER BY 
        CASE 
            WHEN 사업장명 LIKE @p_keyword + '%' THEN 1
            WHEN 사업장명 LIKE '%' + @p_keyword + '%' THEN 2
            ELSE 3
        END,
        사업장명;
END;
GO

PRINT '병원 마스터 정보 프로시저 생성 완료! (실제 테이블 구조 반영)';
PRINT '- 병원 목록 조회 (검색/필터링 지원)';
PRINT '- 병원 상세 정보 조회';
PRINT '- 병원 통계 정보 조회';
PRINT '- 병원별 매출 통계 조회';
PRINT '- 병원 검색 (자동완성용)';
PRINT '- 실제 컬럼명과 데이터 타입 반영'; 