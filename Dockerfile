FROM alpine:3

ENV BASE_URL="https://get.helm.sh"

ENV HELM_3_FILE="helm-v3.4.2-linux-amd64.tar.gz"

RUN apk add --no-cache ca-certificates \
    --repository http://dl-3.alpinelinux.org/alpine/edge/community/ \
    jq curl bash nodejs && \
    # Install python3 and AWS CLI:
    apk add --update --no-cache python3 && \
    ln -sf python3 /usr/bin/python && \
    python3 -m ensurepip && \
    pip3 install awscli git
    # Install helm version 3:
RUN curl -L ${BASE_URL}/${HELM_3_FILE} |tar xvz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64

    # Install helm-github plugin

COPY helm-github helm-github
RUN helm plugin install ./helm-github


ENV PYTHONPATH "/usr/lib/python3.8/site-packages/"

COPY . /usr/src/
ENTRYPOINT ["node", "/usr/src/index.js"]
