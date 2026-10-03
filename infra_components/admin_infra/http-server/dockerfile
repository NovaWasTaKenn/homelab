FROM docker.io/golang:1.22-alpine AS builder
WORKDIR /build
COPY go.mod .
COPY main.go .
RUN go build -o pxe-server .

FROM docker.io/alpine:latest
COPY --from=builder /build/pxe-server /pxe-server
ENTRYPOINT ["/pxe-server"]
