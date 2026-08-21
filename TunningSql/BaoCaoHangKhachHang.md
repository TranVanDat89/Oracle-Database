# Case: Tối ưu query báo cáo Loyalty Rank (BK_LOYALTY_RANK_LOG)

## 1. Hiện trạng ban đầu

### 1.1. Query gốc (dùng window function)

```sql
SELECT /*+ gather_plan_statistics */
        COUNT(1)
    FROM
         bb_corp_info c
    JOIN bk_bank_org               b ON c.sign_org = b.org_no
    LEFT JOIN bk_loyalty_customer_class class ON c.class_id = class.id AND class.status = 'ACTV'
    LEFT JOIN (
        SELECT
            id,
            new_class,
            time,
            cif_no
        FROM
            (
                SELECT
                    l.*,
                    ROW_NUMBER()
                    OVER(PARTITION BY cif_no
                         ORDER BY
                             id DESC
                    ) rn
                FROM
                    bk_loyalty_rank_log l
            )
        WHERE
            rn = 1
    )                         log ON log.cif_no = c.cif_no
    LEFT JOIN bb_loyalty_point          p ON c.cif_no = p.cif_no
WHERE
        1 = 1
    AND c.class_id IS NOT NULL
    AND log.time >= to_date('18/05/2025', 'dd/mm/yyyy')
    AND log.time < to_date('18/08/2025', 'dd/mm/yyyy') + 1;
```

### 1.2. Mục đích query

Phục vụ màn hình báo cáo (report + count cho phân trang): liệt kê `bb_corp_info` có `class_id` khác NULL, kèm bản ghi loyalty rank mới nhất trong khoảng thời gian lọc.

### 1.3. Execution plan gốc (rút gọn) — A-Time ~34.46s

```
| Id | Operation                   | Name                      | E-Rows | A-Rows | A-Time     | Used-Mem | Used-Tmp |
|  0 | SELECT STATEMENT            |                            |        |      1 | 00:00:34.46|          |          |
|  1 |  SORT AGGREGATE             |                            |      1 |      1 | 00:00:34.46|          |          |
|* 2 |   HASH JOIN                 |                            |    34M |      0 | 00:00:34.46|          |          |
|* 3 |    HASH JOIN                |                            |  13356 |  10696 | 00:00:00.01|          |          |
|  4 |     TABLE ACCESS FULL       | BK_BANK_ORG                |    250 |    248 | 00:00:00.01|          |          |
|* 5 |     HASH JOIN RIGHT OUTER   |                            |  10696 |  10696 | 00:00:00.01|          |          |
|  6 |      TABLE ACCESS FULL      | BB_LOYALTY_POINT           |     39 |     41 | 00:00:00.01|          |          |
|* 7 |      HASH JOIN RIGHT OUTER  |                            |  10696 |  10696 | 00:00:00.01|          |          |
|* 8 |       TABLE ACCESS FULL     | BK_LOYALTY_CUSTOMER_CLASS  |     35 |     35 | 00:00:00.01|          |          |
|* 9 |       TABLE ACCESS FULL     | BB_CORP_INFO               |  10696 |  10696 | 00:00:00.01|          |          |
|*10 |    VIEW                     |                            |    27M |      0 | 00:00:34.45|          |          |
|*11 |     WINDOW SORT PUSHED RANK |                            |    27M |  10672 | 00:00:34.52|      97M |      56M |
|  12 |      TABLE ACCESS FULL     | BK_LOYALTY_RANK_LOG        |    27M |    28M | 00:00:01.42|          |          |
```

## 2. Phân tích nguyên nhân chậm (query gốc)

### 2.1. Nút thắt cổ chai

Toàn bộ thời gian dồn vào 3 bước liên quan đến `bk_loyalty_rank_log`:

1. **Id 12** – `TABLE ACCESS FULL BK_LOYALTY_RANK_LOG`: đọc toàn bộ **27 triệu dòng**, dù cuối cùng chỉ cần dữ liệu của ~10,696 `cif_no`.
2. **Id 11** – `WINDOW SORT PUSHED RANK`: tính `ROW_NUMBER() OVER (PARTITION BY cif_no ORDER BY id DESC)` cho **toàn bộ 27M dòng** trước khi biết dòng nào được giữ (`rn=1`). Sort vượt PGA (97M) nên tràn temp tablespace (**56M Used-Tmp**) — nguyên nhân chính gây chậm.
3. **Id 10** – `VIEW`: lọc `rn=1` và điều kiện `time` **sau khi** đã sort xong toàn bộ — công sức sort phần lớn bị lãng phí.
4. **Id 2** – `HASH JOIN` cuối: optimizer ước lượng sai cardinality (34M dự đoán vs A-Rows thực tế = 0), build hash table quá lớn.

### 2.2. Bản chất vấn đề

Query gốc tính rank cho **toàn bộ dữ liệu lịch sử** trước, rồi mới lọc theo `cif_no` cần thiết và theo thời gian — trong khi tập `cif_no` cần quan tâm đã biết trước (~10,696 dòng từ `bb_corp_info`). Hướng tối ưu đúng: **đảo ngược thứ tự xử lý** — lọc `cif_no`/điều kiện cần thiết trước, sau đó mới tìm bản ghi mới nhất cho từng `cif_no`.

## 3. Các phương án đã cân nhắc để thay thế window function

### 3.1. Giới hạn `cif_no` ngay trong subquery ranking

```sql
JOIN (
    SELECT cif_no, time
    FROM (
        SELECT l.cif_no, l.time,
               ROW_NUMBER() OVER (PARTITION BY l.cif_no ORDER BY l.id DESC) rn
        FROM bk_loyalty_rank_log l
        WHERE l.cif_no IN (SELECT cif_no FROM bb_corp_info WHERE class_id IS NOT NULL)
    )
    WHERE rn = 1
) log ON log.cif_no = c.cif_no
```

Ít thay đổi cấu trúc nhưng vẫn phụ thuộc việc optimizer có unnest `IN` thành semi-join hiệu quả hay không.

### 3.2. LATERAL JOIN (inner, cần `ON 1=1` giả)

```sql
JOIN LATERAL (
    SELECT l.time
    FROM bk_loyalty_rank_log l
    WHERE l.cif_no = c.cif_no
    ORDER BY l.id DESC
    FETCH FIRST 1 ROW ONLY
) log ON 1 = 1
```

### 3.3. OUTER APPLY — phương án được chọn

```sql
OUTER APPLY (
    SELECT
        l.ID,
        l.NEW_CLASS,
        l.TIME,
        l.CIF_NO
    FROM BK_LOYALTY_RANK_LOG l
    WHERE l.CIF_NO = c.CIF_NO
    ORDER BY l.ID DESC
    FETCH FIRST 1 ROW ONLY
) log
```

**So với LATERAL:** `OUTER APPLY` là LEFT/OUTER tự nhiên, không cần điều kiện `ON 1=1` giả. Trong case này, vì `WHERE log.time >= ... AND log.time < ...` ở ngoài tự động loại các dòng `log IS NULL`, kết quả của OUTER APPLY và LATERAL (inner) là **tương đương 100%** — nhưng cú pháp OUTER APPLY gọn và tự nhiên hơn.

**Cách thực thi:** khác window function (sort toàn bộ trước), OUTER APPLY/LATERAL chạy theo **NESTED LOOPS** — với mỗi dòng `c` (~10,696 dòng), probe vào `bk_loyalty_rank_log` 1 lần để lấy top-1 theo `id DESC`. Cách này chỉ nhanh nếu có **index đúng** hỗ trợ `(cif_no, id DESC)`; nếu không có index, sẽ full scan 27M dòng lặp lại 10,696 lần — tệ hơn bản gốc.

### Index tạo ban đầu

```sql
CREATE INDEX idx_rank_log_cif_id_time ON bk_loyalty_rank_log (cif_no, id DESC, time);
```

### 3.4. OUTER APPLY khác gì JOIN thường

Đây là điểm mấu chốt lý giải vì sao bài toán này **không thể dùng JOIN thường** mà bắt buộc phải dùng APPLY (hoặc window function).

**JOIN thường (kể cả LEFT/INNER):**
```sql
LEFT JOIN BB_LOYALTY_POINT p ON c.CIF_NO = p.CIF_NO
```
- Vế phải là **một tập dữ liệu cố định, độc lập**, không phụ thuộc bảng trái — chỉ so khớp qua điều kiện `ON`.
- Optimizer tự do chọn HASH JOIN, MERGE JOIN, hay NESTED LOOPS.
- Không thể diễn đạt "chỉ lấy 1 dòng mới nhất mỗi nhóm" trong `ON` — nếu `JOIN` thẳng vào `bk_loyalty_rank_log`, mỗi `cif_no` khớp với **nhiều dòng log** → kết quả bị **nhân bản dòng** (sai cả COUNT lẫn dữ liệu hiển thị).

**OUTER APPLY:**
```sql
OUTER APPLY (
    SELECT l.ID, l.NEW_CLASS, l.TIME, l.CIF_NO
    FROM BK_LOYALTY_RANK_LOG l
    WHERE l.CIF_NO = c.CIF_NO
    ORDER BY l.ID DESC
    FETCH FIRST 1 ROW ONLY
) log
```
- Subquery bên trong được phép **tham chiếu trực tiếp cột bảng trái** (`c.CIF_NO`) — là dạng **correlated subquery**, về bản chất được gọi lại cho từng dòng của `c`.
- Vì mỗi dòng `c` cho kết quả subquery khác nhau, Oracle bắt buộc dùng **NESTED LOOPS** (không thể HASH JOIN) — thể hiện trong plan bằng `Starts = 10696` (subquery "khởi động" lại 10,696 lần, một lần/`cif_no`).
- Giải trực tiếp bài toán **Top-N per group** (ở đây là Top-1: bản ghi mới nhất theo `id`) mà JOIN thường không làm được.
- `OUTER APPLY` giữ lại dòng trái không có match (giống LEFT JOIN); `CROSS APPLY` loại bỏ (giống INNER JOIN).

**Bảng so sánh:**

| | JOIN thường | OUTER APPLY / LATERAL |
|---|---|---|
| Vế phải phụ thuộc cột bảng trái | Không (chỉ qua `ON`) | Có — tham chiếu trực tiếp trong subquery |
| Join method optimizer chọn được | HASH JOIN, MERGE JOIN, NESTED LOOPS | Gần như luôn NESTED LOOPS |
| Giải bài toán "Top-N mỗi nhóm" | Không (gây nhân bản dòng) | Có (`FETCH FIRST N ROWS`) |
| Hiệu năng phụ thuộc chính vào | Kích thước 2 tập, cách build hash | Có index đúng cho subquery hay không |
| OUTER vs INNER | `LEFT/RIGHT/FULL JOIN` | `OUTER APPLY` vs `CROSS APPLY` |

**Kết luận cho case này:** mỗi `cif_no` trong `bk_loyalty_rank_log` có nhiều bản ghi lịch sử (27M dòng cho toàn bộ khách hàng), cần đúng 1 bản ghi mới nhất mỗi `cif_no` — đây là lý do **không thể dùng JOIN thường**, chỉ có thể chọn giữa window function (rank toàn bảng rồi lọc) hoặc APPLY (lặp theo từng `cif_no`, cần index hỗ trợ).

## 4. Partition hoá BK_LOYALTY_RANK_LOG (giải pháp bổ sung, đã áp dụng)

### 4.1. Lý do ban đầu

Bảng log tăng dần theo `time`, kỳ vọng RANGE partition theo `time` + LOCAL index sẽ giúp partition pruning và tăng tốc.

### 4.2. Tạo bảng partition bằng CTAS

```sql
CREATE TABLE bk_loyalty_rank_log_part
PARTITION BY RANGE (time)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_init VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
)
NOLOGGING
PARALLEL 8
AS
SELECT /*+ PARALLEL(8) */ *
FROM bk_loyalty_rank_log;

ALTER TABLE bk_loyalty_rank_log_part NOPARALLEL LOGGING;
```

### 4.3. LOCAL index + gather stats + rename

```sql
ALTER TABLE bk_loyalty_rank_log_part MODIFY (id NOT NULL);

ALTER TABLE bk_loyalty_rank_log_part
    ADD CONSTRAINT pk_rank_log_part PRIMARY KEY (id, time);

CREATE INDEX idx_rank_log_part_cif_id
    ON bk_loyalty_rank_log_part (cif_no, id DESC, time)
    LOCAL
    COMPRESS 1;

EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname     => 'SCHEMA_NAME',
    tabname     => 'BK_LOYALTY_RANK_LOG_PART',
    granularity => 'ALL',
    degree      => 8
);

RENAME bk_loyalty_rank_log TO bk_loyalty_rank_log_old;
RENAME bk_loyalty_rank_log_part TO bk_loyalty_rank_log;
```

> Nếu bảng đang được ghi liên tục 24/7 (khả năng cao với log table banking), nên dùng `DBMS_REDEFINITION` thay vì CTAS + rename thủ công để tránh mất dữ liệu ghi trong lúc copy.

## 5. Sự cố phát sinh: SELECT dữ liệu thật chậm hơn hẳn COUNT (81.65s)

### 5.1. Hiện tượng

Cùng cấu trúc JOIN/OUTER APPLY, nhưng khi đổi từ `COUNT(1)` sang `SELECT` các cột thực tế (phục vụ màn hình report), thời gian chạy tăng vọt lên **81.65 giây** — chậm hơn cả bản gốc dùng window function (34.46s).

### 5.2. Execution plan thực tế của câu SELECT (sau khi đã có LOCAL index + partition)

```
| Id | Operation                                        | Name                     | Starts | A-Rows | A-Time     | Buffers |
|  0 | SELECT STATEMENT                                 |                          |      1 |      0 |01:21.65    |     29M |
|  1 |  NESTED LOOPS                                    |                          |      1 |      0 |01:21.65    |     29M |
|* 2 |   HASH JOIN                                      |                          |      1 |  10696 |00:00.17    |    774  |
|  3 |    TABLE ACCESS FULL                             | BK_BANK_ORG              |      1 |    248 |00:00.01    |      7  |
|* 4 |    HASH JOIN RIGHT OUTER                         |                          |      1 |  10696 |00:00.12    |    767  |
|  5 |     TABLE ACCESS FULL                            | BB_LOYALTY_POINT         |      1 |     41 |00:00.01    |      7  |
|* 6 |     HASH JOIN RIGHT OUTER                        |                          |      1 |  10696 |00:00.07    |    760  |
|* 7 |      TABLE ACCESS FULL                           | BK_LOYALTY_CUSTOMER_CLASS|      1 |     36 |00:00.01    |      7  |
|* 8 |      TABLE ACCESS FULL                           | BB_CORP_INFO             |      1 |  10696 |00:00.03    |    753  |
|  9 |   VIEW                                           | VW_LAT_C786925F          |  10696 |      0 |01:21.46    |     29M |
| 10 |    VIEW                                          | VW_LAT_E88661A9          |  10696 |      0 |01:21.44    |     29M |
| 11 |     SORT ORDER BY                                |                          |  10696 |      0 |01:21.43    |     29M |
|*12 |      VIEW                                        |                          |  10696 |      0 |01:21.36    |     29M |
|*13 |       WINDOW SORT PUSHED RANK                    |                          |  10696 |  10666 |01:21.31    |     29M |
| 14 |        PARTITION RANGE ALL                       |                          |  10696 |    28M |01:20.95    |     29M |
| 15 |         TABLE ACCESS BY LOCAL INDEX ROWID BATCHED| BK_LOYALTY_RANK_LOG      |  96264 |    28M |01:18.20    |     29M |
|*16 |          INDEX RANGE SCAN                        | IDX_RANK_LOG_CIF_ID_TIME |  96264 |    28M |00:08.04    |    298K |
```

### 5.3. Nguyên nhân thật sự — KHÔNG phải do đổi COUNT sang SELECT

Ban đầu nghi ngờ do phải fetch thêm cột (random I/O by rowid) hoặc fetch size JDBC nhỏ, nhưng plan thực tế cho thấy nguyên nhân chính khác hẳn:

- **Id 14 — `PARTITION RANGE ALL`**: với **mỗi 1 trong 10,696 `cif_no`** (Starts=10696), Oracle phải duyệt qua **TẤT CẢ partition** của `bk_loyalty_rank_log`, không pruning được partition nào.
- **Id 16 — `Starts = 96264`**: 96264 / 10696 ≈ **9** — đúng bằng số partition hiện có. Với **mỗi cif_no**, Oracle mở index scan riêng trên **cả 9 partition** để tìm bản ghi.

**Gốc rễ:** query gốc tìm "bản ghi có `id` lớn nhất, **bất kể partition/time nào**" (`ORDER BY l.id DESC FETCH FIRST 1 ROW ONLY`, điều kiện `time` chỉ lọc **sau đó** ở WHERE ngoài). Vì partition key là `time` chứ không phải `cif_no`, Oracle **không thể biết trước** bản ghi có id lớn nhất của 1 cif_no nằm ở partition nào — bắt buộc phải quét LOCAL index ở toàn bộ 9 partition rồi mới gộp lại tìm max(id).

→ **10,696 cif_no × 9 partition = 96,264 lần index probe**, thay vì lý tưởng ~10,696 lần. **Partition theo `time` hoàn toàn không phù hợp với pattern "top-1 theo `id` cho từng `cif_no`, lọc `time` sau"** — việc partition trong trường hợp này làm chậm đi thay vì nhanh hơn.

> Lưu ý: câu COUNT trước đó (mục 3.3/5.1) chạy nhanh (~vài trăm ms cho phần APPLY) không phải vì "COUNT không cần đọc dữ liệu" mà thực chất **cùng vấn đề PARTITION RANGE ALL vẫn tồn tại** — điểm khác là tuỳ dữ liệu/thời điểm plan có thể chọn nhánh khác nhau; nguyên nhân cốt lõi được xác nhận chính xác khi có plan SELECT thật ở trên.

### 5.4. Phát hiện thêm — sai lệch logic nghiệp vụ

Query hiện tại trả lời: *"Bản ghi log mới nhất theo `id` (bất kể thời gian nào) của cif_no này — có `time` rơi vào khoảng lọc không?"* — khác với *"cif_no này có bản ghi log nào trong khoảng thời gian lọc không, nếu có thì lấy bản mới nhất **trong khoảng đó**?"*

Hai cách hiểu cho kết quả khác nhau nếu 1 cif_no có bản ghi mới nhất (id lớn nhất) nằm **ngoài** khoảng lọc, nhưng cũng có bản ghi khác **trong** khoảng lọc — theo logic cũ, cif_no này bị loại; theo logic đúng (theo kỳ báo cáo), cif_no này phải được tính.

Vì đây là màn hình report có tham số `beginDate`/`endDate`, nghiệp vụ đúng nên là **"bản ghi mới nhất trong khoảng thời gian lọc"**.

## 6. Giải pháp áp dụng: đưa điều kiện thời gian vào trong OUTER APPLY

> **Điểm cải thiện lớn nhất, mấu chốt của toàn bộ quá trình tuning:** lọc điều kiện `time` **trước** khi tìm bản ghi mới nhất (đưa vào bên trong `OUTER APPLY`, trước `ORDER BY`/`FETCH FIRST`) — thay vì lọc **sau** như query cũ. Nhờ vậy Oracle biết trước phạm vi partition cần quét ngay từ đầu, kích hoạt được **partition pruning** đúng nghĩa (chỉ chạm vào vài partition liên quan thay vì `PARTITION RANGE ALL` quét toàn bộ). Đây là thay đổi quyết định giúp giảm thời gian chạy, không phải việc đổi APPLY/JOIN hay đổi index.

### 6.1. Nguyên tắc sửa

Đưa `beginDate`/`endDate` vào **bên trong** `OUTER APPLY`, lọc `l.TIME` **trước** `ORDER BY`/`FETCH FIRST`, thay vì lọc `log.TIME` ở `WHERE` ngoài. Nhờ đó:
- Đúng nghiệp vụ: lấy bản ghi mới nhất **trong** khoảng thời gian lọc.
- Đúng hiệu năng: Oracle biết trước cần partition nào (pruning theo `time`) **trước khi** tìm max(id), LOCAL index hoạt động đúng ý — không còn `PARTITION RANGE ALL`.

### 6.2. Mapper `getLoyaltyCustomerRankReport` (đã sửa)

```xml
<select id="getLoyaltyCustomerRankReport" parameterType="java.util.Map" resultMap="customerRankReport">
    <![CDATA[
        SELECT *
        FROM (
            SELECT
                t.*,
                ROWNUM RN
            FROM (
                SELECT
                    b.ORG_NO,
                    b.ORG_NO || '_' || b.FULL_NAME AS ORG_NAME,
                    c.CIF_NO,
                    c.CORP_NAME,
                    class.ID AS CLASS_ID,
                    class.CLASS_NAME,
                    log.TIME AS UPDATED_CLASS_DATE,
                    p.POINT_AMOUNT AS POINT_AVAILABLE,
                    TO_CHAR(log.TIME, 'dd/MM/yyyy') AS UPDATED_CLASS_DATE_STR

                FROM BB_CORP_INFO c

                JOIN BK_BANK_ORG b
                    ON c.SIGN_ORG = b.ORG_NO

                LEFT JOIN BK_LOYALTY_CUSTOMER_CLASS class
                    ON c.CLASS_ID = class.ID
                    AND class.STATUS = 'ACTV'

                OUTER APPLY (
                    SELECT
                        l.ID,
                        l.NEW_CLASS,
                        l.TIME,
                        l.CIF_NO
                    FROM BK_LOYALTY_RANK_LOG l
                    WHERE l.CIF_NO = c.CIF_NO
    ]]>

    <if test="beginDate != null ">
        <![CDATA[
            AND l.TIME >= TO_DATE(#{beginDate}, 'dd/mm/yyyy')
        ]]>
    </if>

    <if test="endDate != null ">
        <![CDATA[
            AND l.TIME < TO_DATE(#{endDate}, 'dd/mm/yyyy') + 1
        ]]>
    </if>

    <![CDATA[
                    ORDER BY l.ID DESC
                    FETCH FIRST 1 ROW ONLY
                ) log

                LEFT JOIN BB_LOYALTY_POINT p
                    ON c.CIF_NO = p.CIF_NO

                WHERE c.CLASS_ID IS NOT NULL
    ]]>

    <if test="cifNo != null and cifNo != ''">
        <![CDATA[
            AND c.CIF_NO = #{cifNo}
        ]]>
    </if>

    <if test="classId != null and classId != ''">
        <![CDATA[
            AND c.CLASS_ID = #{classId}
        ]]>
    </if>

    <![CDATA[
                ORDER BY c.CREATE_TIME DESC
            ) t
        )
    ]]>

    <where>

        <if test="toRecord != null and toRecord != ''">
            <![CDATA[
                RN <= #{toRecord}
            ]]>
        </if>

        <if test="fromRecord != null and fromRecord != ''">
            <![CDATA[
                AND RN >= #{fromRecord}
            ]]>
        </if>

    </where>

</select>
```

### 6.3. Mapper `getLoyaltyCustomerRankReport_count` (đã sửa)

```xml
<select id="getLoyaltyCustomerRankReport_count" parameterType="java.util.Map" resultType="java.lang.Integer">
    <![CDATA[
        SELECT COUNT(1)

        FROM BB_CORP_INFO c

        JOIN BK_BANK_ORG b
            ON c.SIGN_ORG = b.ORG_NO

        LEFT JOIN BK_LOYALTY_CUSTOMER_CLASS class
            ON c.CLASS_ID = class.ID
            AND class.STATUS = 'ACTV'

        OUTER APPLY (
            SELECT
                l.ID,
                l.NEW_CLASS,
                l.TIME,
                l.CIF_NO
            FROM BK_LOYALTY_RANK_LOG l
            WHERE l.CIF_NO = c.CIF_NO
    ]]>

    <if test="beginDate != null ">
        <![CDATA[
            AND l.TIME >= TO_DATE(#{beginDate}, 'dd/mm/yyyy')
        ]]>
    </if>

    <if test="endDate != null ">
        <![CDATA[
            AND l.TIME < TO_DATE(#{endDate}, 'dd/mm/yyyy') + 1
        ]]>
    </if>

    <![CDATA[
            ORDER BY l.ID DESC
            FETCH FIRST 1 ROW ONLY
        ) log

        LEFT JOIN BB_LOYALTY_POINT p
            ON c.CIF_NO = p.CIF_NO

        WHERE c.CLASS_ID IS NOT NULL
    ]]>

    <if test="cifNo != null and cifNo != ''">
        <![CDATA[
            AND c.CIF_NO = #{cifNo}
        ]]>
    </if>

    <if test="classId != null and classId != ''">
        <![CDATA[
            AND c.CLASS_ID = #{classId}
        ]]>
    </if>

</select>
```

### 6.4. Những gì đã thay đổi

1. `beginDate`/`endDate` chuyển từ `WHERE` ngoài vào bên trong `OUTER APPLY` (điều kiện trên `l.TIME`), áp dụng **trước** `ORDER BY`/`FETCH FIRST`.
2. `cifNo`, `classId` giữ nguyên ở `WHERE` ngoài vì là điều kiện trên `c`, không liên quan `log`.
3. Điều kiện `log.TIME` cũ ở WHERE ngoài **bị xoá hẳn** (không chỉ thêm ở trong) để partition pruning phát huy tác dụng đầy đủ.
4. Trường hợp `beginDate`/`endDate` đều NULL: `OUTER APPLY` lấy đúng bản ghi mới nhất tuyệt đối theo `id` (không lọc time) — giữ nguyên hành vi cũ cho trường hợp không lọc theo ngày.

## 7. Bàn về LOCAL index vs GLOBAL index

### 7.1. Sau khi đã sửa query (mục 6), LOCAL index có còn đủ dùng?

**Đủ dùng cho trường hợp có truyền `beginDate`/`endDate`** — vì lúc này Oracle pruning đúng partition theo `time` trước khi tìm max(id), không còn `PARTITION RANGE ALL`.

**Vẫn có thể gặp lại vấn đề cũ nếu `beginDate`/`endDate` đều NULL** (không lọc time) — quay lại tình huống phải tìm max(id) trên toàn bảng, LOCAL index lại bị quét toàn bộ partition (`PARTITION RANGE ALL`).

### 7.2. Global index — ưu/nhược điểm

**Ưu điểm:** 1 B-tree duy nhất trên toàn bảng, luôn tìm thẳng ra bản ghi mới nhất theo `(cif_no, id DESC)` mà không phụ thuộc partition/filter time — nhanh ổn định bất kể có lọc time hay không. Không hề chậm hơn LOCAL index khi dùng cho SELECT/query thông thường.

**Nhược điểm — chi phí khi maintenance partition:**
- Khi `DROP`/`TRUNCATE` một partition (thao tác dọn log cũ định kỳ), global index bị đánh dấu **`UNUSABLE` toàn bộ**, cần rebuild:
  ```sql
  ALTER INDEX idx_rank_log_cif_id_global REBUILD ONLINE;
  ```
- Có thể né bằng `UPDATE INDEXES` khi drop partition:
  ```sql
  ALTER TABLE bk_loyalty_rank_log DROP PARTITION p_2024_01 UPDATE INDEXES;
  ```
  nhưng vẫn tốn I/O update index ngay trong lệnh đó (gộp chi phí rebuild vào cùng bước thay vì tách riêng).
- Không tận dụng được lợi ích "nhẹ, độc lập từng phần" của LOCAL index khi rebuild/maintenance.

### 7.3. Khuyến nghị lựa chọn

| Tình huống | Nên dùng |
|---|---|
| Luôn truyền `beginDate`/`endDate` (không bao giờ NULL cả 2) | **LOCAL index** đủ dùng |
| Có trường hợp không lọc time, hoặc muốn hiệu năng ổn định không phụ thuộc filter | **GLOBAL index**, chấp nhận thêm bước `UPDATE INDEXES` khi drop partition |
| Không có kế hoạch drop/archive partition trong tương lai gần | Global index gần như không có nhược điểm |

```sql
-- Nếu chọn global:
DROP INDEX idx_rank_log_part_cif_id;

CREATE INDEX idx_rank_log_cif_id_global
    ON bk_loyalty_rank_log (cif_no, id DESC, time)
    GLOBAL
    COMPRESS 1;
```

**Việc cần xác nhận thêm:** bảng `BK_LOYALTY_RANK_LOG` có job drop/archive partition cũ định kỳ hay không — đây là yếu tố quyết định chính giữa LOCAL và GLOBAL.

## 8. Kiểm tra kết quả sau khi sửa

```sql
SELECT /*+ gather_plan_statistics */
    b.ORG_NO,
    b.ORG_NO || '_' || b.FULL_NAME AS ORG_NAME,
    c.CIF_NO,
    c.CORP_NAME,
    class.ID AS CLASS_ID,
    class.CLASS_NAME,
    log.TIME AS UPDATED_CLASS_DATE,
    p.POINT_AMOUNT AS POINT_AVAILABLE,
    TO_CHAR(log.TIME, 'dd/MM/yyyy') AS UPDATED_CLASS_DATE_STR
FROM BB_CORP_INFO c
JOIN BK_BANK_ORG b ON c.SIGN_ORG = b.ORG_NO
LEFT JOIN BK_LOYALTY_CUSTOMER_CLASS class
     ON c.CLASS_ID = class.ID AND class.STATUS = 'ACTV'
OUTER APPLY (
    SELECT l.ID, l.NEW_CLASS, l.TIME, l.CIF_NO
    FROM BK_LOYALTY_RANK_LOG l
    WHERE l.CIF_NO = c.CIF_NO
      AND l.TIME >= to_date('18/05/2025', 'dd/mm/yyyy')
      AND l.TIME <  to_date('18/08/2025', 'dd/mm/yyyy') + 1
    ORDER BY l.ID DESC
    FETCH FIRST 1 ROW ONLY
) log
LEFT JOIN BB_LOYALTY_POINT p ON c.CIF_NO = p.CIF_NO
WHERE c.CLASS_ID IS NOT NULL;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

**Kết quả mong đợi trong plan mới:**
- `PARTITION RANGE ALL` biến mất, thay bằng `PARTITION RANGE ITERATOR` (chỉ ~4 partition trong khoảng 18/05–18/08).
- `Starts` ở `INDEX RANGE SCAN` giảm về gần đúng ~10,696 (1 lần/cif_no × số partition liên quan, không còn nhân với toàn bộ 9 partition).
- Không còn `WINDOW SORT PUSHED RANK` tràn temp.
- A-Time tổng giảm mạnh so với cả bản gốc (34.46s) lẫn bản lỗi partition (81.65s).

Nếu vẫn thấy `TABLE ACCESS FULL BK_LOYALTY_RANK_LOG` hoặc `PARTITION RANGE ALL` lặp lại → kiểm tra lại index chưa được tạo/chọn đúng, hoặc thống kê (`DBMS_STATS`) chưa cập nhật.

## 9. Tóm tắt hành trình tuning

| Bước | Vấn đề phát hiện | Giải pháp | Kết quả |
|---|---|---|---|
| 1 | Query gốc dùng `ROW_NUMBER()` window function, sort toàn bộ 27M dòng trước khi lọc | Đổi sang `OUTER APPLY` (top-1 theo `id` per `cif_no`) | Giảm từ full sort 27M dòng xuống NESTED LOOPS theo cif_no |
| 2 | OUTER APPLY chậm nếu không có index hỗ trợ `(cif_no, id DESC)` | Tạo index `(cif_no, id DESC, time)` | Cho phép INDEX RANGE SCAN thay vì full scan lặp lại |
| 3 | Bảng log lớn, muốn thêm partition theo `time` để pruning | Tạo bảng partition RANGE INTERVAL theo `time` bằng CTAS + LOCAL index | — |
| 4 | Sau khi partition, câu SELECT dữ liệu thật chậm hơn cả bản gốc (81.65s) do `PARTITION RANGE ALL` — lọc `time` ở WHERE ngoài không giúp pruning vì APPLY tìm max(id) trước, không phân biệt partition | Đưa điều kiện `beginDate`/`endDate` vào **bên trong** `OUTER APPLY`, lọc trước `ORDER BY`/`FETCH FIRST` | Partition pruning hoạt động đúng, đồng thời sửa đúng lại logic nghiệp vụ "bản ghi mới nhất **trong kỳ báo cáo**" |
| 5 | Cân nhắc LOCAL vs GLOBAL index cho trường hợp không truyền `beginDate`/`endDate` | Tuỳ vào có job drop/archive partition định kỳ hay không: LOCAL nếu luôn lọc time, GLOBAL nếu cần ổn định mọi trường hợp (đánh đổi chi phí rebuild khi drop partition) | Cần xác nhận thêm với đội vận hành |

## 10. Việc cần làm tiếp

1. Deploy 2 mapper `getLoyaltyCustomerRankReport` và `getLoyaltyCustomerRankReport_count` đã sửa (mục 6).
2. Chạy lại `gather_plan_statistics` + `DBMS_XPLAN.DISPLAY_CURSOR` để xác nhận plan mới đúng như kỳ vọng ở mục 8.
3. Xác nhận với nghiệp vụ: có đồng ý đổi ý nghĩa từ "bản ghi mới nhất tuyệt đối" sang "bản ghi mới nhất trong kỳ báo cáo" không (mục 5.4).
4. Xác nhận có job drop/archive partition cũ định kỳ trên `BK_LOYALTY_RANK_LOG` hay không, để quyết định LOCAL hay GLOBAL index (mục 7.3).
5. Nếu chọn GLOBAL index, cập nhật quy trình drop partition để dùng `UPDATE INDEXES` hoặc có bước rebuild index sau đó.
6. Rà soát các nơi khác trong hệ thống có dùng chung `BK_LOYALTY_RANK_LOG` với pattern APPLY tương tự nhưng chưa lọc time trong subquery, để áp dụng cùng cách sửa.