# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Pham Long Nhat |
| Mã học viên | 2A202602844 |
| Repo | https://github.com/Nhatcony0902/K4-L3B-DAY12-PhamLongNhat-2A202602844-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-f7be.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, cấu hình trong `railway.toml`) |
| Ngày deploy | 2026-09-29 |

Project Railway `day12-agent` gồm 2 service: `agent` (image build từ repo) và
`Redis` (database add-on của Railway, có volume `redis-volume`).

## Biến Môi Trường Đã Set Trên Cloud

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán (thực tế là 8080), app đọc qua `${PORT}` |
| `AGENT_API_KEY` | ✅ | đặt bằng `railway variables`, khóa riêng cho cloud, không nằm trong repo |
| `REDIS_URL` | ✅ | tham chiếu `${{Redis.REDIS_URL}}` tới Redis add-on (host nội bộ `redis.railway.internal`) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

```bash
URL=https://agent-production-f7be.up.railway.app

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-29 từ Git Bash trên Windows:

```
$ curl -i https://agent-production-f7be.up.railway.app/health
HTTP/1.1 200 OK
Content-Type: application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i https://agent-production-f7be.up.railway.app/ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

$ curl -i -X POST https://agent-production-f7be.up.railway.app/ask   # không có API key
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}

$ # rate limit: 15 lần /ask cùng user sv-test
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429

$ # có X-API-Key, X-User-Id: sv-test, body UTF-8 (chạy lại sau khi hết cửa sổ 60s)
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud. (Mình đang nhớ 20 lượt trao đổi trước đó.)","user_id":"sv-test","history_length":20,"cost_usd":9.285e-05,"tokens":{"in":439,"out":45}}
```

Ghi chú:

- Lần đầu chạy lệnh 4 bằng `-d '{"question":"Deploy là gì?"}'` trong Git Bash
  trên Windows nhận `400 {"detail":"There was an error parsing the body"}`:
  terminal gửi chữ `à`/`ì` không phải UTF-8 nên JSON không hợp lệ. Gửi body
  bằng `--data-binary @body.json` (file UTF-8) thì trả 200 như trên.
- `history_length` = 20 vì user `sv-test` đã có 10 lượt hỏi ở bước rate limit
  (20 message); store chỉ giữ tối đa 20 message gần nhất (`ltrim`).
- Log trên Railway cho thấy uvicorn chạy với PID 1 và cổng do platform gán:
  `Uvicorn running on http://0.0.0.0:8080`.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên Railway
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
