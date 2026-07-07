# Các loại JSON Function trong Oracle

## 1. Giới thiệu

Oracle hỗ trợ xử lý dữ liệu JSON thông qua nhiều **JSON Functions**, giúp:

* Truy vấn dữ liệu JSON
* Chuyển đổi giữa JSON và relational data
* Tạo và cập nhật JSON

---

## 2. Phân loại JSON Function

Các JSON Function trong Oracle được chia thành 4 nhóm chính:

---

## 2.1 JSON Query Functions (Truy vấn JSON)

Dùng để **lấy dữ liệu từ JSON**

### JSON_VALUE

* Trả về **một giá trị đơn**

```sql id="j1k3d9"
SELECT JSON_VALUE(data, '$.name') FROM employees;
```

---

### JSON_QUERY

* Trả về **object hoặc array**

```sql id="k3l9x2"
SELECT JSON_QUERY(data, '$.address') FROM employees;
```

---

### JSON_TABLE

* Chuyển JSON thành **bảng (rows/columns)**

```sql id="x9d2lp"
SELECT *
FROM JSON_TABLE(
    data,
    '$.employees[*]'
    COLUMNS (
        name VARCHAR2(100) PATH '$.name',
        age NUMBER PATH '$.age'
    )
);
```

---

## 2.2 JSON Generation Functions (Tạo JSON)

Dùng để **tạo dữ liệu JSON từ SQL**

### JSON_OBJECT

```sql id="p3z8k1"
SELECT JSON_OBJECT(
    'name' VALUE name,
    'age' VALUE age
) FROM employees;
```

---

### JSON_ARRAY

```sql id="v7q2mn"
SELECT JSON_ARRAY(name, age) FROM employees;
```

---

### JSON_ARRAYAGG

* Gom nhiều dòng thành array

```sql id="y4r8bc"
SELECT JSON_ARRAYAGG(name) FROM employees;
```

---

### JSON_OBJECTAGG

* Gom key-value

```sql id="b2m9qa"
SELECT JSON_OBJECTAGG(id VALUE name) FROM employees;
```

---

## 2.3 JSON Modification Functions (Cập nhật JSON)

Dùng để **chỉnh sửa JSON**

### JSON_MERGEPATCH

```sql id="t8n2df"
SELECT JSON_MERGEPATCH(
    '{"name":"An"}',
    '{"age":25}'
) FROM dual;
```

---

### JSON_TRANSFORM (Oracle mới)

```sql id="w1x9za"
SELECT JSON_TRANSFORM(
    data,
    SET '$.age' = 30
) FROM employees;
```

---

## 2.4 JSON Condition Functions (Kiểm tra JSON)

Dùng để **validate hoặc kiểm tra JSON**

### IS JSON

```sql id="f9k2lm"
SELECT *
FROM employees
WHERE data IS JSON;
```

---

### JSON_EXISTS

* Kiểm tra path có tồn tại không

```sql id="u2z8xp"
SELECT *
FROM employees
WHERE JSON_EXISTS(data, '$.address');
```

---

## 3. So sánh nhanh

| Nhóm      | Function        | Mục đích          |
| --------- | --------------- | ----------------- |
| Query     | JSON_VALUE      | Lấy 1 giá trị     |
| Query     | JSON_QUERY      | Lấy object/array  |
| Query     | JSON_TABLE      | Convert sang bảng |
| Generate  | JSON_OBJECT     | Tạo object        |
| Generate  | JSON_ARRAY      | Tạo array         |
| Modify    | JSON_MERGEPATCH | Gộp JSON          |
| Modify    | JSON_TRANSFORM  | Cập nhật          |
| Condition | JSON_EXISTS     | Kiểm tra path     |

---

## 4. Khi nào dùng gì?

* Lấy 1 field → `JSON_VALUE`
* Lấy object → `JSON_QUERY`
* Convert sang bảng → `JSON_TABLE`
* Tạo JSON → `JSON_OBJECT`, `JSON_ARRAY`
* Update JSON → `JSON_TRANSFORM`
* Check tồn tại → `JSON_EXISTS`

---

## 5. Ví dụ tổng hợp

```sql id="q7k2ds"
    FUNCTION build_process_json(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN CLOB IS

        v_json CLOB;

    BEGIN
        SELECT JSON_ARRAYAGG(
                 JSON_OBJECT(
                    'applyName'  VALUE apply_name,
                    'title'      VALUE title,
                    'status'     VALUE status,
                    'startTime'  VALUE TO_CHAR(start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                    'endTime'    VALUE TO_CHAR(end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                    'remarks'    VALUE remarks,
                    'assignee'   VALUE assignee,
                    'userName'   VALUE user_name,
                    'fullName'   VALUE (CASE WHEN (full_name IS NULL OR full_name = '') THEN assignee ELSE full_name END),
                    'isActive'   VALUE (CASE WHEN is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                    'isPending'  VALUE (CASE WHEN is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                    'trans'      VALUE (
                        SELECT JSON_ARRAYAGG(
                                 JSON_OBJECT(
                                    'logId'          VALUE c.log_id,
                                    'wfProcessId'    VALUE c.wf_process_id,
                                    'applyName'      VALUE c.apply_name,
                                    'status'         VALUE c.status,
                                    'startTime'      VALUE TO_CHAR(c.start_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                                    'endTime'        VALUE TO_CHAR(c.end_time, 'YYYY-MM-DD"T"HH24:MI:SS'),
                                    'remarks'        VALUE c.remarks,
                                    'assignee'       VALUE c.assignee,
                                    'approveChannel' VALUE c.approve_channel,
                                    'tranSn'         VALUE c.tran_sn,
                                    'requestId'      VALUE c.request_id,
                                    'userName'       VALUE c.user_name,
                                    'fullName'       VALUE c.full_name,
                                    'isActive'       VALUE (CASE WHEN c.is_active = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON,
                                    'isPending'      VALUE (CASE WHEN c.is_pending = 'Y' THEN 'true' ELSE 'false' END) FORMAT JSON
                                 ABSENT ON NULL)
                               )
                          FROM TABLE(trans) c
                    ) FORMAT JSON
                 ABSENT ON NULL)
                 ORDER BY rn
               )
          INTO v_json
          FROM (
              SELECT h.*, ROWNUM AS rn
                FROM TABLE(pkg_wf_process_builder.build_process(p_request_id, p_corp_id, p_language, p_service_type)) h
          );

        RETURN NVL(v_json, '[]');

    END build_process_json;
```

---