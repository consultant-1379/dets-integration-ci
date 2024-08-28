###############################################################################################################
# Prepare an initial image later used by intermediate images as well as during the released image build.
###############################################################################################################
FROM armdocker.rnd.ericsson.se/proj-ldc/common_base_os/sles:3.45.0-15
RUN zypper ar -C -G -f https://arm.sero.gic.ericsson.se/artifactory/proj-ldc-repo-rpm-local/common_base_os/sles/3.45.0-15 LDC-CBO-SLES \
 && zypper ref -f -r LDC-CBO-SLES \
 && zypper install -y python39 \
 && zypper clean --all \
 && find /usr -type d -name  "__pycache__" -exec rm -r {} +

# A locale needs to be installed and set for later use by some python packages like click
ENV LC_ALL=en_US.utf-8
ENV LANG=en_US.utf-8

RUN zypper install -y python39-pip curl unzip

# Download helm 3 binary for later inclusion in final image.
WORKDIR /helm3/
RUN curl -O https://arm1s11-eiffel052.eiffel.gic.ericsson.se:8443/nexus/service/local/repositories/eo-3pp-foss/content/org/cncf/helm/3.7.1/helm-3.7.1.zip
RUN unzip helm-3.7.1.zip

## Make sure helm is executable
RUN mv /helm3/linux-amd64/helm /usr/bin/helm
RUN helm version

# Download helmfile binary for later inclusion in final image.
WORKDIR /helmfile/
RUN curl -O https://arm1s11-eiffel052.eiffel.gic.ericsson.se:8443/nexus/service/local/repositories/eo-3pp-tools/content/com/helm/helmfile/0.139.9/helmfile-0.139.9.zip
RUN unzip helmfile-0.139.9.zip

## Make sure helmfile is executable
RUN mv /helmfile/helmfile_linux_amd64 /usr/bin/helmfile
RUN helmfile version

# Download kubectl binary for later inclusion in final image.
WORKDIR /usr/bin
RUN curl -sL https://arm1s11-eiffel052.eiffel.gic.ericsson.se:8443/nexus/content/repositories/eo-3pp-foss/org/cncf/kubernetes/kubectl/1.22.0/kubectl-1.22.0.zip -o kubectl.zip
RUN unzip kubectl.zip

## Make sure kubectl is executable
RUN kubectl --help

WORKDIR /ci-scripts/

RUN mkdir output-files

COPY requirements.txt .
RUN pip3.9 install -r requirements.txt

COPY src /ci-scripts

ENTRYPOINT ["/usr/bin/python3.9", "/ci-scripts"]
