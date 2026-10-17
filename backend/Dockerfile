# syntax=docker/dockerfile:1
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# Distroless: no shell, non-root, minimal attack surface. Time-zone data is
# embedded in the binary (time/tzdata).
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
ENV APP_ENV=production HTTP_ADDR=:8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
