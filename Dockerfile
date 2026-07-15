FROM alpine:3.20
COPY hello.txt /hello.txt
CMD ["cat", "/hello.txt"]
