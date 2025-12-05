FROM golang:1.21 AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/hello .

FROM alpine:3.19
RUN adduser -D appuser
COPY --from=builder /out/hello /usr/local/bin/hello
USER appuser
EXPOSE 8081
ENTRYPOINT ["/usr/local/bin/hello"]
