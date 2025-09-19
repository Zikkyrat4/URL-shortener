services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://${db_user}:${db_password}@${db_host}:5432/${db_name}?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt
      - REDIS_ADDR=redis:6379
    depends_on:
      - redis
    restart: unless-stopped
    networks:
      - app-network
    # Добавьте volume для SSL сертификатов
    volumes:
      - /etc/ssl/certs:/etc/ssl/certs:ro

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge