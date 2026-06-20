# Phân tích yêu cầu — vai Provider

- Cặp đàm phán: Pair 03
- Product: Smart Campus Operations Platform
- Provider service: Access Gate Service
- Consumer service: Core Business Service
- Người viết: Nguyễn Minh Sơn (Provider Representative)
- Ngày: 2026-06-20

---

## 1. Resource chính

| Resource | Mô tả | Thuộc tính bắt buộc | Thuộc tính tùy chọn |
|---|---|---|---|
| `GateStatus` | Trạng thái vật lý và điều khiển từ xa của cổng kiểm soát | `gateId`, `status`, `isLocked`, `lastMaintenance` | |
| `Card` | Thông tin định danh và loại thẻ được phân quyền (polymorphic) | `cardId`, `cardType`, `status`, `expiresAt` | Thể hiện qua subtype: `studentId`, `employeeId`, `guestName`, `visitorId` |
| `AccessLog` | Nhật ký quẹt thẻ kiểm soát ra/vào | `logId`, `cardId`, `gateId`, `direction`, `timestamp`, `status` | `reasonCode`, `operatorNote` |

---

## 2. Action/API dự kiến

| Method | Path | Mục đích | Consumer gọi khi nào? |
|---|---|---|---|
| GET | `/health` | Kiểm tra trạng thái hoạt động của Access Gate Service | Khi cần giám sát uptime hệ thống. |
| GET | `/access/logs` | Truy xuất toàn bộ log quẹt thẻ (phân trang bằng cursor) | Khi đồng bộ hoặc đối soát dữ liệu định kỳ. |
| GET | `/access/logs/recent` | Lấy danh sách log mới nhất để hiển thị dashboard quản trị | Khi hiển thị danh sách hoạt động trực quan realtime. |
| GET | `/access/logs/{logId}` | Lấy chi tiết log theo ID | Khi người dùng click xem chi tiết một lượt quẹt thẻ cụ thể. |
| GET | `/gates/{gateId}/status` | Truy xuất trạng thái đóng/mở/khóa của cổng | Khi kiểm tra tình trạng vật lý của cổng. |
| GET | `/cards` | Duyệt danh sách thẻ RFID hoạt động | Khi kiểm tra danh sách thẻ được cấp phát. |
| GET | `/cards/{cardId}` | Truy xuất thông tin phân quyền của thẻ vật lý | Khi cần định danh người dùng sở hữu thẻ. |

---

## 3. Error case

Tối thiểu 5 case.

| Status | Tình huống | Response body dự kiến |
|---:|---|---|
| 400 | Định dạng CardId không hợp lệ (không đúng pattern `RFID-YYYY-NNN`) | `Problem` (Validation Failure) |
| 401 | Thiếu Bearer Token trong Authorization Header hoặc token hết hạn | `Problem` (Authentication Credentials Missing) |
| 403 | Token hợp lệ nhưng Client không có role thích hợp (ví dụ: `security_auditor`) | `Problem` (Permission Denied) |
| 404 | Không tìm thấy logId hoặc cardId trong database | `Problem` (Resource Not Located) |
| 409 | Yêu cầu trùng lặp trùng ID phiên ghi nhận log | `Problem` (Resource State Conflict) |
| 422 | Thẻ hợp lệ về schema nhưng đã bị khóa/suspension nghiệp vụ | `Problem` (Request Unprocessable) |

---

## 4. Giả định bổ sung

- **Giả định 1**: Core Business luôn đảm bảo đồng bộ hóa cơ sở dữ liệu sinh viên/nhân viên với Access Gate để tránh lỗi 404/422 không đáng có khi quẹt thẻ.
- **Giả định 2**: Tốc độ phản hồi của Access Gate đối với các yêu cầu kiểm tra trạng thái và logs phải dưới 100ms để đảm bảo trải nghiệm người dùng cuối.
- **Giả định 3**: Các log quẹt thẻ ở Access Gate chỉ lưu trữ nóng 30 ngày. Dữ liệu cũ hơn sẽ được chuyển vào cold storage ngoại tuyến.

---

## 5. Câu hỏi cho Consumer

1. Tần suất truy vấn log trung bình từ phía Core Business là bao nhiêu để Provider chuẩn bị tài nguyên database replica thích hợp?
2. Trong trường hợp mất kết nối mạng (offline mode), Access Gate có quyền tự động quyết định mở cổng (fail-open) hay giữ cổng đóng (fail-closed)?
3. Webhook báo động cổng (`gateAlarmTriggered`) có cần hỗ trợ retry mechanism với exponential backoff không?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Lệch múi giờ giữa Provider và Consumer | Log timestamp hiển thị sai giờ thực tế | Tất cả timestamp bắt buộc truyền nhận theo ISO 8601 UTC (`YYYY-MM-DDTHH:mm:ssZ`). |
| Số lượng log tăng đột biến gây nghẽn | Trả log chậm, nghẽn tài nguyên server | Bắt buộc sử dụng Cursor-based pagination thay vì Offset-based pagination. |
| Webhook bị mất mát gói tin | Core Business bỏ lỡ cảnh báo đột nhập nghiêm trọng | Áp dụng cơ chế webhook handshake và lưu nhật ký alert retry ở phía Provider. |
