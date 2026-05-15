# two-stage build keeps the final image small
# stage 1: install everything we need into a separate folder
FROM python:3.12-slim AS installer
WORKDIR /pkg
COPY requirements.txt .
RUN pip install --quiet --no-cache-dir --upgrade pip && \
    pip install --quiet --no-cache-dir -r requirements.txt

# stage 2: copy only the installed libs + our code, nothing else
FROM python:3.12-slim
LABEL org.opencontainers.image.title="helep-user-service"

# uid 10001 -- run as non-root (K8s restricted policy requires it)
RUN addgroup --gid 10001 app && \
    adduser  --uid 10001 --gid 10001 --no-create-home --shell /bin/false app

WORKDIR /srv

COPY --from=installer /usr/local/lib/python3.12/site-packages \
                      /usr/local/lib/python3.12/site-packages
COPY --from=installer /usr/local/bin /usr/local/bin

COPY app ./app
RUN mkdir -p /data && chown app:app /data

USER 10001

ENV PYTHONUNBUFFERED=1 SERVICE_PORT=8001

EXPOSE 8001

HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD python -c \
  "import urllib.request,sys; urllib.request.urlopen('http://localhost:8001/healthz',timeout=4); sys.exit(0)"

CMD ["sh","-c","uvicorn app.main:app --host 0.0.0.0 --port $SERVICE_PORT"]
