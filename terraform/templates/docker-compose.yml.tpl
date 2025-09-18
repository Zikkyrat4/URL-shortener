services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}?sslmode=verify-full
      - REDIS_ADDR=redis:6379
    depends_on:
      - redis
    restart: unless-stopped
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge