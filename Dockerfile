# Start with az CLI because Azure
FROM mcr.microsoft.com/azure-cli

# Install OS packages
RUN apk update && apk add jq curl bash sudo

# Install Terraform
RUN tfzipdir="$(mktemp -d)"; cd "$tfzipdir"; \
    curl -L "https://releases.hashicorp.com/terraform/0.13.0-rc1/terraform_0.13.0-rc1_linux_amd64.zip" > "$tfzipdir"/terraform.zip && \
    unzip terraform.zip && \
    sudo mv terraform /usr/local/bin/terraform && \
    sudo chmod +x /usr/local/bin/terraform

# Copy entrypoint script
COPY ./infracontainer-entrypoint.sh /infracontainer-entrypoint.sh
RUN chmod +x /infracontainer-entrypoint.sh

# Set up expected infracontainer directories
RUN mkdir /in; mkdir /out; mkdir /logs

# Set up directory for Terraform config to go in
RUN mkdir /app
WORKDIR /app

# Copy Terraform config
COPY ./ /app

# Set entrypoint
ENTRYPOINT ["/infracontainer-entrypoint.sh"]
CMD ["help"]
