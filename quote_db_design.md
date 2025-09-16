# 견적서 양식 → DB 저장 설계

## 1) 엑셀 템플릿 설계 (권장)
**헤더(단일 값) = Named Range**, **품목표 = Excel Table**

### Named Ranges (단일 셀)
- `rngQuoteNo` (견적번호)
- `rngQuoteDate` (견적일자)
- `rngCustomerCode`, `rngCustomerName`
- `rngCurrency`
- `rngSubtotal`, `rngDiscountTotal`, `rngTax`, `rngTotal`

### Excel Table (품목 라인)
- 테이블 이름: `tblItems`
- 컬럼: `ItemCode`, `ItemName`, `Spec`, `Qty`, `UnitPrice`, `DiscountRate`, `TaxRate`, `Amount`

---

## 2) DB 스키마 (SQL Server 예시)
```sql
CREATE TABLE dbo.Customers (
  CustomerId     INT IDENTITY PRIMARY KEY,
  CustomerCode   NVARCHAR(50) UNIQUE,
  CustomerName   NVARCHAR(200)
);

CREATE TABLE dbo.Quotes (
  QuoteId        INT IDENTITY PRIMARY KEY,
  QuoteNo        NVARCHAR(50) UNIQUE,
  QuoteDate      DATE,
  CustomerId     INT NOT NULL FOREIGN KEY REFERENCES dbo.Customers(CustomerId),
  Currency       NVARCHAR(10),
  Subtotal       DECIMAL(18,2),
  DiscountTotal  DECIMAL(18,2),
  Tax            DECIMAL(18,2),
  Total          DECIMAL(18,2),
  Version        INT DEFAULT 1,
  CreatedAt      DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.QuoteItems (
  QuoteItemId    INT IDENTITY PRIMARY KEY,
  QuoteId        INT NOT NULL FOREIGN KEY REFERENCES dbo.Quotes(QuoteId),
  LineNo         INT NOT NULL,
  ItemCode       NVARCHAR(100),
  ItemName       NVARCHAR(200),
  Spec           NVARCHAR(200),
  Qty            DECIMAL(18,4),
  UnitPrice      DECIMAL(18,4),
  DiscountRate   DECIMAL(9,4),
  TaxRate        DECIMAL(9,4),
  Amount         DECIMAL(18,4)
);
```

---

## 3) 저장 타이밍 흐름
1. Univer 화면에서 **저장**
2. 백엔드(Node)가 워크북 스냅샷 → `.xlsx Export` (또는 JSON 스냅샷)
3. `.xlsx` 파싱 → DB Insert/Update

---

## 4) Node.js 코드 (ExcelJS + mssql)
```js
const ExcelJS = require('exceljs');
const sql = require('mssql');

async function importQuoteXlsxToDb(xlsxPath, connConfig) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(xlsxPath);
  const ws = wb.worksheets[0];

  // Named Range 읽기
  const dn = wb.definedNames;
  function getNamedCell(name) {
    const ranges = dn.getRanges(name);
    if (!ranges || ranges.length === 0) return null;
    const r = ranges[0];
    const sheet = wb.getWorksheet(r.worksheetName);
    const cell = sheet.getCell(r.ranges[0].start.row, r.ranges[0].start.col);
    return (cell.value?.text ?? cell.value) ?? null;
  }

  const quoteNo   = String(getNamedCell('rngQuoteNo')   || '').trim();
  const quoteDate = getNamedCell('rngQuoteDate');

  // 품목 테이블 찾기 (헤더명 기준)
  const headerNames = ['ItemCode','ItemName','Spec','Qty','UnitPrice','DiscountRate','TaxRate','Amount'];
  let startRow=null, startCol=null;
  outer: for (let r=1;r<=ws.actualRowCount;r++){
    for (let c=1;c<=ws.actualColumnCount;c++){
      if (String(ws.getCell(r,c).value||'').trim()===headerNames[0]){
        let ok=true;
        for (let i=0;i<headerNames.length;i++){
          if (String(ws.getCell(r,c+i).value||'').trim()!==headerNames[i]) {ok=false;break;}
        }
        if(ok){startRow=r;startCol=c;break outer;}
      }
    }
  }
  const items=[];
  let row=startRow+1;
  while(row<=ws.actualRowCount){
    const code=String(ws.getCell(row,startCol).value||'').trim();
    if(!code) break;
    items.push({
      code,
      name:String(ws.getCell(row,startCol+1).value||'').trim(),
      qty:Number(ws.getCell(row,startCol+3).value||0)
    });
    row++;
  }

  const pool=await sql.connect(connConfig);
  const tx=new sql.Transaction(pool);
  await tx.begin();
  try{
    await new sql.Request(tx)
      .input('QuoteNo',sql.NVarChar(50),quoteNo)
      .query(`MERGE dbo.Quotes AS T
              USING (SELECT @QuoteNo AS QuoteNo) AS S
              ON T.QuoteNo=S.QuoteNo
              WHEN NOT MATCHED THEN INSERT(QuoteNo) VALUES(@QuoteNo)
              OUTPUT inserted.QuoteId;`);
    for(const it of items){
      await new sql.Request(tx)
        .input('ItemCode',sql.NVarChar(100),it.code)
        .input('Qty',sql.Decimal(18,4),it.qty)
        .query("INSERT INTO dbo.QuoteItems (ItemCode,Qty,QuoteId) VALUES(@ItemCode,@Qty,SCOPE_IDENTITY())");
    }
    await tx.commit();
  }catch(e){await tx.rollback();throw e;}finally{pool.close();}
}
```

---

## 5) Univer 연결
- 저장 버튼 → Export .xlsx → DB 파싱
- 또는 스냅샷 JSON 직접 매핑 (더 빠름)

---

## 6) 실무 팁
- 통화/날짜 형식: 템플릿에 확정
- 고객/품목 코드: 코드 기반 FK로 저장
- PDF Export: 고객용 버전 보관 추천
