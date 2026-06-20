# Phân tích yêu cầu — vai Consumer

- Cặp đàm phán: Pair 03
- Product: Smart Campus Operations Platform
- Consumer service: Core Business Service
- Provider service: Access Gate Service
- Người viết: Nguyễn Minh Sơn (Consumer Representative)
- Ngày: 2026-06-20

---

## 1. Resource Consumer cần nhận/gửi

| Resource | Consumer dùng để làm gì? | Field bắt buộc với Consumer | Field có thể tùy chọn |
|---|---|---|---|
| `Card` | Phân tích danh tính và phân quyền chủ sở hữu thẻ (Student/Staff/Guest) để đối soát với hệ thống nhân sự/đào tạo | `cardId`, `cardType`, `status`, `expiresAt` | `studentId`, `employeeId`, `guestName`, `visitorId` (tùy theo `cardType`) |
| `AccessLog` | Ghi nhận nhật ký di chuyển của cư dân trong campus để tính toán mật độ, kiểm tra gian lận hoặc xuất báo cáo | `logId`, `cardId`, `gateId`, `direction`, `timestamp`, `status` | `reasonCode`, `operatorNote` |
| `GateAlarmEvent` | Lắng nghe qua webhook để kích hoạt luồng thông báo khẩn cấp khi có đột nhập trái phép hoặc kẹt cửa | `alarmId`, `gateId`, `alarmType`, `timestamp`, `severity` | |

---

## 2. API Consumer cần gọi

| Method | Path | Lúc nào gọi? | Kỳ vọng response |
|---|---|---|---|
| GET | `/access/logs` | Đồng bộ dữ liệu định kỳ mỗi tối hoặc khi chạy tác vụ tổng hợp dữ liệu hiện diện | HTTP 200 kèm danh sách logs đã được phân trang bằng cursor |
| GET | `/access/logs/{logId}` | Xem thông tin chi tiết một trường hợp nghi ngờ vi phạm hoặc kiểm tra chéo | HTTP 200 kèm đầy đủ thông tin log chi tiết |
| GET | `/gates/{gateId}/status` | Kiểm tra trạng thái của cổng trước khi gửi lệnh điều khiển khẩn cấp | HTTP 200 chứa trạng thái hiện tại (OPEN/CLOSED/FAULT) |
| GET | `/cards/{cardId}` | Truy vấn thông tin của thẻ vật lý khi nhân sự quẹt thẻ tại quầy hỗ trợ | HTTP 200 kèm thông tin chi tiết của thẻ (polymorphic) |

---

## 3. Error case Consumer cần xử lý

Tối thiểu 5 case.

| Status | Consumer hiểu là gì? | Consumer sẽ xử lý thế nào? |
|---:|---|---|
| 400 | Payload hoặc query parameters gửi đi sai định dạng (ví dụ: regex `cardId` bị sai) | Log chi tiết lỗi validation, dừng gửi request bị lỗi để tránh gây nhiễu, báo cáo lỗi hệ thống nội bộ. |
| 401 | Credential của Core Business không hợp lệ (hết hạn Bearer Token) | Tự động chạy tác vụ refresh token lấy JWT mới và thực hiện gọi lại API (retry). |
| 403 | Core Business không đủ quyền truy cập tài nguyên (ví dụ: phân hệ logs yêu cầu scope cao hơn) | Ghi nhận lỗi bảo mật, thông báo cho quản trị viên cấu hình lại IAM. |
| 404 | Thẻ vật lý hoặc bản ghi nhật ký không tồn tại trên phân hệ Gate | Hiển thị thông báo "Thẻ chưa đăng ký hệ thống" hoặc "Bản ghi không tồn tại" trên UI. |
| 422 | Thẻ quẹt đã bị khóa (Suspended) do vi phạm quy định campus | Kích hoạt kịch bản nghiệp vụ: từ chối xử lý, ghi nhận cảnh báo nguy cơ và gửi thông báo đẩy đến nhân viên bảo vệ gần nhất. |

---

## 4. Giả định bổ sung

- **Giả định 1**: Định dạng của RFID cardId thống nhất là `RFID-YYYY-NNN` (ví dụ: `RFID-2026-001`).
- **Giả định 2**: Webhook `gateAlarmTriggered` sẽ được Access Gate kích hoạt gửi đồng bộ ngay lập tức (dưới 1 giây) kể từ khi sự cố xảy ra.
- **Giả định 3**: Các cuộc gọi API được bảo mật hoàn toàn bằng Bearer Token sử dụng chuẩn JWT chứa thông tin định danh Core Business.

---

## 5. Câu hỏi cho Provider

1. Làm sao để phân biệt giữa Guest Card vãng lai ngắn hạn và Guest Card dài hạn trong schema?
2. Có thể hỗ trợ API lọc logs theo khoảng thời gian (`fromTime` / `toTime`) kèm với phân trang bằng cursor không?
3. Khi xảy ra sự cố hỏa hoạn, Access Gate có tự động override mở toàn bộ cổng hay cần lệnh điều khiển từ Core Business qua một API điều khiển (POST/PUT)?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Cổng gặp lỗi vật lý liên tục gửi Webhook | Gây nghẽn Notification service của Core Business | Áp dụng rate limiting ở phía Consumer hoặc Provider đối với các sự kiện báo động liên tục từ cùng một `gateId`. |
| Payload schema của thẻ bị thay đổi (thêm subtype mới) | Consumer không parse được JSON dẫn đến crash | Sử dụng cơ chế deserialize linh hoạt, bỏ qua các field lạ nếu không trùng khớp discriminator, và cập nhật thư viện parser. |
| Xung đột múi giờ khi đối soát | Báo cáo hiện diện hiển thị sai lệch ngày | Thống nhất chuẩn hóa toàn bộ thời gian về ISO 8601 UTC trên cả hai service. |
