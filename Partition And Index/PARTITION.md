# Khái niệm

* Partition là quá trình phân chia table thành các phân vùng nhỏ theo một quy tắc nào đó được gọi là partition function. 
* Khi dữ kiệu lớn hàng triệu dòng, và có dấu hiệu tăng trưởng định kỳ như các bảng log thì nên chia partition.

# Range partition

* Range Partition: Chia phân vùng theo khoảng giá trị (phổ biến nhất cho ngày tháng). Rất hiệu quả khi dữ liệu được truy xuất theo chuỗi thời gian (ví dụ: chia theo tháng: PARTITION BY RANGE (created_date)).

# List partition

*  Phân vùng dựa trên danh sách các giá trị rời rạc, không liên tục (ví dụ: PARTITION BY LIST (status) cho các trạng thái PENDING, DONE)