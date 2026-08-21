# ACID và Isolation Level trong Oracle

> Ghi chú kỹ thuật — tổng hợp từ buổi tìm hiểu về lost update, write skew, và cách Oracle xử lý concurrency trong PL/SQL.

---

## Phần 1: ACID là gì

ACID là 4 tính chất mà một transaction trong database phải đảm bảo. Isolation (chữ I) chỉ là **một phần** của ACID — không phải hai chủ đề tách biệt.

### Atomicity (Tính nguyên tử)

**Câu hỏi:** Transaction có làm hết hoặc không làm gì không?

Một transaction là khối không thể chia nhỏ. Ví dụ chuyển tiền:

```sql
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

Nếu câu thứ hai lỗi giữa chừng, câu thứ nhất **cũng không được tính** — không có chuyện tiền biến mất khỏi tài khoản 1 mà không vào tài khoản 2.

**Cơ chế Oracle:** Undo segment. Khi transaction rollback, Oracle dùng undo để khôi phục lại trạng thái trước đó.

### Consistency (Tính nhất quán)

**Câu hỏi:** Dữ liệu có luôn hợp lệ theo constraint/invariant không?

Transaction phải đưa DB từ một trạng thái hợp lệ sang một trạng thái hợp lệ khác — không vi phạm NOT NULL, CHECK, FOREIGN KEY, unique constraint, hay bất kỳ invariant nghiệp vụ nào.

Đây là chữ dễ hiểu nhầm nhất, vì bản thân nó **không phải một cơ chế riêng** — nó là **hệ quả** của Atomicity + Isolation + Durability, cộng với constraint bạn khai báo. Ví dụ invariant "luôn còn ít nhất 1 bác sĩ trực" không thể khai báo thành CHECK constraint (vì phụ thuộc COUNT nhiều dòng), nên Consistency của nó phụ thuộc hoàn toàn vào việc code Isolation đúng hay không.

> **Write skew chính là một lỗi Consistency, nguyên nhân gốc nằm ở Isolation.**

### Isolation (Tính cô lập)

**Câu hỏi:** Transaction chạy song song có "thấy" nhau không?

Các transaction chạy song song phải cho kết quả như thể chúng chạy tuần tự, lần lượt từng cái một. Mức độ "như thể" đó do Isolation Level quyết định — xem chi tiết ở Phần 2.

**Cơ chế Oracle:** SCN (System Change Number) + undo segment để dựng lại snapshot.

### Durability (Tính bền vững)

**Câu hỏi:** Đã commit thì có chắc chắn còn không?

Sau khi `COMMIT` trả về thành công, dữ liệu phải tồn tại vĩnh viễn, kể cả khi server sập điện ngay sau đó.

**Cơ chế Oracle:** Redo log (write-ahead logging) — mọi thay đổi ghi vào redo log **trước khi** báo commit thành công. Nếu crash, lúc khởi động lại Oracle replay redo log để khôi phục các thay đổi đã commit.

> **Phân biệt undo vs redo:** Atomicity dùng **undo** (huỷ cái chưa xong). Durability dùng **redo** (đảm bảo cái đã xong không mất). Hai log riêng biệt, hai mục đích ngược nhau.

### Bảng tóm tắt

| Chữ | Câu hỏi | Cơ chế Oracle |
|---|---|---|
| **A**tomicity | Làm hết hay không làm gì? | Undo segment + ROLLBACK |
| **C**onsistency | Dữ liệu luôn hợp lệ? | Constraint + hệ quả của A, I, D |
| **I**solation | Transaction song song có thấy nhau? | SCN + Read Committed/Serializable |
| **D**urability | Đã commit có chắc còn? | Redo log |

---

## Phần 2: Các loại Anomaly (theo ANSI SQL 1992)

Khi nhiều transaction chạy song song và đụng cùng dữ liệu, có 3 loại sai lệch cổ điển:

### Dirty read
Transaction A sửa một dòng nhưng chưa commit. Transaction B đọc ngay giá trị chưa commit đó. A rollback → B vừa đọc dữ liệu chưa từng thật sự tồn tại.

### Non-repeatable read
Trong cùng một transaction, B đọc một dòng thấy 100. Lát sau đọc lại chính dòng đó, thấy 200 — vì transaction khác đã commit thay đổi ở giữa.

### Phantom read
Giống non-repeatable nhưng ở cấp tập hợp dòng. B chạy "đếm số user tuổi > 30" ra 10. Chạy lại ra 11 — vì có dòng mới vừa được insert thoả điều kiện.

### Hai anomaly bị chuẩn ANSI bỏ sót (từ bài phê bình 1995 *"A Critique of ANSI SQL Isolation Levels"*)

**Lost update:** Hai transaction cùng đọc số dư 500k, cùng tính toán, cùng ghi đè — update của thằng ghi trước bị thằng ghi sau đè mất.

**Write skew:** Ví dụ kinh điển — bệnh viện quy định luôn phải còn ít nhất 1 bác sĩ trực. An và Bình đều đang trực, cả hai cùng xin nghỉ ở hai transaction riêng, cả hai cùng đọc thấy "đang có 2 người" → OK, cả hai cùng commit. Kết quả: không còn ai trực.

- Khác với lost update: hai transaction ghi vào **hai dòng khác nhau**, không có xung đột trực tiếp nào để database phát hiện.
- Đây là điều kiện ẩn (invariant) mà cả hai transaction cùng dựa vào nhưng không đứa nào thấy đứa kia đang phá vỡ nó.

---

## Phần 3: Isolation Level trong Oracle

### Oracle chỉ có 2 mức thật sự dùng

| Mức | Ghi chú |
|---|---|
| **READ COMMITTED** | Mặc định |
| **SERIALIZABLE** | Phải tự set |
| ~~READ UNCOMMITTED~~ | Không tồn tại — Oracle không bao giờ cho dirty read |
| ~~REPEATABLE READ~~ | Không có tên riêng như PostgreSQL/MySQL |
| READ ONLY | Chế độ phụ — transaction chỉ đọc, không nằm trong 4 mức anomaly |

### Cơ chế nền: Undo segment + SCN

Khi UPDATE một dòng, Oracle:
1. Ghi giá trị **mới** vào bảng thật.
2. Ghi giá trị **cũ** vào **undo segment**.
3. Gắn **SCN** (System Change Number) — con số thời điểm tăng dần mỗi khi có thay đổi trong DB.

Khi một transaction cần đọc, Oracle so SCN của transaction đó với SCN của dòng dữ liệu. Nếu dòng đã bị sửa **sau** SCN của transaction, Oracle lấy dữ liệu cũ từ undo để "dựng lại" đúng cái nhìn tại thời điểm transaction bắt đầu.

> **Lỗi liên quan:** `ORA-01555: snapshot too old` — xảy ra khi undo bị ghi đè mất trước khi transaction kịp dùng để dựng lại snapshot.

### READ COMMITTED — snapshot theo từng câu lệnh (per-statement)

Mỗi câu lệnh (SELECT/UPDATE...) trong transaction lấy SCN **riêng**, tại đúng thời điểm câu đó bắt đầu chạy.

- SELECT lần 1 lúc 10:00 → thấy 500k
- Transaction khác commit lúc 10:01, đổi thành 300k
- SELECT lần 2 lúc 10:05 (cùng transaction) → thấy 300k

→ **Non-repeatable read vẫn xảy ra** ở mức này.

### SERIALIZABLE — snapshot cố định cho cả transaction (per-transaction)

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

Toàn bộ transaction dùng **một SCN duy nhất**, chốt từ câu lệnh đầu tiên. Mọi câu SELECT sau đó đều nhìn thấy đúng một "bức ảnh" cố định, bất kể người khác commit gì.

**Chặn được:**
- Non-repeatable read — hết, vì dùng chung 1 snapshot.
- Lost update — nếu cố UPDATE một dòng đã bị transaction khác commit thay đổi sau khi chụp snapshot, Oracle báo lỗi ngay:
  ```
  ORA-08177: can't serialize access for this transaction
  ```
  Ứng dụng phải tự bắt lỗi này và retry — Oracle không tự động retry.

**KHÔNG chặn được: Write skew**

> ⚠️ Đây là điểm quan trọng nhất. `ORA-08177` chỉ nổ ra khi hai transaction đụng **cùng một dòng**. Ca bác sĩ trực — An và Bình sửa hai dòng khác nhau — không có va chạm trực tiếp nào để Oracle phát hiện. Cả hai commit thành công, invariant vẫn bị vỡ.

### ⚠️ Lưu ý về cái tên "Serializable"

Tên gọi "Serializable" của Oracle là **marketing name** — bản chất bên dưới chỉ là **snapshot isolation**, không phải serializable thật theo lý thuyết (không có cơ chế như SSI của PostgreSQL để phát hiện write skew). Đừng tin một cái tên isolation level chỉ vì nó nghe an toàn — luôn hỏi "database này thực sự làm gì bên dưới cái tên đó".

### Bảng tóm tắt Isolation Level Oracle

| Mức | Dirty read | Non-repeatable read | Phantom read | Lost update | Write skew |
|---|---|---|---|---|---|
| READ COMMITTED | ❌ (không có) | ✅ có thể xảy ra | ✅ có thể xảy ra | ✅ có thể xảy ra | ✅ có thể xảy ra |
| SERIALIZABLE | ❌ (không có) | ❌ chặn được | ❌ chặn được | ❌ chặn được (báo lỗi ORA-08177) | ✅ **vẫn xảy ra** |

---

## Phần 4: Xử lý thực chiến trong PL/SQL

Nguyên tắc chung: **xử lý tại đúng câu lệnh trước, đừng vội nâng isolation level cho cả transaction** — nâng level là quyết định có bán kính ảnh hưởng rộng (retry loop, tăng tỉ lệ abort dưới tải cao).

### Với Lost Update

**Cách 1 — Conditional update (gọn nhất):**

```sql
UPDATE accounts 
SET balance = balance - :amount 
WHERE id = :acc_id AND balance >= :amount;
-- kiểm tra SQL%ROWCOUNT, = 0 nghĩa là không đủ tiền hoặc có tranh chấp
```

Oracle tự khoá đúng dòng đó trong lúc chạy — không cần đụng gì tới isolation level.

**Cách 2 — Pessimistic lock (khi logic phức tạp, không dồn vào 1 câu được):**

```sql
SELECT balance INTO v_balance FROM accounts WHERE id = :acc_id FOR UPDATE;
-- dòng bị khoá, transaction khác phải chờ tới khi commit/rollback
```

Hợp với dòng "nóng" — tranh chấp cao (tồn kho flash sale).

**Cách 3 — Optimistic lock (khi tranh chấp ít):**

Thêm cột `version`, `UPDATE ... WHERE id = ? AND version = ?`. Nếu affected rows = 0 → có đứa sửa trước, retry.

### Với Write Skew

Vì Oracle Serializable không cứu được, cách duy nhất là **materialize invariant** — ép các transaction phải đụng chung một dòng cụ thể thay vì đọc một điều kiện tổng hợp (COUNT/SUM/EXISTS) rồi mỗi đứa ghi dòng riêng.

```sql
-- Khoá dòng đại diện cho ràng buộc "ca trực" TRƯỚC khi COUNT
SELECT ca_truc_id FROM ca_truc WHERE id = :shift_id FOR UPDATE;
-- Giờ mới COUNT số người đang trực, kiểm tra >= 1, rồi mới update trạng thái nghỉ
```

`FOR UPDATE` bắt transaction thứ hai phải đợi transaction thứ nhất commit xong mới được đọc tiếp — lúc đó COUNT sẽ ra số đúng.

---

## Kết luận

- Isolation Level không phải một dòng config chỉnh một lần rồi quên — nó là hợp đồng giữa bạn và database về việc "database giấu giúp bạn những gì, và bạn phải tự lo những gì".
- Câu hỏi đáng giá không phải "set isolation level nào", mà là: **"Invariant nào bắt buộc luôn đúng trong nghiệp vụ này, và nó dựa trên dữ liệu nào mà tôi chỉ đọc chứ không ghi?"**
- Ở Oracle cụ thể: SERIALIZABLE chỉ mạnh ngang mức "khoá được khi đụng cùng 1 dòng". Khi ràng buộc nghiệp vụ nằm ở tổng hợp nhiều dòng, phải tự tay biến nó thành một dòng cụ thể để lock — đừng trông chờ isolation level tự lo giúp.