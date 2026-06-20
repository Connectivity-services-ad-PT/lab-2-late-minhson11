# API Versioning Policy - Smart Campus Access Gate

Tài liệu này quy định quy tắc quản lý phiên bản (versioning), chính sách tương thích ngược (backward compatibility), và quy trình loại bỏ tính năng cũ (deprecation/sunset) đối với các dịch vụ tích hợp trong Smart Campus, đặc biệt áp dụng cho **Access Gate API v1.0.0**.

---

## 1. Nguyên tắc quản lý phiên bản

Access Gate API áp dụng chuẩn **Semantic Versioning (SemVer)** phiên bản `MAJOR.MINOR.PATCH` để định danh:

- **MAJOR**: Tăng khi có các thay đổi phá vỡ tính tương thích ngược (breaking changes) với Consumer. Ví dụ: `v1.x.x` nâng lên `v2.0.0`.
- **MINOR**: Tăng khi bổ sung các chức năng hoặc endpoints mới có tính tương thích ngược. Ví dụ: `v1.0.0` lên `v1.1.0`.
- **PATCH**: Tăng khi sửa lỗi (bug fixes) tương thích ngược. Ví dụ: `v1.0.0` lên `v1.0.1`.

Phiên bản chính (Major version) được thể hiện trực tiếp trong URL và đường dẫn API thực tế:
- URL mẫu: `https://api.access-gate.campus.local/v1/access/logs`

---

## 2. Quy tắc tương thích ngược (Backward Compatibility)

### A. Thay đổi tương thích ngược (Non-breaking Changes)
*Được phép cập nhật trong các phiên bản Minor hoặc Patch mà không cần nâng cấp Major version:*
1. **Bổ sung endpoint mới**: Thêm đường dẫn (path) mới vào `openapi.yaml`.
2. **Bổ sung trường tùy chọn (optional field)**: Thêm các thuộc tính mới không bắt buộc vào request body hoặc các trường mới vào response body.
3. **Bổ sung tham số tùy chọn (optional parameter)**: Thêm query/header/path parameter tùy chọn.
4. **Bổ sung giá trị enum mới**: Thêm một giá trị enum mới vào response schema (Consumer cần xử lý fallback cho các giá trị enum lạ).
5. **Bổ sung Webhook mới**: Thêm một sự kiện webhook mới trong block `webhooks`.

### B. Thay đổi phá vỡ tương thích ngược (Breaking Changes)
*Bắt buộc phải phát hành phiên bản Major mới:*
1. **Xóa hoặc đổi tên endpoint**: Thay đổi đường dẫn hoặc method (ví dụ: đổi `GET /access/logs` thành `GET /access/history`).
2. **Xóa hoặc đổi tên trường dữ liệu**: Bỏ trường bắt buộc/tùy chọn hoặc đổi tên thuộc tính trong request/response.
3. **Thay đổi kiểu dữ liệu**: Chuyển đổi kiểu của trường (ví dụ: từ `integer` sang `string`).
4. **Thêm ràng buộc chặt hơn**: Thêm thuộc tính vào danh sách `required`, hoặc thêm/thay đổi regex `pattern`, `minLength`, `maximum` làm bó hẹp phạm vi dữ liệu hợp lệ.
5. **Thay đổi mã HTTP Status Code**: Thay đổi mã trả về của endpoint (ví dụ: chuyển từ trả về `200 OK` trống sang `204 No Content` hoặc thay đổi mã lỗi từ `400` thành `422`).

---

## 3. Quy trình Deprecation và Sunset

Khi một endpoint hoặc trường dữ liệu cần được thay thế, Provider sẽ áp dụng quy trình gồm 3 bước: **Mark Deprecated → Emit Headers → Sunset**.

### Bước 1: Khai báo trong `openapi.yaml`
1. Đánh dấu thuộc tính `deprecated: true` tại endpoint hoặc schema field tương ứng.
2. Thêm mô tả lý do deprecation và phương án thay thế trong trường `description`.

Ví dụ đặc tả trong OpenAPI:
```yaml
paths:
  /access/logs/old-endpoint:
    get:
      deprecated: true
      summary: Lấy nhật ký (cũ)
      description: Endpoint này đã bị thay thế bởi /access/logs phân trang cursor. Sẽ bị tắt hoàn toàn vào ngày Sunset.
```

### Bước 2: Phát hành HTTP Headers trong Response thực tế
Khi Consumer gọi một endpoint đã bị deprecated, server của Provider sẽ trả về các Header tiêu chuẩn trong response để cảnh báo:

1. **`Deprecation`**: Xác nhận endpoint đã bị phản đối và thời điểm bắt đầu deprecated.
   ```http
   Deprecation: Mon, 20 Jul 2026 00:00:00 GMT
   ```
2. **`Sunset`**: Thời hạn cuối cùng mà endpoint này còn hoạt động. Sau ngày này, API sẽ trả về lỗi `410 Gone` hoặc `404 Not Found`.
   ```http
   Sunset: Mon, 20 Oct 2026 23:59:59 GMT
   ```
3. **`Link`**: Trỏ tới tài liệu hướng dẫn chuyển đổi API mới.
   ```http
   Link: <https://api.access-gate.campus.local/docs/migration-v1-to-v2>; rel="deprecation"
   ```

### Bước 3: Hết hạn (Sunset) và Gỡ bỏ
- Khoảng thời gian từ lúc đánh dấu `deprecated` đến lúc `sunset` tối thiểu là **3 tháng** đối với môi trường nội bộ Smart Campus.
- Sau thời gian Sunset, endpoint sẽ bị tắt hoàn toàn và Provider giải phóng tài nguyên.
