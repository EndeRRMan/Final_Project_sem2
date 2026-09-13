FROM golang:1.26.0-alpine3.23 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/backend-report .

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /out/backend-report /app/backend-report
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/app/backend-report"]
