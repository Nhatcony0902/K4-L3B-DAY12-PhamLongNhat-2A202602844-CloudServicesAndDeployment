# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   [x] Multi-stage: `builder` cài dependency, `runtime` chỉ copy kết quả
#   [x] Base image slim
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source (cache layer)
#   [x] Chạy bằng user thường `appuser`, không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ biến môi trường PORT
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài thư viện vào /install, stage này bị bỏ đi sau build
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — image cuối cùng, chỉ có Python + thư viện + code
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Code copy SAU cùng: sửa code chỉ làm mất cache của các layer từ đây trở đi
COPY --chown=appuser:appuser utils ./utils
COPY --chown=appuser:appuser app ./app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.getenv('PORT', '8000') + '/health', timeout=3).read()" || exit 1

# Qua `sh -c` để ${PORT} được nội suy lúc chạy (Railway/Render tự gán PORT).
# `exec` để uvicorn thay chỗ sh làm PID 1 và nhận SIGTERM trực tiếp — sh
# không chuyển tiếp tín hiệu, container sẽ bị SIGKILL thay vì tắt êm.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
