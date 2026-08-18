setup-pxe-infra: 
  cd $PROJECT_PATH/pxe-infra && sops exec-env $PROJECT_PATH/secrets.enc.yaml 'sudo podman compose up'

molecule-test:
  sops exec-env $PROJECT_PATH 'molecule test'


# Add ansible, terraform ; layer1 ... recipes
