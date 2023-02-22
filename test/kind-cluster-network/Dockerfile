FROM golang:1.20-alpine
RUN CGO_ENABLED=0 go install github.com/google/ko@latest
WORKDIR /go/github.com/tilt-dev/ctlptl/test/cluster-network
ADD . .
