FROM golang:1.24-alpine AS build
WORKDIR /src
ARG GOPROXY=https://proxy.golang.org,direct
ENV GOPROXY=$GOPROXY
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/ava-server ./cmd/ava-server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H ava
COPY --from=build /out/ava-server /usr/local/bin/ava-server
ENV ADDR=:8080
EXPOSE 8080
USER ava
ENTRYPOINT ["ava-server"]
CMD ["serve"]
