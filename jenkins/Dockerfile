FROM jenkins/jenkins:2.479.1-lts-jdk17

USER root
# AWS CLI v2, jq and Python for the ops scripts
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip jq python3 python3-boto3 \
 && curl -sSLo /tmp/awscli.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
 && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscli.zip /var/lib/apt/lists/*
USER jenkins

# Skip the setup wizard: everything is configured from casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins casc.yaml /var/jenkins_home/casc.yaml
