ARG PYTHON_IMAGE
FROM ${PYTHON_IMAGE}
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
COPY apps/api/requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir -r /tmp/requirements.lock
COPY apps/api /app/apps/api
COPY deploy/v2-server/container /app/operations
RUN pip install --no-cache-dir --no-deps /app/apps/api
ARG REVISION
LABEL org.opencontainers.image.revision=${REVISION}
ENV PILLXAI_SERVICE_VERSION=0.1.0+${REVISION}
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=6 CMD ["python", "/app/operations/health.py"]
CMD ["python", "/app/operations/serve.py"]
