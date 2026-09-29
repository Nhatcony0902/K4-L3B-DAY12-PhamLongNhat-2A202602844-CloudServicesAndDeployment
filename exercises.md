# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>

> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Long Nhật  Mã học viên: 2A202602844


### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.


Ban đầu, container chạy không có AGENT_API_KEY mà vẫn khởi động, Docker báo healthy, /health trả 200. Chỉ đến khi gọi /ask mới nổ ValidationError thành 500.
- Nguyên nhân: Settings chỉ được đọc lần đầu bên trong verify_api_key.
- Sau khi thêm get_settings() vào lifespan: container chết sau 1 giây (exit code 3), log ghi agent_api_key Field required.
Tình huống cụ thể: deploy lên Railway nhưng quên set AGENT_API_KEY.
- Nếu có mặc định "changeme": app lên xanh, còn khóa changeme thì ai đọc repo trên GitHub (repo public) cũng biết. Người lạ gọi /ask miễn phí bằng khóa đó, và bạn chỉ phát hiện khi nhìn hóa đơn.
- Fail fast: deploy đỏ ngay, healthcheck của Railway không qua, nên bản lỗi không bao giờ nhận traffic. Lỗi hiện ra lúc bạn đang nhìn màn hình, không phải 3 ngày sau.
- Bài học từ thí nghiệm: không có giá trị mặc định là chưa đủ, config còn phải được đọc lúc khởi động.

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.


{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:33:08.949108+00:00", "user_id": "sv01", "tokens_in": 46, "tokens_out": 54, "cost_usd": 3.93e-05}
 Railway tự tách dòng JSON đó thành các trường riêng:
[INFO]  event="ask_completed" ... user_id="cp5-test" tokens_in=41 tokens_out=45 cost_usd=0.00003315 ,với print("đã trả lời xong") thì Railway chỉ thấy một chuỗi chữ.
Lọc và tìm kiếm theo trường: ví dụ lọc user_id = "sv01" để xem mọi câu hỏi của một user, hoặc lọc level = "error". Chuỗi print không có user_id nên không lọc được.
 Tính toán và thống kê: cộng cost_usd theo từng user để biết ai tiêu nhiều tiền nhất hôm nay, hoặc cộng tokens_in/tokens_out. print không có con số nào để cộng.

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) |1730  MB |
| Multi-stage |  271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

1. Base image: phần lớn nhất, khoảng 1.4GB.
   - Nền của bản 1 stage (python:3.11 đầy đủ) chiếm khoảng 1.63GB; nền của bản multi-stage (python:3.11-slim) chỉ khoảng 205MB.
   - Bản đầy đủ mang theo cả bộ công cụ build và tiện ích. Tôi đã kiểm tra: trong agent:single có sẵn gcc, g++, make, git, curl. Trong agent:multi thì không có cái nào.
   - Đây là những thứ chỉ cần lúc biên dịch thư viện, app chạy không cần.
2. Layer cài thư viện: 95.1MB so với 65.5MB.
   - Bản 1 stage chạy pip install không có --no-cache-dir, nên giữ lại cache của pip. Tôi đo được /root/.cache/pip nặng 17MB nằm trong image.
   - Bản multi-stage chỉ COPY --from=builder /install, tức chỉ lấy thư viện đã cài xong. Cache và mọi thứ phát sinh trong stage builder bị bỏ lại.
3. File thừa do COPY . .: bản 1 stage copy cả Dockerfile, docker-compose.yml, grade.py, nginx/, railway.toml… vào /app. Phần này nhỏ (176kB) nhưng cho thấy image chứa những thứ không cần để chạy. Bản multi-stage chỉ copy app/ và utils/.

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

docker cache theo từng layer nên khi mà layer thay đổi thì nó và mọi layer phía sau phải build lại 
khi đặt copy .. lên trước sửa bất kì kí tự nào thì layer COPY .. đều khác kéo theo pip install các layer sau phải chạy lại

FROM python:3.11-slim: CACHED — Base image không đổi.

COPY . .: CHẠY LẠI — Vì file code trong project bị sửa, layer này bị hỏng cache ngay lập tức.

RUN pip install ...: CHẠY LẠI (98.2s) — Layer trước bị phá cache nên layer này bắt buộc phải tải lại toàn bộ dependencies từ Pypi.

COPY --from=builder /install: CHẠY LẠI — Bị kéo theo.

RUN useradd ...: CHẠY LẠI — Bị kéo theo.

COPY utils ./utils: CHẠY LẠI — Bị kéo theo.

COPY app ./app: CHẠY LẠI — Bị kéo theo.
### Câu 5 — Vì sao không chạy bằng root (CP2)


1. Code Python có lỗ hổng, ví dụ eval/pickle trên dữ liệu người dùng gửi lên, hoặc một thư viện dính lỗi RCE. Kẻ tấn công chạy được lệnh trong container.
2. Lệnh đó chạy với quyền của process app. Nếu app chạy bằng root thì kẻ tấn công là root trong container: sửa thư viện, cài công cụ, đọc mọi file (bảng trên).
3. Container không phải máy ảo. Nó dùng chung kernel với host, và uid 0 trong container cũng là uid 0 của kernel. Mọi thứ được mount từ host (volume, thư mục, nặng nhất là /var/run/docker.sock) đều bị ghi bằng quyền root. Chỉ cần thêm một lỗi cấu hình hoặc một lỗ hổng kernel/runtime để thoát ra ngoài container, kẻ tấn công sẽ là root trên host.
4. USER appuser cắt chuỗi ở bước 2. Kẻ tấn công vẫn chạy được lệnh, nhưng chỉ với quyền một user thường: không sửa được hệ thống và thư viện, không ghi được vào file của root trên volume, và khi thoát ra host (nếu thoát được) cũng chỉ là uid 10001, không có quyền gì.

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

tối đa 20 request. Gửi 10 request ở giây 59, bộ đếm reset lúc giây 00, rồi gửi tiếp 10. Mô phỏng thật: fixed window cho lọt 20, sliding window trong code của bạn chỉ cho lọt 10

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

 Rate limit đếm số lần gọi trong một khoảng thời gian ngắn, trả 429.
- Cost guard đếm số tiền cộng dồn cả tháng, trả 402.
- Rate limit cho qua nhưng cost guard chặn: user gọi đều 9 lần/phút, không bao giờ vượt, nhưng mỗi lần gửi prompt thật dài. Tiền cộng dồn tới hết 10 USD thì bị 402.
- Ngược lại: user spam 15 câu "Hi" trong 5 giây. Tiền gần như không đáng kể, nhưng lần thứ 11 bị 429, vì gọi dồn dập vẫn làm quá tải server.

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis mất kết nối.
2. Cả 3 container gọi Redis trong endpoint health, cùng trả 503.
3. Orchestrator hiểu là "process chết", nên restart cả 3 container cùng lúc.
4. Trong lúc restart, không còn instance nào nhận request, người dùng thấy lỗi 502/503. Kể cả các request không cần Redis cũng bị cắt ngang giữa chừng.
5. Container khởi động lại, Redis vẫn chưa về, health lại 503, lại restart: vòng lặp restart.
6. 30 giây sau Redis quay lại, nhưng các container đang dở vòng restart nên hệ thống hồi phục chậm hơn cả sự cố gốc.

### Câu 9 — Stateless (CP4)
3 container chia request 4/3/3 mà history_length vẫn tăng đều 0, 2, 4, …, 18.
Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

nếu lịch sử nằm trong dict Python, mỗi container có một dict riêng. history_length sẽ nhảy lung tung, tùy request rơi vào container nào. Ví dụ agent-1 đã thấy 2 lượt thì trả 4, rồi request tiếp theo vào agent-2 chưa thấy lượt nào thì trả 0. Tổng các con số cũng không bao giờ lên được 18. Container restart thì dict mất sạch và lịch sử về 0.

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Railway hết hạn mức:
  - Lỗi: railway init báo Free plan resource provision limit exceeded. Please upgrade to provision more resources!.
  - Cách tìm nguyên nhân: railway list cho thấy đã có 2 project cũ (bubbly-reverence, delightful-determination) từ lần thử hôm trước.
  - Cách sửa: railway delete 2 project đó rồi railway init lại.
