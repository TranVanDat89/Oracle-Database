# Phân tích Explain Plan — Query `getTradeFinanceDetail`

SQL_ID: `1kz9j8g925xsn` | Plan hash value: `2889289319` | Tổng thời gian: **5.23s**

---

## 0. Câu SQL gốc và đoạn Explain Plan

### 0.1 Câu SQL (bản gốc, trước khi tối ưu)

```sql
SELECT /*+ gather_plan_statistics */  
    trade.REQUEST_ID, trade.LC_NO,
    trade.AMOUNT AS LC_AMOUNT,
    trade.BENEFICIARY_NAME, u.FULL_NAME AS USER_NAME, trade.CREATE_TIME,
    trade.STATUS, trade.TRADE_TYPE, trade.CONTRACT_NO, 'Y' AS IS_TRADE_FINANCE,
    trade.CIF_NO, trade.LC_CURRENCY,
    trade.APPLICANT_NAME, trade.APPLICANT_ADDRESS, trade.BENEFICIARY_NAME, trade.BENEFICIARY_ADDRESS,
    trade.BENEFICIARY_COUNTRY, trade.TYPE_OF_CREDIT, trade.IS_TRANSFERABLE, trade.ADVISING_BANK_SWCODE,
    trade.ADVISING_BANK_NAME, trade.TRANSFERRING_BANK_SWCODE, trade.TRANSFERRING_BANK_NAME, trade.CONFIRMING_INS,
    trade.LC_CURRENCY, trade.AMOUNT_TOLERANCE_UB, trade.AMOUNT_TOLERANCE_LB, trade.QUANTITY_TOLERANCE_UB,
    trade.QUANTITY_TOLERANCE_LB, trade.DATE_OF_EXPIRY, trade.PLACE_OF_EXPIRY, trade.PRESENTATION_DAY,
    trade.PRESENTATION_AFTER, trade.PARTIAL_SHIPMENT, trade.TRANSSHIPMENT, trade.PLACE_RECEIPT,
    trade.PLACE_DESTINATION, trade.PORT_LOADING, trade.PORT_DISCHARG, trade.LASTEST_SHIPMENT_DATE,
    trade.PERIOD_SHIPMENT, trade.DESCRIPTION_GOODS, trade.ADDITIONAL_CONDITIONS, trade.MARGIN_RATIO,
    trade.DEBIT_ACC, trade.FEE_DEBIT_ACC, trade.PRESENTING_BANK, trade.BANK_INFORMATION,
    trade.PAYMENT_TENOR, trade.SHIPMENT, trade.AMEND_CHARGE_PAYABLE_BY, trade.OTHER_CHANGES, trade.LC_CONSULT_REQUEST_ID,
    trade.WF_PROCESS_ID, trade.TRAN_SN,
    (
        SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
               WITHIN GROUP (ORDER BY ATTACHMENT_ID) AS ATTACHMENTS
        FROM BK_CMS_FILE_ATTACHMENT
        WHERE ATTACHMENT_ID IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(trade.ATTACHMENT_IDS, '[^,]+', 1, LEVEL)))
            FROM dual
            CONNECT BY REGEXP_SUBSTR(trade.ATTACHMENT_IDS, '[^,]+', 1, LEVEL) IS NOT NULL
        )
    ) AS ATTACHMENT_IDS,
    trade.NUMBER_OF_AMENDMENTS, trade.CONTRACT_CURRENCY, trade.RESPONSE_CONTENT, trade.RESPONSE_TIME,
    (
        SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
               WITHIN GROUP (ORDER BY ATTACHMENT_ID) AS ATTACHMENTS
        FROM BK_CMS_FILE_ATTACHMENT
        WHERE ATTACHMENT_ID IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(trade.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL)))
            FROM dual
            CONNECT BY REGEXP_SUBSTR(trade.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL) IS NOT NULL
        )
    ) AS FILE_RESPONSE_IDS,
    country.COUNTRY_NAME, trade.PAYMENT_DEBIT_ACC, NULL AS ISSUE_DATE, trade.ATTACHMENT_IDS AS RAW_ATTACHMENT_IDS,
    NULL AS CONSULT_TYPE, NULL AS CONTRACT_NO, NULL AS CONTRACT_DATE,
    NULL AS CONTRACT_AMOUNT, NULL AS CONTRACT_CURRENCY, trade.IS_CUS_CHECKED,
    debitAcc.CCY AS DEBIT_ACC_CURRENCY, feeDebitAccc.CCY AS FEE_ACC_CURRENCY,
    paymentAcc.CCY AS PAYMENT_ACC_CURRENCY, trade.DOCUMENT_REQUIREDS
FROM BB_TRADE_FINANCE_MANAGEMENT trade
LEFT JOIN BK_COUNTRY country ON country.COUNTRY_CODE = trade.BENEFICIARY_COUNTRY
LEFT JOIN BB_USER_INFO u ON trade.CREATE_BY = u.USER_ID
LEFT JOIN BK_COMBOBOX tradeType ON tradeType.C_VALUES = trade.TRADE_TYPE AND tradeType.C_TABLE_NAME = 'LC_CONSULT_TYPE'
LEFT JOIN BK_COMBOBOX statusName ON statusName.C_VALUES = trade.STATUS AND statusName.C_TABLE_NAME = 'LC_STATUS'
LEFT JOIN V_ACCOUNT_INFO debitAcc ON debitAcc.ACCT_NO = trade.DEBIT_ACC
LEFT JOIN V_ACCOUNT_INFO feeDebitAccc ON feeDebitAccc.ACCT_NO = trade.FEE_DEBIT_ACC
LEFT JOIN V_ACCOUNT_INFO paymentAcc ON paymentAcc.ACCT_NO = trade.PAYMENT_DEBIT_ACC
WHERE 1=1 AND tran_sn = '2025081442268772';
```

### 0.2 Đoạn Explain Plan (DBMS_XPLAN.DISPLAY_CURSOR, ALLSTATS LAST)

```
SQL_ID  1kz9j8g925xsn, child number 0
-------------------------------------
Plan hash value: 2889289319

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                                  | Name                                   | Starts | E-Rows | A-Rows |   A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                           |                                        |      1 |        |      1 |00:00:05.23 |      43 |       |       |          |
|   1 |  SORT GROUP BY                             |                                        |      1 |      1 |      1 |00:00:00.02 |     248 |  2048 |  2048 | 2048  (0)|
|*  2 |   FILTER                                   |                                        |      1 |        |      1 |00:00:00.02 |     248 |       |       |          |
|   3 |    TABLE ACCESS FULL                       | BK_CMS_FILE_ATTACHMENT                 |      1 |   4246 |   4315 |00:00:00.01 |     248 |       |       |          |
|*  4 |    FILTER                                  |                                        |   4314 |        |      1 |00:00:00.02 |       0 |       |       |          |
|   5 |     CONNECT BY WITHOUT FILTERING (UNIQUE)  |                                        |   4314 |        |   4314 |00:00:00.01 |       0 |  2048 |  2048 | 2048  (0)|
|   6 |      FAST DUAL                             |                                        |   4314 |      1 |   4314 |00:00:00.01 |       0 |       |       |          |
|   7 |  SORT GROUP BY                             |                                        |      1 |      1 |      1 |00:00:00.01 |     248 |  1024 |  1024 |          |
|*  8 |   FILTER                                   |                                        |      1 |        |      0 |00:00:00.01 |     248 |       |       |          |
|   9 |    TABLE ACCESS FULL                       | BK_CMS_FILE_ATTACHMENT                 |      1 |   4246 |   4315 |00:00:00.01 |     248 |       |       |          |
|* 10 |    FILTER                                  |                                        |   4312 |        |      0 |00:00:00.01 |       0 |       |       |          |
|  11 |     CONNECT BY WITHOUT FILTERING (UNIQUE)  |                                        |   4312 |        |   4312 |00:00:00.01 |       0 |  2048 |  2048 | 2048  (0)|
|  12 |      FAST DUAL                             |                                        |   4312 |      1 |   4312 |00:00:00.01 |       0 |       |       |          |
|* 13 |  HASH JOIN RIGHT OUTER                     |                                        |      1 |     71G|      1 |00:00:05.23 |      43 |    46M|  7720K|   44M (0)|
|  14 |   VIEW                                     | V_ACCOUNT_INFO                         |      1 |    187K|    703K|00:00:00.34 |       0 |       |       |          |
|  15 |    REMOTE                                  | STTM_CUST_ACCOUNT                      |      1 |    187K|    703K|00:00:00.28 |       0 |       |       |          |
|* 16 |   HASH JOIN OUTER                          |                                        |      1 |     14M|      1 |00:00:03.32 |      43 |   687K|   687K| 1109K (0)|
|* 17 |    HASH JOIN OUTER                         |                                        |      1 |   3360 |      1 |00:00:01.64 |      43 |   686K|   686K|  429K (0)|
|* 18 |     HASH JOIN OUTER                        |                                        |      1 |      1 |      1 |00:00:00.01 |      43 |   686K|   686K|  446K (0)|
|* 19 |      HASH JOIN OUTER                       |                                        |      1 |      1 |      1 |00:00:00.01 |      38 |   686K|   686K|  448K (0)|
|* 20 |       HASH JOIN OUTER                      |                                        |      1 |      1 |      1 |00:00:00.01 |      22 |   686K|   686K|  450K (0)|
|  21 |        NESTED LOOPS OUTER                  |                                        |      1 |      1 |      1 |00:00:00.01 |       6 |       |       |          |
|  22 |         TABLE ACCESS BY INDEX ROWID BATCHED| BB_TRADE_FINANCE_MANAGEMENT            |      1 |      1 |      1 |00:00:00.01 |       3 |       |       |          |
|* 23 |          INDEX RANGE SCAN                  | BB_TRADE_FINANCE_MANAGEMENT_TRANSN_IDX |      1 |      1 |      1 |00:00:00.01 |       2 |       |       |          |
|  24 |         TABLE ACCESS BY INDEX ROWID BATCHED| BB_USER_INFO                           |      1 |      1 |      1 |00:00:00.01 |       3 |       |       |          |
|* 25 |          INDEX RANGE SCAN                  | BB_USER_INFO_PK                        |      1 |      1 |      1 |00:00:00.01 |       2 |       |       |          |
|* 26 |        TABLE ACCESS FULL                   | BK_COMBOBOX                            |      1 |      4 |      4 |00:00:00.01 |      16 |       |       |          |
|* 27 |       TABLE ACCESS FULL                    | BK_COMBOBOX                            |      1 |     13 |     13 |00:00:00.01 |      16 |       |       |          |
|  28 |      TABLE ACCESS FULL                     | BK_COUNTRY                             |      1 |    248 |    248 |00:00:00.01 |       5 |       |       |          |
|  29 |     VIEW                                   | V_ACCOUNT_INFO                         |      1 |    187K|    703K|00:00:06.09 |       0 |       |       |          |
|  30 |      REMOTE                                | STTM_CUST_ACCOUNT                      |      1 |    187K|    703K|00:00:06.04 |       0 |       |       |          |
|  31 |    VIEW                                    | V_ACCOUNT_INFO                         |      1 |    187K|    703K|00:00:06.19 |       0 |       |       |          |
|  32 |     REMOTE                                 | STTM_CUST_ACCOUNT                      |      1 |    187K|    703K|00:00:06.13 |       0 |       |       |          |
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( IS NOT NULL)
   4 - filter(TO_NUMBER(TRIM( REGEXP_SUBSTR (:B1,'[^,]+',1,LEVEL,<not feasible>)
   8 - filter( IS NOT NULL)
  10 - filter(TO_NUMBER(TRIM( REGEXP_SUBSTR (:B1,'[^,]+',1,LEVEL,<not feasible>)
  13 - access("FEEDEBITACCC"."ACCT_NO"="TRADE"."FEE_DEBIT_ACC")
  16 - access("DEBITACC"."ACCT_NO"="TRADE"."DEBIT_ACC")
  17 - access("PAYMENTACC"."ACCT_NO"="TRADE"."PAYMENT_DEBIT_ACC")
  18 - access("COUNTRY"."COUNTRY_CODE"="TRADE"."BENEFICIARY_COUNTRY")
  19 - access("STATUSNAME"."C_VALUES"="TRADE"."STATUS")
  20 - access("TRADETYPE"."C_VALUES"="TRADE"."TRADE_TYPE")
  23 - access("TRADE"."TRAN_SN"='2025081442268772')
  25 - access("TRADE"."CREATE_BY"="U"."USER_ID")
  26 - filter("TRADETYPE"."C_TABLE_NAME"='LC_CONSULT_TYPE')
  27 - filter("STATUSNAME"."C_TABLE_NAME"='LC_STATUS')
```

---

## 0.3 Explain Plan tô màu theo thứ tự thực thi (tầng phụ thuộc)

**Cách đọc bảng dưới:** mỗi dòng có cột **Tầng** — tầng số nhỏ chạy trước (không phụ thuộc ai), tầng số lớn chạy sau (gộp kết quả từ các tầng nhỏ hơn bên dưới nó). Màu đậm dần từ xanh lá → vàng → cam → đỏ tương ứng với thứ tự chạy sớm → muộn. Đây là thứ tự phụ thuộc dữ liệu thực tế (topological order), chính xác hơn nhiều so với chỉ nhìn số `Id` từ trên xuống.

<table>
<thead>
<tr><th>Tầng</th><th>Id</th><th>Operation</th><th>Name</th><th>A-Time</th><th>A-Rows</th></tr>
</thead>
<tbody>

<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>3</td><td>TABLE ACCESS FULL</td><td>BK_CMS_FILE_ATTACHMENT</td><td>00:00:00.01</td><td>4315</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>6</td><td>FAST DUAL</td><td></td><td>00:00:00.01</td><td>4314</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>9</td><td>TABLE ACCESS FULL</td><td>BK_CMS_FILE_ATTACHMENT</td><td>00:00:00.01</td><td>4315</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>12</td><td>FAST DUAL</td><td></td><td>00:00:00.01</td><td>4312</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>15</td><td>REMOTE</td><td>STTM_CUST_ACCOUNT (debitAcc)</td><td>00:00:00.28</td><td>703K</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>23</td><td>INDEX RANGE SCAN</td><td>BB_TRADE_FINANCE_MANAGEMENT_TRANSN_IDX</td><td>00:00:00.01</td><td>1</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>25</td><td>INDEX RANGE SCAN</td><td>BB_USER_INFO_PK</td><td>00:00:00.01</td><td>1</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>26</td><td>TABLE ACCESS FULL</td><td>BK_COMBOBOX (tradeType)</td><td>00:00:00.01</td><td>4</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>27</td><td>TABLE ACCESS FULL</td><td>BK_COMBOBOX (statusName)</td><td>00:00:00.01</td><td>13</td></tr>
<tr style="background-color:#e8f5e9; color:#1b1b1b"><td>1</td><td>28</td><td>TABLE ACCESS FULL</td><td>BK_COUNTRY</td><td>00:00:00.01</td><td>248</td></tr>
<tr style="background-color:#fdf6d8; color:#1b1b1b"><td>1</td><td>30</td><td>REMOTE</td><td>STTM_CUST_ACCOUNT (feeDebitAccc)</td><td>00:00:06.04</td><td>703K</td></tr>
<tr style="background-color:#fdf6d8; color:#1b1b1b"><td>1</td><td>32</td><td>REMOTE</td><td>STTM_CUST_ACCOUNT (paymentAcc)</td><td>00:00:06.13</td><td>703K</td></tr>

<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>4</td><td>FILTER</td><td>(dùng Id 3 + 5)</td><td>00:00:00.02</td><td>1</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>5</td><td>CONNECT BY WITHOUT FILTERING</td><td>(dùng Id 6)</td><td>00:00:00.01</td><td>4314</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>10</td><td>FILTER</td><td>(dùng Id 9 + 11)</td><td>00:00:00.01</td><td>0</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>11</td><td>CONNECT BY WITHOUT FILTERING</td><td>(dùng Id 12)</td><td>00:00:00.01</td><td>4312</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>14</td><td>VIEW</td><td>V_ACCOUNT_INFO (bọc Id 15)</td><td>00:00:00.34</td><td>703K</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>22</td><td>TABLE ACCESS BY INDEX ROWID BATCHED</td><td>BB_TRADE_FINANCE_MANAGEMENT (dùng Id 23)</td><td>00:00:00.01</td><td>1</td></tr>
<tr style="background-color:#fbeec7; color:#1b1b1b"><td>2</td><td>24</td><td>TABLE ACCESS BY INDEX ROWID BATCHED</td><td>BB_USER_INFO (dùng Id 25)</td><td>00:00:00.01</td><td>1</td></tr>
<tr style="background-color:#fbe0bd; color:#1b1b1b"><td>2</td><td>29</td><td>VIEW</td><td>V_ACCOUNT_INFO (bọc Id 30)</td><td>00:00:06.09</td><td>703K</td></tr>
<tr style="background-color:#fbe0bd; color:#1b1b1b"><td>2</td><td>31</td><td>VIEW</td><td>V_ACCOUNT_INFO (bọc Id 32)</td><td>00:00:06.19</td><td>703K</td></tr>

<tr style="background-color:#fbe0bd; color:#1b1b1b"><td>3</td><td>2</td><td>FILTER</td><td>(dùng Id 3 + 4)</td><td>00:00:00.02</td><td>1</td></tr>
<tr style="background-color:#fbe0bd; color:#1b1b1b"><td>3</td><td>8</td><td>FILTER</td><td>(dùng Id 9 + 10)</td><td>00:00:00.01</td><td>0</td></tr>
<tr style="background-color:#fbe0bd; color:#1b1b1b"><td>3</td><td>21</td><td>NESTED LOOPS OUTER</td><td>(dùng Id 22 + 24)</td><td>00:00:00.01</td><td>1</td></tr>

<tr style="background-color:#f9d3ab; color:#1b1b1b"><td>4</td><td>20</td><td>HASH JOIN OUTER</td><td>(dùng Id 21 + 26)</td><td>00:00:00.01</td><td>1</td></tr>

<tr style="background-color:#f6c69a; color:#1b1b1b"><td>5</td><td>19</td><td>HASH JOIN OUTER</td><td>(dùng Id 20 + 27)</td><td>00:00:00.01</td><td>1</td></tr>

<tr style="background-color:#f2b98a; color:#1b1b1b"><td>6</td><td>18</td><td>HASH JOIN OUTER</td><td>(dùng Id 19 + 28)</td><td>00:00:00.01</td><td>1</td></tr>

<tr style="background-color:#eeab79; color:#1b1b1b"><td>7</td><td>17</td><td>HASH JOIN OUTER</td><td>(dùng Id 18 + 29) ⚠ nạp 703K từ Id 29</td><td>00:00:01.64</td><td>1</td></tr>

<tr style="background-color:#e79c76; color:#1b1b1b"><td>8</td><td>16</td><td>HASH JOIN OUTER</td><td>(dùng Id 17 + 31) ⚠ nạp thêm 703K từ Id 31</td><td>00:00:03.32</td><td>1</td></tr>

<tr style="background-color:#df8b73; color:#1b1b1b"><td>9</td><td>13</td><td>HASH JOIN RIGHT OUTER</td><td>(dùng Id 14 + 16) ⚠ điểm hội tụ toàn bộ 3 nhánh remote</td><td>00:00:05.23</td><td>1</td></tr>
<tr style="background-color:#d67d72; color:#1b1b1b"><td>10</td><td>1</td><td>SORT GROUP BY</td><td>(dùng Id 2)</td><td>00:00:00.02</td><td>1</td></tr>
<tr style="background-color:#d67d72; color:#1b1b1b"><td>10</td><td>7</td><td>SORT GROUP BY</td><td>(dùng Id 8)</td><td>00:00:00.01</td><td>1</td></tr>
<tr style="background-color:#cc6f6f; color:#1b1b1b"><td>11</td><td>0</td><td>SELECT STATEMENT</td><td>(gộp Id 1 + 7 + 13 — kết quả cuối)</td><td>00:00:05.23</td><td>1</td></tr>

</tbody>
</table>

**Đọc nhanh theo màu:**
- 🟢 **Xanh lá (tầng 1, phần lớn)** — các thao tác đọc dữ liệu thô, độc lập, rất nhanh (index scan, full scan bảng nhỏ).
- 🟡 **Vàng nhạt (tầng 1-2, `Id 30/32/29/31`)** — đây là điểm bất thường: cùng tầng 1-2 như các thao tác xanh lá khác, nhưng mỗi cái tốn **6 giây** vì kéo 703K dòng qua DB link thay vì vài dòng.
- 🟠 **Cam đậm dần (tầng 4-8)** — chuỗi `HASH JOIN OUTER` gộp dần các nhánh; từ tầng 7 trở đi (`Id 17`, `Id 16`) thời gian tăng vọt vì bắt đầu "hứng" dữ liệu từ các nhánh remote màu vàng.
- 🔴 **Đỏ đậm (tầng 9-11)** — điểm hội tụ cuối cùng (`Id 13`, `Id 0`) — nơi toàn bộ 5.23s dồn về, vì tất cả các nhánh vàng phải hoàn tất trước khi hash join này build/probe xong.

Nhìn theo màu, thấy ngay: **các ô vàng nằm ở tầng thấp (chạy sớm) nhưng lại là nguồn cơn khiến toàn bộ chuỗi cam/đỏ phía trên bị kéo chậm theo** — đúng logic tối ưu đã đề xuất ở các câu trả lời trước: xử lý 3 remote call này trước tiên là sẽ giải quyết được toàn bộ vấn đề.

---

## 1. Nguyên tắc đọc plan (áp dụng cho mọi plan, không riêng case này)

1. **Đọc theo thụt lề (indentation), không đọc theo số Id thứ tự.** Operation con (thụt sâu hơn) luôn chạy trước để cung cấp dữ liệu cho operation cha (thụt nông hơn) ngay phía trên nó.
2. **Cột đáng tin nhất là `A-Time` và `A-Rows`** (actual — số liệu thật khi có hint `gather_plan_statistics`), không phải `E-Rows` hay `Cost` (chỉ là ước lượng của optimizer, có thể sai rất xa).
3. **Chênh lệch lớn giữa `E-Rows` và `A-Rows`** ở một dòng là dấu hiệu optimizer đang ước lượng sai (stats cũ, thiếu histogram, hoặc — như case này — không ước lượng được số liệu qua remote/DB link).
4. **`A-Time` là thời gian cộng dồn từ tất cả operation con bên dưới nó**, không phải thời gian riêng của bản thân operation đó. Muốn biết operation nào tốn thời gian "riêng", lấy `A-Time` của nó trừ đi tổng `A-Time` của các operation con ngay bên dưới.

---

## 2. Áp dụng vào plan thực tế

### Bước 1 — Tìm gốc rễ thời gian bằng cách so sánh A-Time giữa cha và con

```
Id 0  SELECT STATEMENT                                A-Time: 00:00:05.23   ← tổng toàn bộ query
Id 13  HASH JOIN RIGHT OUTER                           A-Time: 00:00:05.23   ← gần như 100% thời gian nằm ở đây
```

Vì `Id 0` và `Id 13` có A-Time gần như bằng nhau, toàn bộ 5.23s "chảy" qua nhánh `HASH JOIN RIGHT OUTER` — đây là nơi cần soi tiếp, không cần quan tâm `Id 1-12` (nhánh `LISTAGG`/`CONNECT BY` xử lý attachment, chỉ tốn 0.02s).

### Bước 2 — Soi vào nhánh tốn thời gian, đọc từ trong ra ngoài

`Id 13` có 2 nhánh con: `Id 14` (VIEW) và `Id 16` (HASH JOIN OUTER tiếp theo, chứa toàn bộ phần join local + 2 nhánh remote khác lồng bên trong):

```
Id 14  VIEW V_ACCOUNT_INFO           A-Time: 00:00:00.34   A-Rows: 703K
Id 15   REMOTE STTM_CUST_ACCOUNT     A-Time: 00:00:00.28   A-Rows: 703K

Id 29  VIEW V_ACCOUNT_INFO           A-Time: 00:00:06.09   A-Rows: 703K
Id 30   REMOTE STTM_CUST_ACCOUNT     A-Time: 00:00:06.04   A-Rows: 703K

Id 31  VIEW V_ACCOUNT_INFO           A-Time: 00:00:06.19   A-Rows: 703K
Id 32   REMOTE STTM_CUST_ACCOUNT     A-Time: 00:00:06.13   A-Rows: 703K
```

→ Cùng một pattern lặp lại **3 lần**: kéo full **703,000 dòng** từ bảng remote `STTM_CUST_ACCOUNT` (qua DB link) về, mỗi lần tốn 0.3–6.1 giây.

**Lưu ý về con số A-Time:** vì 3 nhánh remote này chạy lồng nhau trong hash join (không phải tuần tự độc lập), A-Time hiển thị (6.09s, 6.19s) có thể là thời gian tích lũy hoặc chồng lấn tùy cách Oracle tính song song nội bộ — điểm mấu chốt không phải cộng dồn chính xác 3 con số này, mà là: **cả 3 đều đang kéo 703K dòng thay vì vài dòng cần thiết**, đây mới là lãng phí thực sự.

### Bước 3 — Đối chiếu với Predicate Information để hiểu vì sao

```
13 - access("FEEDEBITACCC"."ACCT_NO"="TRADE"."FEE_DEBIT_ACC")
16 - access("DEBITACC"."ACCT_NO"="TRADE"."DEBIT_ACC")
17 - access("PAYMENTACC"."ACCT_NO"="TRADE"."PAYMENT_DEBIT_ACC")
```

Đây là 3 điều kiện join của 3 alias khác nhau (`feeDebitAccc`, `debitAcc`, `paymentAcc`) — cùng join vào 1 view `V_ACCOUNT_INFO`/bảng remote `STTM_CUST_ACCOUNT`, nhưng với 3 cột khác nhau của `trade`.

**Vì sao Oracle không tối ưu được:** điều kiện join (`ACCT_NO = trade.xxx`) phụ thuộc vào cột của bảng khác (correlated), nên optimizer của Oracle **không đẩy được filter này xuống remote site** (distributed query predicate pushdown không xảy ra với điều kiện dạng correlated join qua DB link). Kết quả: Oracle phải kéo toàn bộ bảng remote về local rồi mới lọc bằng hash join.

### Bước 4 — Nhìn con số E-Rows bất thường để cảnh giác thêm

```
Id 13  HASH JOIN RIGHT OUTER    E-Rows: 71G   A-Rows: 1
```

**71 tỷ dòng ước lượng** so với **1 dòng thực tế** — sai lệch cực đoan. Đây là hệ quả của việc optimizer nhân dồn cardinality qua nhiều tầng hash join có join column phụ thuộc dữ liệu remote (khó ước lượng chính xác qua DB link). Trong case này không gây hại vì A-Rows thực tế nhỏ, nhưng là tín hiệu cảnh báo: nếu sau này viết thêm query phức tạp hơn trên cùng cấu trúc bảng này, optimizer có thể chọn sai chiến lược join (ví dụ chọn nested loop cho một tập dữ liệu instance lớn hơn dự kiến) do cùng nguyên nhân ước lượng sai này.

---

## 3. Các dòng khác trong plan — vì sao KHÔNG phải ưu tiên

| Id | Operation | A-Time | Đánh giá |
|----|-----------|--------|----------|
| 3, 9 | `TABLE ACCESS FULL BK_CMS_FILE_ATTACHMENT` | 0.01s | Full scan nhưng bảng nhỏ (4315 dòng), rẻ. Do filter dùng `REGEXP_SUBSTR` nên index không dùng được (`<not feasible>` trong predicate) — chấp nhận được ở quy mô hiện tại |
| 22-25 | `BB_TRADE_FINANCE_MANAGEMENT` + `BB_USER_INFO` qua index range scan | 0.01s | Đã dùng đúng index (`BB_TRADE_FINANCE_MANAGEMENT_TRANSN_IDX`, `BB_USER_INFO_PK`), rất hiệu quả |
| 26-28 | `BK_COMBOBOX` ×2, `BK_COUNTRY` full scan | 0.01s | Bảng lookup nhỏ, full scan chấp nhận được |

**Kết luận đọc plan:** trong một plan phức tạp nhiều tầng, việc quan trọng nhất là nhanh chóng loại các nhánh có A-Time nhỏ (dù nhìn "nhiều Id" có vẻ phức tạp) và tập trung vào (các) nhánh chiếm phần lớn A-Time của root — ở đây là 3 nhánh `REMOTE STTM_CUST_ACCOUNT`, chiếm hơn 95% tổng thời gian.

---

## 4. Checklist đọc explain plan nhanh (áp dụng lần sau)

1. Lấy `A-Time` của root (`Id 0`) làm mốc tổng.
2. Đi dần xuống, tìm operation con có `A-Time` gần bằng root — đó là nhánh "ăn" thời gian.
3. Lặp lại bước 2 trong nhánh đó cho tới khi chạm vào operation lá (table access, index scan, remote call) — đó là nguyên nhân gốc.
4. Đối chiếu với `Predicate Information` để hiểu điều kiện lọc/join tại đó có tối ưu không (dùng đúng index? điều kiện có bị đẩy xuống remote không? có full scan trên bảng lớn không?).
5. Nếu thấy `E-Rows` và `A-Rows` lệch nhau nhiều bậc độ lớn (như 71G vs 1) → nghi ngờ stats hoặc khả năng ước lượng của optimizer trong hoàn cảnh đó (thường gặp ở remote/DB link, hoặc bind variable peeking).

---

## 5. Câu SQL sau khi tối ưu

Nguyên nhân gốc (mục 2, bước 3) là 3 lần `LEFT JOIN V_ACCOUNT_INFO` với điều kiện correlated (`ACCT_NO = trade.xxx`) khiến Oracle không đẩy được filter xuống remote site, phải kéo full 703K dòng về 3 lần. Cách sửa: tách account cần tra cứu ra một CTE riêng, dùng `WHERE ACCT_NO IN (...)` — literal filter, không còn correlated — để Oracle có cơ hội đẩy xuống remote.

### 5.1 Bản chuẩn hoá (SQL thuần, chưa gắn XML)

```sql
WITH trade_cte AS (
    SELECT
        trade.*,
        u.FULL_NAME AS USER_NAME,
        country.COUNTRY_NAME AS BENEFICIARY_COUNTRY_NAME
    FROM BB_TRADE_FINANCE_MANAGEMENT trade
    LEFT JOIN BK_COUNTRY country ON country.COUNTRY_CODE = trade.BENEFICIARY_COUNTRY
    LEFT JOIN BB_USER_INFO u ON trade.CREATE_BY = u.USER_ID
    WHERE trade.TRAN_SN = '2025081442268772'
),
acct_lookup AS (
    SELECT v.ACCT_NO, v.CCY
    FROM V_ACCOUNT_INFO v
    WHERE v.ACCT_NO IN (
        SELECT DEBIT_ACC FROM trade_cte WHERE DEBIT_ACC IS NOT NULL
        UNION
        SELECT FEE_DEBIT_ACC FROM trade_cte WHERE FEE_DEBIT_ACC IS NOT NULL
        UNION
        SELECT PAYMENT_DEBIT_ACC FROM trade_cte WHERE PAYMENT_DEBIT_ACC IS NOT NULL
    )
)
SELECT /*+ gather_plan_statistics */
    t.REQUEST_ID,
    t.LC_NO,
    t.AMOUNT AS LC_AMOUNT,
    t.BENEFICIARY_NAME,
    t.USER_NAME,
    t.CREATE_TIME,
    t.STATUS,
    t.TRADE_TYPE,
    t.CONTRACT_NO,
    'Y' AS IS_TRADE_FINANCE,
    t.CIF_NO,
    t.LC_CURRENCY,
    t.APPLICANT_NAME,
    t.APPLICANT_ADDRESS,
    t.BENEFICIARY_NAME,
    t.BENEFICIARY_ADDRESS,
    t.BENEFICIARY_COUNTRY,
    t.TYPE_OF_CREDIT,
    t.IS_TRANSFERABLE,
    t.ADVISING_BANK_SWCODE,
    t.ADVISING_BANK_NAME,
    t.TRANSFERRING_BANK_SWCODE,
    t.TRANSFERRING_BANK_NAME,
    t.CONFIRMING_INS,
    t.LC_CURRENCY,
    t.AMOUNT_TOLERANCE_UB,
    t.AMOUNT_TOLERANCE_LB,
    t.QUANTITY_TOLERANCE_UB,
    t.QUANTITY_TOLERANCE_LB,
    t.DATE_OF_EXPIRY,
    t.PLACE_OF_EXPIRY,
    t.PRESENTATION_DAY,
    t.PRESENTATION_AFTER,
    t.PARTIAL_SHIPMENT,
    t.TRANSSHIPMENT,
    t.PLACE_RECEIPT,
    t.PLACE_DESTINATION,
    t.PORT_LOADING,
    t.PORT_DISCHARG,
    t.LASTEST_SHIPMENT_DATE,
    t.PERIOD_SHIPMENT,
    t.DESCRIPTION_GOODS,
    t.ADDITIONAL_CONDITIONS,
    t.MARGIN_RATIO,
    t.DEBIT_ACC,
    t.FEE_DEBIT_ACC,
    t.PRESENTING_BANK,
    t.BANK_INFORMATION,
    t.PAYMENT_TENOR,
    t.SHIPMENT,
    t.AMEND_CHARGE_PAYABLE_BY,
    t.OTHER_CHANGES,
    t.LC_CONSULT_REQUEST_ID,
    t.WF_PROCESS_ID,
    t.TRAN_SN,
    (
        SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
               WITHIN GROUP (ORDER BY ATTACHMENT_ID)
        FROM BK_CMS_FILE_ATTACHMENT
        WHERE ATTACHMENT_ID IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(t.ATTACHMENT_IDS, '[^,]+', 1, LEVEL)))
            FROM dual
            CONNECT BY REGEXP_SUBSTR(t.ATTACHMENT_IDS, '[^,]+', 1, LEVEL) IS NOT NULL
        )
    ) AS ATTACHMENT_IDS,
    t.NUMBER_OF_AMENDMENTS,
    t.CONTRACT_CURRENCY,
    t.RESPONSE_CONTENT,
    t.RESPONSE_TIME,
    (
        SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
               WITHIN GROUP (ORDER BY ATTACHMENT_ID)
        FROM BK_CMS_FILE_ATTACHMENT
        WHERE ATTACHMENT_ID IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(t.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL)))
            FROM dual
            CONNECT BY REGEXP_SUBSTR(t.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL) IS NOT NULL
        )
    ) AS FILE_RESPONSE_IDS,
    t.BENEFICIARY_COUNTRY_NAME AS COUNTRY_NAME,
    t.PAYMENT_DEBIT_ACC,
    NULL AS ISSUE_DATE,
    t.ATTACHMENT_IDS AS RAW_ATTACHMENT_IDS,
    NULL AS CONSULT_TYPE,
    NULL AS CONTRACT_NO,
    NULL AS CONTRACT_DATE,
    NULL AS CONTRACT_AMOUNT,
    NULL AS CONTRACT_CURRENCY,
    t.IS_CUS_CHECKED,
    da.CCY AS DEBIT_ACC_CURRENCY,
    fa.CCY AS FEE_ACC_CURRENCY,
    pa.CCY AS PAYMENT_ACC_CURRENCY,
    t.DOCUMENT_REQUIREDS
FROM trade_cte t
LEFT JOIN acct_lookup da ON da.ACCT_NO = t.DEBIT_ACC
LEFT JOIN acct_lookup fa ON fa.ACCT_NO = t.FEE_DEBIT_ACC
LEFT JOIN acct_lookup pa ON pa.ACCT_NO = t.PAYMENT_DEBIT_ACC;
```

**Lưu ý:** hai bảng `BK_COMBOBOX` (tradeType, statusName) đã được bỏ khỏi bản tối ưu vì trong SELECT gốc, `trade.TRADE_TYPE`/`trade.STATUS` lấy trực tiếp từ `trade`, không dùng cột mô tả (`C_DESCRIPTION`) của 2 bảng combobox này — join đó là dư thừa, loại bỏ giúp giảm thêm 2 full table scan.

### 5.2 Bản gắn vào MyBatis/iBatis XML (filter động theo `requestId` / `tranSn`)

```xml
<select id="getTradeFinanceDetail" parameterClass="java.util.Map" resultMap="tradeFinanceDetailMap">
    <![CDATA[ 
       WITH trade_cte AS (
          SELECT
             trade.*,
             u.FULL_NAME AS USER_NAME,
             country.COUNTRY_NAME AS BENEFICIARY_COUNTRY_NAME
          FROM BB_TRADE_FINANCE_MANAGEMENT trade
          LEFT JOIN BK_COUNTRY country ON country.COUNTRY_CODE = trade.BENEFICIARY_COUNTRY
          LEFT JOIN BB_USER_INFO u ON trade.CREATE_BY = u.USER_ID
          WHERE 1=1
    ]]>
    <isNotEmpty property="requestId" prepend=" and ">
        <![CDATA[ trade.REQUEST_ID = #requestId# ]]>
    </isNotEmpty>
    <isNotEmpty property="tranSn" prepend=" and ">
        <![CDATA[ trade.TRAN_SN = #tranSn# ]]>
    </isNotEmpty>
    <![CDATA[ 
       ),
       acct_lookup AS (
          SELECT v.ACCT_NO, v.CCY
          FROM V_ACCOUNT_INFO v
          WHERE v.ACCT_NO IN (
             SELECT DEBIT_ACC FROM trade_cte WHERE DEBIT_ACC IS NOT NULL
             UNION
             SELECT FEE_DEBIT_ACC FROM trade_cte WHERE FEE_DEBIT_ACC IS NOT NULL
             UNION
             SELECT PAYMENT_DEBIT_ACC FROM trade_cte WHERE PAYMENT_DEBIT_ACC IS NOT NULL
          )
       )
       SELECT
          t.REQUEST_ID, t.LC_NO, t.AMOUNT AS LC_AMOUNT, t.BENEFICIARY_NAME, t.USER_NAME, t.CREATE_TIME,
          t.STATUS, t.TRADE_TYPE, t.CONTRACT_NO, 'Y' AS IS_TRADE_FINANCE, t.CIF_NO, t.LC_CURRENCY,
          t.APPLICANT_NAME, t.APPLICANT_ADDRESS, t.BENEFICIARY_NAME, t.BENEFICIARY_ADDRESS,
          t.BENEFICIARY_COUNTRY, t.TYPE_OF_CREDIT, t.IS_TRANSFERABLE, t.ADVISING_BANK_SWCODE,
          t.ADVISING_BANK_NAME, t.TRANSFERRING_BANK_SWCODE, t.TRANSFERRING_BANK_NAME, t.CONFIRMING_INS,
          t.LC_CURRENCY, t.AMOUNT_TOLERANCE_UB, t.AMOUNT_TOLERANCE_LB, t.QUANTITY_TOLERANCE_UB,
          t.QUANTITY_TOLERANCE_LB, t.DATE_OF_EXPIRY, t.PLACE_OF_EXPIRY, t.PRESENTATION_DAY,
          t.PRESENTATION_AFTER, t.PARTIAL_SHIPMENT, t.TRANSSHIPMENT, t.PLACE_RECEIPT,
          t.PLACE_DESTINATION, t.PORT_LOADING, t.PORT_DISCHARG, t.LASTEST_SHIPMENT_DATE,
          t.PERIOD_SHIPMENT, t.DESCRIPTION_GOODS, t.ADDITIONAL_CONDITIONS, t.MARGIN_RATIO,
          t.DEBIT_ACC, t.FEE_DEBIT_ACC, t.PRESENTING_BANK, t.BANK_INFORMATION,
          t.PAYMENT_TENOR, t.SHIPMENT, t.AMEND_CHARGE_PAYABLE_BY, t.OTHER_CHANGES, t.LC_CONSULT_REQUEST_ID,
          t.WF_PROCESS_ID, t.TRAN_SN,
          (
             SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
                   WITHIN GROUP (ORDER BY ATTACHMENT_ID)
             FROM BK_CMS_FILE_ATTACHMENT
             WHERE ATTACHMENT_ID IN (
                SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(t.ATTACHMENT_IDS, '[^,]+', 1, LEVEL)))
                FROM dual
                CONNECT BY REGEXP_SUBSTR(t.ATTACHMENT_IDS, '[^,]+', 1, LEVEL) IS NOT NULL
             )
          ) AS ATTACHMENT_IDS,
          t.NUMBER_OF_AMENDMENTS, t.CONTRACT_CURRENCY, t.RESPONSE_CONTENT, t.RESPONSE_TIME,
          (
             SELECT LISTAGG(ATTACHMENT_ID || ' / ' || FILE_NAME, ', ')
                   WITHIN GROUP (ORDER BY ATTACHMENT_ID)
             FROM BK_CMS_FILE_ATTACHMENT
             WHERE ATTACHMENT_ID IN (
                SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(t.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL)))
                FROM dual
                CONNECT BY REGEXP_SUBSTR(t.RESPONSE_FILE_ID, '[^,]+', 1, LEVEL) IS NOT NULL
             )
          ) AS FILE_RESPONSE_IDS,
          t.BENEFICIARY_COUNTRY_NAME AS COUNTRY_NAME, t.PAYMENT_DEBIT_ACC, NULL AS ISSUE_DATE,
          t.ATTACHMENT_IDS AS RAW_ATTACHMENT_IDS, NULL AS CONSULT_TYPE, NULL AS CONTRACT_NO,
          NULL AS CONTRACT_DATE, NULL AS CONTRACT_AMOUNT, NULL AS CONTRACT_CURRENCY, t.IS_CUS_CHECKED,
          da.CCY AS DEBIT_ACC_CURRENCY, fa.CCY AS FEE_ACC_CURRENCY, pa.CCY AS PAYMENT_ACC_CURRENCY,
          t.DOCUMENT_REQUIREDS
       FROM trade_cte t
       LEFT JOIN acct_lookup da ON da.ACCT_NO = t.DEBIT_ACC
       LEFT JOIN acct_lookup fa ON fa.ACCT_NO = t.FEE_DEBIT_ACC
       LEFT JOIN acct_lookup pa ON pa.ACCT_NO = t.PAYMENT_DEBIT_ACC
    ]]>
</select>
```

### 5.3 Kết quả kỳ vọng sau khi tối ưu

| Nhánh | Trước | Sau |
|---|---|---|
| Số lần fetch remote `STTM_CUST_ACCOUNT` | 3 lần | 1 lần |
| A-Rows mỗi lần fetch remote | 703K/lần | ≤ 3 (đúng bằng số account cần tra) |
| Full scan `BK_COMBOBOX` | 2 lần (dư thừa) | 0 (đã loại bỏ join không dùng đến) |
| Tổng A-Time | 5.23s | Kỳ vọng còn vài chục ms (chủ yếu là các index range scan + join local đã có sẵn) |

**Cần làm sau khi deploy:** chạy lại `DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST')` trên câu mới, xác nhận nhánh `REMOTE STTM_CUST_ACCOUNT` chỉ còn `A-Rows` nhỏ thay vì 703K — nếu vẫn còn lớn, nghĩa là predicate `IN (...)` vẫn chưa được đẩy xuống remote, cần xem `DBMS_METADATA.GET_DDL('VIEW', 'V_ACCOUNT_INFO')` để tìm nguyên nhân (view có logic phức tạp chặn pushdown).