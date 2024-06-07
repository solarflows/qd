# 设置基础镜像
FROM a76yyyy/pycurl:latest

# 设置维护者信息
LABEL maintainer "husky"
LABEL org.opencontainers.image.source=https://github.com/solarflows/qd

# 设置工作目录
WORKDIR /usr/src/app

# 更新Alpine镜像源并安装OpenSSH客户端
RUN sed -i 's/mirrors.ustc.edu.cn/dl-cdn.alpinelinux.org/g' /etc/apk/repositories && \
    apk update && \
    apk add --update --no-cache openssh-client

# 设置SSH密钥权限并添加远程主机到known_hosts
RUN chmod 600 /root/.ssh/id_rsa && \
    ssh-keyscan gitee.com > /root/.ssh/known_hosts

# 引入随机睡眠延迟
RUN let num=$RANDOM%100+10 && \
    sleep $num

# 克隆代码仓库并处理
RUN git clone --depth 1 git@gitee.com:qd-today/qd.git /gitclone_tmp && \
    yes | cp -rf /gitclone_tmp/. /usr/src/app && \
    rm -rf /gitclone_tmp

# 设置可执行权限和创建目录
RUN chmod +x /usr/src/app/update.sh && \
    mkdir -vp /usr/src/app/config && \
    mkdir -vp /config/qdtoday

# 创建软链接
RUN ln -s /usr/src/app/update.sh /bin/update && \
    ln -s /usr/src/app/config /config/qdtoday

# 安装Python及相关依赖
RUN apk add --update --no-cache openssh-client python3 py3-six \
    py3-markupsafe py3-pycryptodome py3-tornado py3-wrapt \
    py3-packaging py3-greenlet py3-urllib3 py3-cryptography \
    py3-aiosignal py3-async-timeout py3-attrs py3-frozenlist \
    py3-multidict py3-charset-normalizer py3-aiohttp \
    py3-typing-extensions py3-yarl py3-cffi

# 根据系统位数选择性安装依赖包
RUN [[ $(getconf LONG_BIT) = "32" ]] && \
    echo "Tips: 32-bit systems do not support ddddocr, so there is no need to install numpy and opencv-python" || \
    apk add --update --no-cache py3-numpy-dev py3-opencv py3-pillow

# 安装构建所需软件包
RUN apk add --no-cache --virtual .build_deps cmake make perl \
    autoconf g++ automake py3-pip py3-setuptools py3-wheel python3-dev \
    linux-headers libtool util-linux

# 在requirements.txt中移除特定依赖
RUN sed -i '/ddddocr/d' requirements.txt && \
    sed -i '/packaging/d' requirements.txt
    # (其他依赖移除步骤省略)

# 使用pip安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt --break-system-packages

# 清理构建所需软件包
RUN apk del .build_deps

# 恢复Alpine镜像源并清理缓存
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    rm -rf /var/cache/apk/* && \
    rm -rf /usr/share/man/*

# 设置环境变量和暴露端口
ENV PORT 80
EXPOSE $PORT/tcp

# 设置时区
ENV TZ=CST-8

# 添加挂载点
VOLUME ["/config/qdtoday"]

# 运行命令
CMD ["sh","-c","python /usr/src/app/run.py"]
