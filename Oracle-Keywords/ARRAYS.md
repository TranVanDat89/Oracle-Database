# Các từ khóa làm việc với mảng (Collection) trong Oracle

## 1. Giới thiệu

Trong Oracle PL/SQL, mảng được gọi là **Collection**, gồm 3 loại:

* VARRAY
* Nested Table
* Associative Array (Index-by table): là một loại collection trong Oracle PL/SQL cho phép lưu trữ dữ liệu dạng key–value (chỉ mục – giá trị). Không cần cấp phát kích thước trước. Chỉ dùng trong PL/SQL, không dùng trực tiếp trong SQL.

Các collection hỗ trợ nhiều **phương thức (methods)** để thao tác dữ liệu.

---

## 2. Các phương thức phổ biến

Giả sử:

```sql id="7k2s8f"
v_tran_list some_collection_type;
```

---

### 2.1 EXTEND – Thêm phần tử

Dùng để tăng kích thước mảng

```sql id="c8z3fp"
v_tran_list.EXTEND;
v_tran_list(v_tran_list.LAST) := 'DATA';
```

👉 Các dạng:

```sql id="t7y2dn"
v_tran_list.EXTEND;       -- thêm 1 phần tử
v_tran_list.EXTEND(5);    -- thêm 5 phần tử
v_tran_list.EXTEND(1, 2); -- copy phần tử thứ 2
```

---

### 2.2 COUNT – Số phần tử

```sql id="z6x1nh"
v_tran_list.COUNT
```

---

### 2.3 FIRST / LAST – Phần tử đầu/cuối

```sql id="j9lm3s"
v_tran_list.FIRST
v_tran_list.LAST
```

---

### 2.4 NEXT / PRIOR – Duyệt mảng

```sql id="4h8d2k"
i := v_tran_list.FIRST;
WHILE i IS NOT NULL LOOP
    DBMS_OUTPUT.PUT_LINE(v_tran_list(i));
    i := v_tran_list.NEXT(i);
END LOOP;
```

---

### 2.5 DELETE – Xóa phần tử

```sql id="rmc4pt"
v_tran_list.DELETE;      -- xóa toàn bộ
v_tran_list.DELETE(2);   -- xóa phần tử index 2
```

---

### 2.6 EXISTS – Kiểm tra tồn tại

```sql id="1nq7ws"
IF v_tran_list.EXISTS(1) THEN
    DBMS_OUTPUT.PUT_LINE('Exists');
END IF;
```

---

### 2.7 TRIM – Xóa phần tử cuối

```sql id="7xq3av"
v_tran_list.TRIM;     -- xóa 1 phần tử cuối
v_tran_list.TRIM(2);  -- xóa 2 phần tử cuối
```

---

### 2.8 LIMIT – Giới hạn phần tử

Chỉ áp dụng cho **VARRAY**

```sql id="y3k2lp"
v_tran_list.LIMIT
```

---

## 3. Ví dụ hoàn chỉnh

```sql id="3u8qfz"
DECLARE
    TYPE str_list IS TABLE OF VARCHAR2(50);
    v_tran_list str_list := str_list();
BEGIN
    v_tran_list.EXTEND;
    v_tran_list(1) := 'A';

    v_tran_list.EXTEND;
    v_tran_list(2) := 'B';

    FOR i IN 1..v_tran_list.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_tran_list(i));
    END LOOP;
END;
```

---

## 4. Bảng tổng hợp

| Method | Mô tả             |
| ------ | ----------------- |
| EXTEND | Thêm phần tử      |
| COUNT  | Số phần tử        |
| FIRST  | Index đầu         |
| LAST   | Index cuối        |
| NEXT   | Index tiếp theo   |
| PRIOR  | Index trước       |
| DELETE | Xóa phần tử       |
| EXISTS | Kiểm tra tồn tại  |
| TRIM   | Xóa phần tử cuối  |
| LIMIT  | Giới hạn (VARRAY) |

---

## 5. Lưu ý

* `EXTEND`, `TRIM` chỉ dùng cho:

  * Nested Table
  * VARRAY
* Associative Array **không dùng EXTEND**
* Index không nhất thiết liên tục (đặc biệt với Associative Array)

---

## 6. Kết luận

Các phương thức của collection giúp:

* Quản lý mảng linh hoạt
* Tối ưu xử lý dữ liệu trong PL/SQL
* Viết code rõ ràng, dễ bảo trì

---
