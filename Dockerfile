FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git make

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/server

FROM alpine:latest

RUN apk --no-cache add ca-certificates

RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -D appuser

WORKDIR /app

COPY --from=builder --chown=appuser:appuser /app/main .

USER appuser

EXPOSE 8080

CMD ["./main"]