# Oracle TYPE – Từ khóa và cách sử dụng
## 1. Giới thiệu

Trong Oracle, `TYPE` được sử dụng để định nghĩa **kiểu dữ liệu do người dùng tạo (User-Defined Types)**.
Nó cho phép bạn tạo các cấu trúc dữ liệu phức tạp như:

* Object (giống class)
* Collection (array, table)
* Record (trong PL/SQL)

---

## 2. Các loại TYPE trong Oracle

### 2.1 Object Type

Dùng để tạo kiểu dữ liệu dạng đối tượng (giống OOP)

```sql
CREATE OR REPLACE TYPE person_type AS OBJECT (
    id NUMBER,
    name VARCHAR2(100),
    age NUMBER
);
```

👉 Sử dụng:

```sql
DECLARE
    p person_type;
BEGIN
    p := person_type(1, 'An', 20);
    DBMS_OUTPUT.PUT_LINE(p.name);
END;
```

---

### 2.2 Collection Type

#### a. VARRAY (Mảng có giới hạn)

```sql
CREATE OR REPLACE TYPE phone_list AS VARRAY(5) OF VARCHAR2(20);
```

#### b. Nested Table (Bảng lồng)

```sql
CREATE OR REPLACE TYPE number_table AS TABLE OF NUMBER;
```

👉 Sử dụng:

```sql
DECLARE
    nums number_table := number_table(1,2,3);
BEGIN
    DBMS_OUTPUT.PUT_LINE(nums(1));
END;
```

---

### 2.3 RECORD (trong PL/SQL)

Không dùng `CREATE TYPE`, mà dùng trong block

```sql
DECLARE
    TYPE emp_record IS RECORD (
        id NUMBER,
        name VARCHAR2(100)
    );
    emp emp_record;
BEGIN
    emp.id := 1;
    emp.name := 'Bình';
END;
```

---

## 3. TYPE trong PL/SQL (Khai báo biến)

Bạn cũng có thể dùng `TYPE` để định nghĩa kiểu:

```sql
DECLARE
    TYPE number_array IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    nums number_array;
BEGIN
    nums(1) := 100;
END;
```

---

## 4. Ưu điểm của TYPE

* Tái sử dụng kiểu dữ liệu
* Tổ chức dữ liệu rõ ràng
* Hỗ trợ lập trình hướng đối tượng trong Oracle
* Dễ bảo trì và mở rộng

---

## 5. Khi nào nên dùng TYPE?

* Khi cần lưu dữ liệu phức tạp
* Khi làm việc với API hoặc procedure lớn
* Khi cần truyền dữ liệu dạng object/collection

---

## 6. Tổng kết

| Loại TYPE    | Mô tả                      |
| ------------ | -------------------------- |
| Object Type  | Kiểu đối tượng             |
| VARRAY       | Mảng có kích thước cố định |
| Nested Table | Bảng linh hoạt             |
| Record       | Cấu trúc trong PL/SQL      |

---

## 7. Lưu ý

* TYPE tạo bằng `CREATE TYPE` sẽ tồn tại trong database
* RECORD chỉ dùng trong PL/SQL block

---

## 8. Áp dụng thực tế
```sql
    CREATE OR REPLACE TYPE t_transaction_child AS OBJECT (
        log_id           VARCHAR2(50),
        wf_process_id    VARCHAR2(50),
        apply_name       VARCHAR2(50),
        title            VARCHAR2(200),
        status           VARCHAR2(50),
        start_time       TIMESTAMP,
        end_time         TIMESTAMP,
        remarks          VARCHAR2(4000),
        assignee         VARCHAR2(4000),
        approve_channel  VARCHAR2(50),
        tran_sn          VARCHAR2(50),
        request_id       VARCHAR2(50),
        user_name        VARCHAR2(100),
        full_name        VARCHAR2(200),
        attachment_ids   VARCHAR2(4000),
        is_active        VARCHAR2(1),   
        is_pending       VARCHAR2(1)    
    );

    CREATE OR REPLACE TYPE t_transaction_child_tab 
    AS TABLE OF t_transaction_child;

    CREATE OR REPLACE TYPE t_transaction_file AS OBJECT (
        attachment_id    VARCHAR2(50),
        file_name        VARCHAR2(500)
    );

    CREATE OR REPLACE TYPE t_transaction_file_tab 
    AS TABLE OF t_transaction_file;

    CREATE OR REPLACE TYPE t_transaction_history AS OBJECT (
        log_id           VARCHAR2(50),
        wf_process_id    VARCHAR2(50),
        apply_name       VARCHAR2(50),
        title            VARCHAR2(200),
        status           VARCHAR2(50),
        start_time       TIMESTAMP,
        end_time         TIMESTAMP,
        remarks          VARCHAR2(4000),
        assignee         VARCHAR2(4000),
        approve_channel  VARCHAR2(50),
        tran_sn          VARCHAR2(50),
        request_id       VARCHAR2(50),
        user_name        VARCHAR2(100),
        full_name        VARCHAR2(200),
        attachment_ids   VARCHAR2(4000),
        is_active        VARCHAR2(1),
        is_pending       VARCHAR2(1),
        files            t_transaction_file_tab,
        trans            t_transaction_child_tab  
    );

    --Tạo Arrays
    CREATE OR REPLACE TYPE t_transaction_history_tab 
    AS TABLE OF t_transaction_history;

    -- Tạo Type Local trong PL/SQl
    FUNCTION build_process(
        p_request_id IN VARCHAR2,
        p_corp_id    IN NUMBER,
        p_language   IN VARCHAR2,
        p_service_type IN VARCHAR2
    ) RETURN t_transaction_history_tab PIPELINED IS

        -- Tạo Object trong PL/SQL
        TYPE t_log_row IS RECORD (
            log_id          WF_LOG_INFO.LOG_ID%TYPE,
            wf_process_id   WF_LOG_INFO.WF_PROCESS_ID%TYPE,
            apply_name      WF_LOG_INFO.APPLY_NAME%TYPE,
            status          WF_LOG_INFO.STATUS%TYPE,
            start_time      WF_LOG_INFO.START_TIME%TYPE,
            end_time        WF_LOG_INFO.END_TIME%TYPE,
            remarks         WF_LOG_INFO.REMARKS%TYPE,
            assignee        WF_LOG_INFO.ASSIGNEE%TYPE,
            approve_channel WF_LOG_INFO.APPROVE_CHANNEL%TYPE,
            tran_sn         WF_LOG_INFO.TRAN_SN%TYPE,
            request_id      WF_LOG_INFO.REQUEST_ID%TYPE,
            user_name       BB_USER_INFO.USER_NAME%TYPE,
            full_name       BB_USER_INFO.FULL_NAME%TYPE
        );
        -- Tạo Arrays
        TYPE t_log_tab IS TABLE OF t_log_row INDEX BY PLS_INTEGER;
        v_logs t_log_tab;
        -- Tạo Arrays
        TYPE t_level_names IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;

        v_pro        t_transaction_history;
        v_tran_list  t_transaction_child_tab;

    BEGIN
    ...
    END;
```