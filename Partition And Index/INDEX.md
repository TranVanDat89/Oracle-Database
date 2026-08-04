# Khái niệm

Index là một cấu trúc dữ liệu giúp database tìm kiếm nhanh hơn mà không cần quét toàn bộ bảng.

Đánh index trên những cột có selectivity cao, xuất hiện trong JOIN và WHERE.
Đánh index trên cột có cardinality cao.

# B-Tree Index

* Cấu trúc cây cân bằng (balanced tree), mỗi leaf node lưu giá trị cột + ROWID.
* Phù hợp cho: =, <, >, BETWEEN, LIKE 'prefix%', ORDER BY. Không phù hợp cho: cột cardinality quá thấp (ít giá trị phân biệt như boolean Y/N), LIKE '%abc%'.
* B-Tree Index bao gồm: Index key: chứa các trường dữ liệu làm key khi tạo index. RowID: là ROWID tương ứng với dòng dữ liệu chứa index key. (Với Oracle là ROWID, các Database khác chỉ khác nhau về tên gọi)
Cách B-Tree hoạt động:
* Khi select: giả sử, ta cần select 1 dòng dữ liệu mà trong điều kiện lọc (where) có sử dụng các trường trong index thì Oracle server sẽ load index đó lên và tìm đến dòng chứa index key đó, lấy ra rowid tương ứng. Sau đó từ thông tin rowid này oracle server sẽ đọc chính xác block chứa dòng dữ liệu cần lấy ra lên buffer cache và trả kết quả về cho người dùng.
* Khi insert: thêm 1 dòng mới vào table thì oracle cũng sẽ insert thêm 1 dòng vào các indexes của table đó (bao gồm index key và rowid). Các giá trị sẽ được sắp xếp trên cây index sẽ mở rộng dần sang bên phải hoặc xuống bên dưới tới các lớp lá (leaf).
* Khi delete: Oracle sẽ không xóa, mà chỉ đánh dấu KHÔNG CÒN SỬ DỤNG (Unusable) và nó vẫn tồn tại trong index đó. Cứ như vậy, qua thời gian nó sẽ ngày càng có nhiều dòng (hay còn gọi là lá - leaf), không dùng đến (dead leaf).
* Khi update: TH update key index => Đánh dấu dòng cũ trên index là không còn sử dụng (dead leaf) => Tạo thêm 1 dòng mới với index key mới và rowid tương ứng.

=> Khi index mở rộng, phình to cần rebuild lại **REBUILD** lại index.

# Bitmap Index

* Bitmap Index lưu trữ các giá trị cột dưới dạng các bitmap (bản đồ bit), trong đó mỗi bit đại diện cho trạng thái của một giá trị cụ thể trong cột.
* Bitmap index được tối ưu hóa cho các truy vấn sử dụng các giá trị có độ chọn lọc thấp (low cardinality), nghĩa là số lượng giá trị duy nhất trong cột nhỏ so với tổng số bản ghi. 
* Bitmap Index rất hiệu quả trong hệ thống OLAP (Data warehouse) nhưng không phù hợp trong hệ thống OLTP. Vì bitmap index lock theo range/blocks. Khi dùng trong các thao tác insert/update nhiều có thể gây treo hệ thống.

# Composite Index

*  Kết hợp nhiều cột trong một index. Cần đặt cột có tính chọn lọc cao nhất (hoặc cột bắt buộc có trong mệnh đề WHERE) lên làm cột đầu tiên (leading column)
* Quy tắc left most, ưu tiên bên trái.
Ví dụ:
```sql
CREATE INDEX idx_composite ON bb_transfer_history (status, service_type, create_time);
```
Oracle không lưu 3 cột riêng biệt trong index — mà encode từng cột thành dạng byte nhị phân, rồi nối (concatenate) các chuỗi byte đó lại theo đúng thứ tự khai báo thành 1 khóa (composite key) duy nhất: composite_key = encode(STATUS) || encode(SERVICE_TYPE) || encode(CREATE_TIME).
# Function-Based Index

* Index trên kết quả của 1 hàm/biểu thức áp lên cột, không phải giá trị gốc.
```sql
CREATE INDEX idx_upper_name ON customer (UPPER(cust_name));
```
Cách lưu trữ: Oracle tính toán trước (pre-compute) giá trị UPPER(cust_name) cho từng dòng tại thời điểm insert/update, rồi lưu kết quả đã tính đó vào leaf block của B-tree — hoàn toàn giống index thường, chỉ khác "giá trị" lưu trong index là output của hàm, không phải giá trị cột gốc.

# Tìm kiếm (Full-text/Partial match)

## Oracle Text (CTXSYS.CONTEXT)
* Khác hoàn toàn với B-tree, Oracle Text dùng Inverted Index — cấu trúc giống mục lục sau sách theo từ khóa (không phải theo trang): Oracle tách chuỗi văn bản thành từng từ (tokenize) — ví dụ "Chuyen tien thanh toan hop dong" → tách thành ["chuyen", "tien", "thanh", "toan", "hop", "dong"]. Với mỗi từ, Oracle xây 1 danh sách các ROWID chứa từ đó (gọi là posting list):
```
"chuyen" → [ROWID_1, ROWID_5, ROWID_9, ...]
"tien"   → [ROWID_1, ROWID_3, ROWID_5, ...]
"hop"    → [ROWID_1, ROWID_7, ...]
```
Khi search CONTAINS(remark, 'chuyen tien'), Oracle tra thẳng 2 danh sách của "chuyen" và "tien", rồi giao (intersect) 2 danh sách ROWID lại → ra ngay các dòng chứa cả 2 từ, không cần quét bảng.

* Index không đồng bộ ngay lập tức: mặc định Oracle Text index cần SYNC định kỳ (không tự cập nhật ngay khi INSERT như B-tree).
* Cần optimize định kì.