# syntax=docker/dockerfile:1.7

ARG MAVEN_IMAGE=maven:3.9.11-eclipse-temurin-21-alpine
ARG RUNTIME_IMAGE=eclipse-temurin:21.0.12_8-jre-alpine-3.22

FROM ${MAVEN_IMAGE} AS builder

WORKDIR /workspace

# Download dependencies before copying sources to maximize layer reuse.
COPY backend/pom.xml ./pom.xml
RUN --mount=type=cache,target=/root/.m2 \
    mvn --batch-mode --no-transfer-progress dependency:go-offline

COPY backend/src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn --batch-mode --no-transfer-progress -DskipTests package && \
    cp target/backend-*.jar /tmp/app.jar

FROM ${RUNTIME_IMAGE} AS runtime

LABEL org.opencontainers.image.title="Rezo Backend" \
      org.opencontainers.image.description="API Spring Boot de la plateforme Rezo" \
      org.opencontainers.image.source="https://github.com/ndiougand20-commits/rezo-devsecops"

RUN apk upgrade --no-cache && \
    addgroup -S -g 10001 rezo && \
    adduser -S -D -H -u 10001 -G rezo rezo && \
    mkdir -p /app/uploads && \
    chown -R 10001:10001 /app

WORKDIR /app

COPY --from=builder --chown=10001:10001 /tmp/app.jar /app/app.jar

USER 10001:10001

ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -Djava.io.tmpdir=/tmp" \
    REZO_OPENAPI_ENABLED="false" \
    REZO_SHOW_SQL="false"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/ping || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
