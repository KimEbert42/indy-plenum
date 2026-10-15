ARG BASE_IMAGE=indy-plenum-base:latest
FROM ${BASE_IMAGE}

WORKDIR /app
COPY . .

RUN pip3 install .[tests]

ENTRYPOINT ["python3"]
