# Biên bản đàm phán hợp đồng API

- Cặp đàm phán: Pair 03
- Product: Smart Campus Operations Platform
- Provider: Access Gate Service (Nguyễn Minh Sơn)
- Consumer: Core Business Service (Nguyễn Minh Sơn)
- Phiên: v1.0
- Ngày: 2026-06-20

---

## Issue #1

- Raised by: Provider
- Endpoint: Tất cả ngoại trừ `/health`
- Concern: Ban đầu Consumer muốn dùng Simple API Key truyền qua query parameter (`?api_key=...`) để dễ tích hợp và phát triển nhanh. Tuy nhiên, Provider lo ngại vấn đề rò rỉ log trên gateway/proxy và thiếu khả năng audit chi tiết các vai trò (audit log).
- Proposal: Provider đề xuất dùng chuẩn Bearer Token (JWT) trong HTTP Header `Authorization`. Token này sẽ chứa các claim về scope và client roles.
- Resolution: Accepted
- Rationale: Đảm bảo tính bảo mật theo chuẩn thiết kế Smart Campus và cho phép phân quyền chi tiết (RBAC) trên các endpoint như truy xuất nhật ký ra/vào nhạy cảm.
- Impact: Consumer phải tích hợp luồng lấy JWT token trước khi gọi các endpoint của Access Gate. Đã khai báo `bearerAuth` trong `components.securitySchemes`.

---

## Issue #2

- Raised by: Provider
- Endpoint: `/cards/{cardId}` và `/access/logs`
- Concern: Consumer muốn cardId là một chuỗi tự do (string) bất kỳ để lưu được nhiều loại thẻ khác nhau. Tuy nhiên, thiết bị phần cứng của Provider yêu cầu một mã regex cụ thể để khớp với mã hex lưu trên thẻ vật lý RFID của trường, tránh nhận các thẻ rác.
- Proposal: Provider đề xuất quy định cấu trúc mã thẻ nghiêm ngặt thông qua regex pattern: `^RFID-[0-9]{4}-[0-9]{3}$`.
- Resolution: Accepted
- Rationale: Việc chuẩn hóa định dạng ở mức OpenAPI contract giúp chặn dữ liệu rác ngay tại Gateway/Linter trước khi truyền xuống Database.
- Impact: Thêm trường `pattern: '^RFID-[0-9]{4}-[0-9]{3}$'` vào tất cả schemas/parameters liên quan đến `cardId`. Consumer cần thực hiện validate định dạng thẻ trước khi gửi request.

---

## Issue #3

- Raised by: Consumer
- Endpoint: `/cards/{cardId}`
- Concern: Phân hệ Core Business cần đọc các thông tin đặc thù của người sở hữu thẻ (ví dụ sinh viên thì cần `studentId`, `major`; nhân viên cần `employeeId`, `department`). Thiết kế ban đầu của Provider chỉ trả về một object phẳng `Card` với tất cả các trường tùy chọn, dẫn đến dữ liệu trả về mập mờ và khó lập trình kiểu dữ liệu ở Consumer.
- Proposal: Consumer đề xuất sử dụng đa hình (Polymorphism) bằng cách sử dụng `oneOf` kết hợp với `discriminator` dựa trên trường `cardType` (có các giá trị: `STUDENT`, `STAFF`, `GUEST`).
- Resolution: Accepted
- Rationale: Giúp đặc tả rõ ràng schema ứng với từng loại đối tượng thẻ, đảm bảo tính chặt chẽ trong mã nguồn của cả hai bên.
- Impact: Thay đổi schema `Card` thành kiểu `oneOf` trỏ đến `StudentCard`, `StaffCard`, và `GuestCard` với discriminator `cardType`. Các schema chi tiết được định nghĩa riêng biệt.

---

## Issue #4

- Raised by: Provider
- Endpoint: `/access/logs` và `/cards`
- Concern: Consumer muốn sử dụng phân trang dạng Offset-based pagination (`limit`/`offset`) vì dễ code SQL. Tuy nhiên, Provider lo ngại do lượng log quẹt thẻ tại cổng phát sinh liên tục theo thời gian thực (realtime write-heavy), việc dùng offset sẽ gây ra hiện tượng bỏ sót hoặc lặp bản ghi (page drift) khi truy vấn và gây chậm cơ sở dữ liệu khi offset lớn.
- Proposal: Provider yêu cầu bắt buộc sử dụng Cursor-based pagination (`cursor`/`limit`) sử dụng mã hóa Base64 cho trường ID bản ghi tiếp theo.
- Resolution: Accepted
- Rationale: Cursor-based pagination đảm bảo dữ liệu hiển thị không bị lặp/sót và tối ưu hiệu năng truy vấn cho bảng dữ liệu lớn.
- Impact: Tạo parameter `Cursor` trong `components.parameters` có kiểu `type: [string, "null"]` và thêm trường `nextCursor` trong response schema của danh sách.

---

## Issue #5

- Raised by: Consumer
- Endpoint: Tất cả các error responses (4xx/5xx)
- Concern: Định dạng lỗi ban đầu của Provider trả về dạng text thô hoặc JSON đơn giản `{ "error": "message" }`. Consumer muốn một cấu trúc lỗi đồng bộ và chuẩn hóa để có thể lập trình xử lý lỗi tự động cho toàn bộ hệ thống Smart Campus.
- Proposal: Consumer đề xuất áp dụng chuẩn RFC 7807 / RFC 9457 (Problem Details for HTTP APIs) sử dụng Content-Type `application/problem+json`.
- Resolution: Accepted
- Rationale: RFC 9457 cung cấp một cấu trúc lỗi tiêu chuẩn gồm `type`, `title`, `status`, `detail`, `instance` và danh sách các lỗi con `errors` chi tiết cho từng field, giúp dễ debug và tự động hiển thị thông báo lỗi trên UI.
- Impact: Thiết lập schema `Problem` và cấu hình các error response `400`, `401`, `403`, `404`, `409`, `422`, `500` sử dụng `$ref` trỏ đến Problem Details schema.

---

## Issue #6

- Raised by: Consumer
- Endpoint: `/access/logs`
- Concern: Core Business cần truy cập lịch sử log quẹt thẻ từ 1 năm trước để làm báo cáo thống kê năm học. Tuy nhiên, Access Gate Provider chỉ cam kết lưu trữ nóng logs trong vòng 30 ngày gần nhất để duy trì hiệu năng cao cho hệ thống kiểm soát cửa ra vào realtime.
- Proposal: Hai bên thống nhất API `/access/logs` chỉ phục vụ truy vấn dữ liệu nóng 30 ngày. Lịch sử cũ hơn sẽ được chuyển sang hệ thống Analytics/Data Lake và Core Business sẽ gọi API bên phía Analytics để lấy dữ liệu lịch sử. Endpoint cũ được đánh dấu `deprecated` hoặc sử dụng cơ chế báo trước.
- Resolution: Accepted
- Rationale: Đảm bảo cân bằng giữa hiệu năng vận hành cổng thời gian thực và nhu cầu đối soát báo cáo lịch sử.
- Impact: Không thay đổi schema trực tiếp nhưng ghi nhận vào tài liệu phân tích nghiệp vụ. Provider bổ sung header `Deprecation` và `Sunset` theo lộ trình chuyển đổi và ghi nhận chính sách versioning trong `VERSIONING.md`.

---

# Chốt hợp đồng v1.0

Provider sign-off: Nguyễn Minh Sơn (Đã ký)  
Consumer sign-off: Nguyễn Minh Sơn (Đã ký)  
Witness (GV/TA): FIT4110 Teaching Team  
Date: 2026-06-20  

---

## Ghi chú warning nếu Spectral còn cảnh báo

| Warning | Lý do chấp nhận tạm thời | Kế hoạch sửa |
|---|---|---|
| Không có warning | File `openapi.yaml` đã pass 100% linter ruleset của lớp | Không cần sửa đổi bổ sung |
