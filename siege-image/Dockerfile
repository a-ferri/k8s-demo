FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt update \
    && apt --no-install-recommends -y install siege \
    && apt clean \
    && rm -rf /var/lib/apt/lists 

ENTRYPOINT ["siege"]

CMD ["--help"]