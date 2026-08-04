# Ghi Chú: Tìm Kiếm Khoảng Thời Gian Overlap trong Oracle SQL

## 📋 Bài Toán Gặp Phải

### Mô tả
Cần tìm kiếm các tài khoản Virtual Account (VA) có **khoảng thời gian hoạt động** (từ ACTIVE_DATE đến CANCEL_DATE) **giao nhau** với khoảng thời gian tìm kiếm do người dùng nhập vào.

### Cấu trúc dữ liệu
**Bảng: BK_VA_ACCOUNT_MANAGEMENT_BK**

| VA_ACC_NUMBER | ACTIVE_DATE | CANCEL_DATE |
|---------------|-------------|-------------|
| DATTESBAOCAOVA | 24-DEC-25 | (null) |
| DATTESBAOCAOVA | (null) | (null) |
| DATTESBAOCAOVA | (null) | 06-JAN-26 |
| DATTESBAOCAOVA | 26-JAN-26 | (null) |

### Yêu cầu
- Tìm các VA có khoảng thời gian (ACTIVE_DATE → CANCEL_DATE) **overlap** với khoảng tìm kiếm
- Nếu CANCEL_DATE = NULL, coi như tài khoản vẫn đang active (dùng SYSDATE)
- Kết quả phải bao gồm cả các khoảng thời gian overlap một phần, không chỉ nằm hoàn toàn trong khoảng tìm kiếm

---

## ❌ Sai Lầm Ban Đầu

### Query sai:
```sql
WHERE StartDate >= TO_DATE('28/12/2025', 'dd/mm/yyyy')
  AND NVL(EndDate, SYSDATE) < TO_DATE('01/01/2026', 'dd/mm/yyyy') + 1
```

### Vấn đề:
- Chỉ tìm các khoảng **nằm hoàn toàn** trong phạm vi tìm kiếm
- Bỏ sót các khoảng overlap một phần

### Ví dụ bị bỏ sót:
```
Tìm kiếm:  [28/12 -------- 01/01]
Dữ liệu:  [24/12 -------------- 06/01]  ❌ KHÔNG TRẢ VỀ (sai!)
```

---

## ✅ Giải Pháp Đúng

### Logic Overlap
Hai khoảng thời gian **overlap** khi và chỉ khi:
```
StartDate <= SearchEndDate  VÀ  EndDate >= SearchStartDate
```

### Query đúng:
```sql
WHERE StartDate <= TO_DATE('01/01/2026', 'dd/mm/yyyy')
  AND NVL(EndDate, SYSDATE) >= TO_DATE('28/12/2025', 'dd/mm/yyyy')
```

### Minh họa các trường hợp:

#### ✅ OVERLAP - Trả về kết quả:
```
1. Khoảng dữ liệu nằm hoàn toàn trong khoảng tìm kiếm:
   Tìm:  [15/12 ------------ 10/01]
   Data:       [24/12 -- 06/01]      ✅

2. Khoảng dữ liệu chứa hoàn toàn khoảng tìm kiếm:
   Tìm:        [28/12 -- 01/01]
   Data: [24/12 ---------------- 06/01]  ✅

3. Overlap phần đầu:
   Tìm:  [15/12 -------- 30/12]
   Data:       [24/12 -------- 06/01]  ✅

4. Overlap phần cuối:
   Tìm:              [28/12 -------- 10/01]
   Data: [24/12 ---------- 06/01]  ✅
```

#### ❌ KHÔNG OVERLAP - Không trả về:
```
1. Khoảng dữ liệu kết thúc trước khi tìm kiếm bắt đầu:
   Tìm:                    [28/12 -- 01/01]
   Data: [15/12 -- 20/12]                    ❌

2. Khoảng dữ liệu bắt đầu sau khi tìm kiếm kết thúc:
   Tìm:  [15/12 -- 20/12]
   Data:                    [28/12 -- 01/01]  ❌
```

---

## 🔧 Các Hàm SQL Sử Dụng

### 1. **LEAD() - Window Function**

#### Cú pháp:
```sql
LEAD(column_name, offset, default_value) OVER (
    [PARTITION BY partition_column]
    ORDER BY sort_column
)
```

#### Chức năng:
- Lấy giá trị từ **dòng tiếp theo** trong result set
- Thường dùng để ghép cặp dữ liệu giữa các dòng

#### Ví dụ trong bài toán:
```sql
SELECT 
    VA_ACC_NUMBER,
    ACTIVE_DATE AS StartDate,
    LEAD(CANCEL_DATE) OVER (
        PARTITION BY VA_ACC_NUMBER 
        ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)
    ) AS EndDate
FROM BK_VA_ACCOUNT_MANAGEMENT_BK
```

**Giải thích:**
- `PARTITION BY VA_ACC_NUMBER`: Xử lý riêng từng VA_ACC_NUMBER
- `ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)`: Sắp xếp theo thời gian (ưu tiên ACTIVE_DATE, nếu NULL thì dùng CANCEL_DATE)
- `LEAD(CANCEL_DATE)`: Lấy CANCEL_DATE từ dòng tiếp theo

#### Kết quả:
| VA_ACC_NUMBER | StartDate | EndDate (từ dòng kế) |
|---------------|-----------|---------------------|
| DATTESBAOCAOVA | 24-DEC-25 | 06-JAN-26 |
| DATTESBAOCAOVA | (null) | (null) |
| DATTESBAOCAOVA | 26-JAN-26 | (null) |

---

### 2. **COALESCE() - Null Handling**

#### Cú pháp:
```sql
COALESCE(value1, value2, value3, ...)
```

#### Chức năng:
- Trả về giá trị **không NULL đầu tiên** trong danh sách
- Tương tự `NVL()` nhưng hỗ trợ nhiều tham số hơn

#### Ví dụ:
```sql
-- Dùng để sắp xếp:
ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)

-- Dùng để filter:
WHERE COALESCE(ACTIVE_DATE, CANCEL_DATE) IS NOT NULL

-- Dùng để xử lý EndDate:
NVL(EndDate, SYSDATE)  -- Nếu EndDate NULL, dùng ngày hiện tại
```

---

### 3. **NVL() vs COALESCE()**

| Hàm | Số tham số | Ví dụ |
|-----|------------|-------|
| `NVL(col, default)` | 2 | `NVL(EndDate, SYSDATE)` |
| `COALESCE(col1, col2, col3)` | Nhiều | `COALESCE(EndDate, CANCEL_DATE, SYSDATE)` |

---

### 4. **TO_DATE() - Date Conversion**

#### Cú pháp:
```sql
TO_DATE(string_value, format_mask)
```

#### Ví dụ:
```sql
TO_DATE('28/12/2025', 'dd/mm/yyyy')
TO_DATE('2025-12-28', 'yyyy-mm-dd')
```

#### Lưu ý:
- Format mask phải khớp với chuỗi input
- `dd/mm/yyyy`: ngày/tháng/năm
- `yyyy-mm-dd`: năm-tháng-ngày

---

## 📝 Query Hoàn Chỉnh

### Query độc lập (test):
```sql
WITH ActivePeriods AS (
    SELECT 
        va_acc_number,
        ACTIVE_DATE AS StartDate,
        LEAD(CANCEL_DATE) OVER (
            PARTITION BY va_acc_number 
            ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)
        ) AS EndDate
    FROM bk_va_account_management_bk
    WHERE COALESCE(ACTIVE_DATE, CANCEL_DATE) IS NOT NULL
)
SELECT 
    va_acc_number, 
    StartDate, 
    NVL(EndDate, SYSDATE) AS EndDate
FROM ActivePeriods
WHERE StartDate IS NOT NULL
  -- Logic OVERLAP:
  AND StartDate <= TO_DATE('01/01/2026', 'dd/mm/yyyy')
  AND NVL(EndDate, SYSDATE) >= TO_DATE('28/12/2025', 'dd/mm/yyyy')
ORDER BY StartDate DESC;
```

---

### Query trong iBatis XML:
```xml
<![CDATA[AND EXISTS (
    SELECT 1
    FROM (
        SELECT 
            VA_ACC_NUMBER,
            ACTIVE_DATE AS StartDate,
            LEAD(CANCEL_DATE) OVER (
                PARTITION BY VA_ACC_NUMBER 
                ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)
            ) AS EndDate
        FROM BK_VA_ACCOUNT_MANAGEMENT_BK
        WHERE COALESCE(ACTIVE_DATE, CANCEL_DATE) IS NOT NULL
    ) ActivePeriods
    WHERE ActivePeriods.VA_ACC_NUMBER = va.VA_ACC_NUMBER
      AND StartDate IS NOT NULL ]]>
    
    <!-- Điều kiện OVERLAP -->
    <isNotEmpty property="vaStatusStartDate">
        <![CDATA[ AND NVL(EndDate, SYSDATE) >= TO_DATE(#vaStatusStartDate#, 'dd/mm/yyyy') ]]> 
    </isNotEmpty>
    <isNotEmpty property="vaStatusEndDate">
        <![CDATA[ AND StartDate <= TO_DATE(#vaStatusEndDate#, 'dd/mm/yyyy') ]]> 
    </isNotEmpty>
    
<![CDATA[
) ]]>
```

---

## 🎯 Điểm Quan Trọng

### 1. **Dùng EXISTS thay vì IN**
- **EXISTS**: Hiệu quả hơn với correlated subquery
- **IN**: Không thể sử dụng `va.VA_ACC_NUMBER` trong CTE

### 2. **PARTITION BY quan trọng**
```sql
LEAD(CANCEL_DATE) OVER (
    PARTITION BY VA_ACC_NUMBER  -- ← QUAN TRỌNG!
    ORDER BY COALESCE(ACTIVE_DATE, CANCEL_DATE)
)
```
- Không có `PARTITION BY`: LEAD() sẽ lấy dữ liệu từ VA khác
- Có `PARTITION BY`: LEAD() chỉ lấy trong cùng VA_ACC_NUMBER

### 3. **Logic Overlap**
```
StartDate <= SearchEndDate  AND  EndDate >= SearchStartDate
```
- **KHÔNG PHẢI**: `StartDate >= SearchStartDate AND EndDate <= SearchEndDate`
- Logic này quan trọng để tìm được tất cả các khoảng overlap

### 4. **Xử lý NULL**
```sql
NVL(EndDate, SYSDATE)  -- EndDate NULL = tài khoản vẫn active
```

---

## 🧪 Test Cases

### Test 1: Overlap hoàn toàn
```sql
-- Tìm: 28/12/2025 → 01/01/2026
-- Data: 24/12/2025 → 06/01/2026
-- Kết quả: ✅ TRẢ VỀ
```

### Test 2: Tìm rộng hơn dữ liệu
```sql
-- Tìm: 15/12/2025 → 01/01/2026
-- Data: 24/12/2025 → 06/01/2026
-- Kết quả: ✅ TRẢ VỀ
```

### Test 3: Tìm hẹp trong dữ liệu
```sql
-- Tìm: 28/12/2025 → 30/12/2025
-- Data: 24/12/2025 → 06/01/2026
-- Kết quả: ✅ TRẢ VỀ
```

### Test 4: Không overlap
```sql
-- Tìm: 15/12/2025 → 20/12/2025
-- Data: 24/12/2025 → 06/01/2026
-- Kết quả: ❌ KHÔNG TRẢ VỀ
```

### Test 5: EndDate NULL
```sql
-- Tìm: 28/12/2025 → 01/01/2026
-- Data: 26/01/2026 → (null = SYSDATE = 27/01/2026)
-- Kết quả: ❌ KHÔNG TRẢ VỀ (vì 26/01 > 01/01)
```

---

## 📚 Tài Liệu Tham Khảo

### Oracle Window Functions:
- `LEAD()`, `LAG()`, `ROW_NUMBER()`, `RANK()`
- Tài liệu: Oracle Database SQL Language Reference

### Date Functions:
- `TO_DATE()`, `NVL()`, `COALESCE()`, `SYSDATE`

### iBatis Dynamic SQL:
- `<isNotEmpty>`, `<![CDATA[]]>`

---

## 💡 Tips

1. **Test query độc lập trước** khi nhúng vào iBatis
2. **Dùng EXPLAIN PLAN** để kiểm tra performance
3. **Tạo index** trên `VA_ACC_NUMBER`, `ACTIVE_DATE`, `CANCEL_DATE`
4. **Validate input** từ người dùng (vaStatusStartDate, vaStatusEndDate)
5. **Log query** để debug khi có vấn đề

---

## ⚠️ Lưu Ý Performance

### Index cần thiết:
```sql
CREATE INDEX idx_bk_va_management_bk 
ON BK_VA_ACCOUNT_MANAGEMENT_BK(VA_ACC_NUMBER, ACTIVE_DATE, CANCEL_DATE);
```

### Nếu bảng lớn, cân nhắc:
- Materialized View cho ActivePeriods
- Partition bảng theo tháng/năm
- Thêm điều kiện lọc sớm hơn

---

**Ngày tạo:** 27/01/2026  
**Tác giả:** Documentation based on real implementation  
**Version:** 1.0