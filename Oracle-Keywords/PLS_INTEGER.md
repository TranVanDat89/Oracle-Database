# PLS_INTEGER trong Oracle

## 1. Giới thiệu

`PLS_INTEGER` là kiểu dữ liệu số nguyên trong **PL/SQL** của Oracle, được thiết kế để xử lý nhanh hơn so với kiểu `NUMBER`.

* Chỉ dùng trong **PL/SQL**
* Không sử dụng trực tiếp trong SQL
* Tối ưu cho các phép toán số học

---

## 2. Đặc điểm

* Là số nguyên có dấu
* Lưu trữ dưới dạng **binary integer**
* Hiệu năng cao hơn `NUMBER`

### Phạm vi giá trị

```
-2,147,483,648 → 2,147,483,647
```

---

## 3. So sánh với NUMBER

| Tiêu chí       | PLS_INTEGER | NUMBER       |
| -------------- | ----------- | ------------ |
| Kiểu dữ liệu   | Số nguyên   | Số tổng quát |
| Tốc độ xử lý   | Nhanh hơn   | Chậm hơn     |
| Phạm vi        | Giới hạn    | Rộng hơn     |
| Dùng trong SQL | ❌ Không     | ✅ Có         |

---

## 4. Cú pháp sử dụng

### Khai báo biến

```sql id="hj38q2"
DECLARE
    x PLS_INTEGER := 10;
BEGIN
    DBMS_OUTPUT.PUT_LINE(x);
END;
```

---

### Dùng trong vòng lặp

```sql id="k2n9zx"
DECLARE
    i PLS_INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        DBMS_OUTPUT.PUT_LINE(i);
    END LOOP;
END;
```

---

### Dùng với Associative Array

```sql id="z7m4qa"
DECLARE
    TYPE num_array IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    arr num_array;
BEGIN
    arr(1) := 100;
    arr(2) := 200;
    DBMS_OUTPUT.PUT_LINE(arr(1));
END;
```

---

## 5. Ưu điểm

* Hiệu năng cao 🚀
* Tối ưu cho phép toán số học
* Phù hợp cho xử lý logic nội bộ

---

## 6. Hạn chế

* Không dùng được trong SQL (ví dụ: `CREATE TABLE`)
* Phạm vi giá trị nhỏ hơn `NUMBER`

---

## 7. Khi nào nên dùng?

Nên sử dụng `PLS_INTEGER` khi:

* Viết code PL/SQL thuần
* Cần xử lý vòng lặp, biến đếm
* Tối ưu hiệu năng

---

## 8. Lưu ý

* Thường dùng trong:

  * Procedure
  * Function
  * Package
  * Block `DECLARE`

---

## 9. Kết luận

`PLS_INTEGER` là lựa chọn tối ưu khi làm việc với số nguyên trong PL/SQL nhờ:

* Tốc độ nhanh
* Tài nguyên nhẹ
* Dễ sử dụng

---
