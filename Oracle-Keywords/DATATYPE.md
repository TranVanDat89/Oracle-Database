# Các kiểu dữ liệu trong Oracle

## 1. Giới thiệu

Oracle cung cấp nhiều kiểu dữ liệu khác nhau để lưu trữ và xử lý dữ liệu.
Các kiểu này được chia thành các nhóm chính:

* Kiểu số (Numeric)
* Kiểu ký tự (Character)
* Kiểu ngày giờ (Date/Time)
* Kiểu nhị phân (Binary)
* Kiểu lớn (LOB)
* Kiểu đặc biệt khác

---

## 2. Kiểu dữ liệu số (Numeric)

| Kiểu        | Mô tả                                          |
| ----------- | ---------------------------------------------- |
| NUMBER(p,s) | Số với độ chính xác p và số chữ số thập phân s |
| INTEGER     | Số nguyên (alias của NUMBER)                   |
| FLOAT       | Số thực dấu chấm động                          |

### Ví dụ

```sql
CREATE TABLE demo_numeric (
    id NUMBER,
    price NUMBER(10,2),
    quantity INTEGER
);
```

---

## 3. Kiểu ký tự (Character)

| Kiểu         | Mô tả                      |
| ------------ | -------------------------- |
| CHAR(n)      | Chuỗi cố định độ dài n     |
| VARCHAR2(n)  | Chuỗi biến độ dài tối đa n |
| NCHAR(n)     | Chuỗi Unicode cố định      |
| NVARCHAR2(n) | Chuỗi Unicode biến         |

### Ví dụ

```sql
CREATE TABLE demo_char (
    name VARCHAR2(100),
    code CHAR(10)
);
```

---

## 4. Kiểu ngày giờ (Date/Time)

| Kiểu                           | Mô tả                           |
| ------------------------------ | ------------------------------- |
| DATE                           | Ngày và giờ (đến giây)          |
| TIMESTAMP                      | Ngày giờ có phần thập phân giây |
| TIMESTAMP WITH TIME ZONE       | Có múi giờ                      |
| TIMESTAMP WITH LOCAL TIME ZONE | Theo múi giờ session            |

### Ví dụ

```sql
CREATE TABLE demo_date (
    created_at DATE,
    updated_at TIMESTAMP
);
```

---

## 5. Kiểu nhị phân (Binary)

| Kiểu     | Mô tả                              |
| -------- | ---------------------------------- |
| RAW(n)   | Dữ liệu nhị phân                   |
| LONG RAW | Dữ liệu nhị phân lớn (đã lỗi thời) |

---

## 6. Kiểu dữ liệu lớn (LOB)

| Kiểu  | Mô tả                   |
| ----- | ----------------------- |
| CLOB  | Văn bản lớn             |
| NCLOB | Văn bản Unicode lớn     |
| BLOB  | Dữ liệu nhị phân lớn    |
| BFILE | File bên ngoài database |

### Ví dụ

```sql
CREATE TABLE demo_lob (
    content CLOB,
    image BLOB
);
```

---

## 7. Kiểu Boolean

* Oracle SQL **không hỗ trợ BOOLEAN trực tiếp**
* Chỉ dùng trong PL/SQL

```sql
DECLARE
    is_valid BOOLEAN := TRUE;
BEGIN
    IF is_valid THEN
        DBMS_OUTPUT.PUT_LINE('OK');
    END IF;
END;
```

---

## 8. Kiểu đặc biệt

| Kiểu                      | Mô tả                   |
| ------------------------- | ----------------------- |
| ROWID                     | Địa chỉ dòng trong bảng |
| UROWID                    | ROWID mở rộng           |
| XMLTYPE                   | Lưu dữ liệu XML         |
| JSON (dạng VARCHAR2/CLOB) | Lưu JSON                |

---

## 9. Kiểu do người dùng định nghĩa (User-Defined Types)

Oracle cho phép tạo kiểu riêng:

* Object Type
* Collection (VARRAY, Nested Table)

```sql
CREATE TYPE person_type AS OBJECT (
    id NUMBER,
    name VARCHAR2(100)
);
```

---

## 10. So sánh nhanh

| Nhóm      | Ví dụ           |
| --------- | --------------- |
| Numeric   | NUMBER, FLOAT   |
| Character | VARCHAR2, CHAR  |
| Date/Time | DATE, TIMESTAMP |
| Binary    | RAW             |
| LOB       | CLOB, BLOB      |
| Custom    | TYPE            |

---

## 11. Lưu ý quan trọng

* Nên dùng `VARCHAR2` thay vì `VARCHAR`
* Tránh dùng `LONG` và `LONG RAW` (đã lỗi thời)
* Chọn kiểu dữ liệu phù hợp giúp tối ưu hiệu năng
* LOB dùng cho dữ liệu lớn (>4000 bytes)

