# Duyệt mảng và cấu trúc điều khiển trong Oracle PL/SQL

## 1. Giới thiệu

Trong PL/SQL, để xử lý dữ liệu trong **collection (array)**, ta thường dùng:

* Vòng lặp: `FOR`, `WHILE`
* Điều kiện: `IF`, `CASE`

---

## 2. Các cách duyệt mảng

Giả sử:

```sql
DECLARE
    TYPE num_list IS TABLE OF NUMBER;
    v_arr num_list := num_list(10, 20, 30);
```

---

### 2.1 Duyệt bằng FOR (cơ bản)

```sql
FOR i IN 1..v_arr.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_arr(i));
END LOOP;
```

👉 Đơn giản, dùng khi index liên tục

---

### 2.2 Duyệt bằng WHILE (an toàn hơn)

```sql
i := v_arr.FIRST;
WHILE i IS NOT NULL LOOP
    DBMS_OUTPUT.PUT_LINE(v_arr(i));
    i := v_arr.NEXT(i);
END LOOP;

i := 1;
WHILE i <= v_arr.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_arr(i));
    i := i + 1;
END LOOP;
```

👉 Dùng được cho:

* Nested Table (có thể bị "lỗi index")
* Associative Array

---

### 2.3 Duyệt bằng FOR + FIRST/LAST

```sql
FOR i IN v_arr.FIRST..v_arr.LAST LOOP
    IF v_arr.EXISTS(i) THEN
        DBMS_OUTPUT.PUT_LINE(v_arr(i));
    END IF;
END LOOP;
```

---

## 3. Các keyword quan trọng khi duyệt mảng

| Keyword   | Ý nghĩa          |
| --------- | ---------------- |
| COUNT     | Số phần tử       |
| FIRST     | Index đầu        |
| LAST      | Index cuối       |
| NEXT(i)   | Index tiếp theo  |
| PRIOR(i)  | Index trước      |
| EXISTS(i) | Kiểm tra tồn tại |
| DELETE    | Xóa phần tử      |

---

## 4. Cấu trúc điều khiển

---

### 4.1 IF – ELSE

```sql
IF v_arr(i) > 10 THEN
    DBMS_OUTPUT.PUT_LINE('Lớn hơn 10');
ELSIF v_arr(i) = 10 THEN
    DBMS_OUTPUT.PUT_LINE('Bằng 10');
ELSE
    DBMS_OUTPUT.PUT_LINE('Nhỏ hơn 10');
END IF;
```

---

### 4.2 CASE (thay cho SWITCH)

Oracle **không có SWITCH**, dùng `CASE` thay thế

#### Simple CASE

```sql
CASE v_arr(i)
    WHEN 10 THEN DBMS_OUTPUT.PUT_LINE('Ten');
    WHEN 20 THEN DBMS_OUTPUT.PUT_LINE('Twenty');
    ELSE DBMS_OUTPUT.PUT_LINE('Other');
END CASE;
```

---

#### Searched CASE

```sql
CASE
    WHEN v_arr(i) > 20 THEN DBMS_OUTPUT.PUT_LINE('>20');
    WHEN v_arr(i) > 10 THEN DBMS_OUTPUT.PUT_LINE('>10');
    ELSE DBMS_OUTPUT.PUT_LINE('<=10');
END CASE;
```

---

## 5. Ví dụ tổng hợp

```sql
        FUNCTION resolve_files(p_attachment_ids IN VARCHAR2) RETURN t_transaction_file_tab IS
            v_files t_transaction_file_tab := t_transaction_file_tab();
        BEGIN
            IF p_attachment_ids IS NULL THEN
                RETURN NULL;
            END IF;

            FOR f IN (
                SELECT a.ATTACHMENT_ID, a.FILE_NAME
                  FROM BK_CMS_FILE_ATTACHMENT a
                 WHERE a.ATTACHMENT_ID IN (
                     SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(p_attachment_ids, '[^,]+', 1, LEVEL)))
                       FROM DUAL
                     CONNECT BY REGEXP_SUBSTR(p_attachment_ids, '[^,]+', 1, LEVEL) IS NOT NULL
                 )
            ) LOOP
                v_files.EXTEND;
                v_files(v_files.LAST) := t_transaction_file(
                    attachment_id => TO_CHAR(f.ATTACHMENT_ID),
                    file_name     => f.FILE_NAME
                );
            END LOOP;

            IF v_files.COUNT = 0 THEN
                RETURN NULL; -- không tìm thấy file nào khớp -> để NULL thay vì mảng rỗng
            END IF;

            RETURN v_files;
        END resolve_files;
```

---

## 6. So sánh nhanh

| Cấu trúc | Khi dùng                |
| -------- | ----------------------- |
| FOR      | Khi biết số lần lặp     |
| WHILE    | Khi chưa biết trước     |
| IF       | Rẽ nhánh đơn giản       |
| CASE     | Nhiều điều kiện rõ ràng |

---

## 7. Lưu ý quan trọng

* Không có `SWITCH` trong Oracle → dùng `CASE`
* Với collection có thể bị thiếu index → dùng `WHILE + NEXT`
* Luôn kiểm tra `EXISTS(i)` nếu dùng index thủ công

---