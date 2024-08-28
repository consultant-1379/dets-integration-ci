FROM armdocker.seli.gic.ericsson.se/proj-ldc/common_base_os/sles:3.44.0-7
WORKDIR /ci
COPY requirements.txt .
RUN mkdir /temp /workdir && \
    zypper addrepo -CfG https://arm.rnd.ki.sw.ericsson.se/artifactory/proj-ldc-repo-rpm-local/common_base_os/sles/3.44.0-7 LDC-CBO-SLES && \
    zypper refresh -fr LDC-CBO-SLES && \
    # Install Python dependencies
    zypper install -y python3 glibc-locale python3-pip curl unzip && \
    pip install pipenv==2020.11.4 && pip install --no-cache-dir -r requirements.txt && \
    # Install openSSH
    cd /temp && zypper install -y openssh && \
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && ./aws/install && rm -rf awscliv2.zip && \
    chmod 0755 /usr/local/bin/aws && \
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" && \
    echo "$(<kubectl.sha256)  kubectl" | sha256sum --check && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    # Install Git
    zypper --non-interactive addrepo http://download.opensuse.org/repositories/devel:/tools:/scm/SLE_15_SP3/devel:tools:scm.repo && \
    zypper --no-gpg-checks install -y git-core && zypper install -y iptables && \
    # Install Docker
    curl https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz --output ./docker.tgz && \
    tar -xzf docker.tgz && cp docker/docker /usr/local/bin && rm -rf docker && \
    chmod 0755 /usr/local/bin/docker && \
    # Install Helm
    curl -fsSo helm https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz && tar -zxvf helm && \
    mv linux-amd64/helm /usr/local/bin && chmod +x /usr/local/bin/helm && \
    # Install Helmfile
    rm -f /usr/bin/helmfile && \
    curl -fSLo /usr/local/bin/helmfile https://github.com/roboll/helmfile/releases/download/v0.142.0/helmfile_linux_amd64 && \
    chmod +x /usr/local/bin/helmfile && \
    # Install yq
    curl -fsSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.15.1/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq && \
    # Install jq
    zypper install -y jq && \
    # Install Spinnaker CLI
    curl -LO https://storage.googleapis.com/spinnaker-artifacts/spin/$(curl -s https://storage.googleapis.com/spinnaker-artifacts/spin/latest)/linux/amd64/spin && \
    chmod +x spin && \
    mv spin /usr/bin/spin && \
    # Cleanup
    zypper clean --all && \
    rm -rf aws linux-amd64 && \
    rm -f helm kubectl docker.tgz kubectl.sha256 requirements.txt && \
    # Creating required Cache Directories for all users
    mkdir /.aws && chmod -R 777 /.aws && \
    mkdir /.kube && chmod -R 777 /.kube && \
    mkdir /.docker && chmod -R 777 /.docker && \
    mkdir /.cache && chmod -R 777 /.cache && \
    mkdir /.config && chmod -R 777 /.config

# Create workspace
WORKDIR /workdir

CMD ["echo","CI-Utils Container"]
