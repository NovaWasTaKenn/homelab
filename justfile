setup-pxe-infra: 
  cd $PROJECT_PATH/infra_components/admin_infra && sops exec-env $PROJECT_PATH/secrets.enc.yaml 'sudo --preserve-env=proxmox_root_password,PXE_HTTP_PORT,PXE_HTTP_STATIC_DIR,PXE_HTTP_ANSWER_DIR,PXE_HTTP_NODE_PREFIX,PXE_HTTP_ADMIN_HOST,PXE_HTTP_STATE_FILE podman compose up -d'

teardown-pxe-infra: 
  cd $PROJECT_PATH/infra_components/admin_infra && sops exec-env $PROJECT_PATH/secrets.enc.yaml 'sudo --preserve-env=proxmox_root_password,PXE_HTTP_PORT,PXE_HTTP_STATIC_DIR,PXE_HTTP_ANSWER_DIR,PXE_HTTP_NODE_PREFIX,PXE_HTTP_ADMIN_HOST,PXE_HTTP_STATE_FILE podman compose down'

molecule-test:
  sops exec-env $PROJECT_PATH/secrets.enc.yaml 'molecule test'

# Download the latest Proxmox VE ISO, prepare it for unattended install and
# drop the artifacts (iso + vmlinuz + initrd.img) into the PXE http-files dir.
# boot.ipxe is updated in place when the version changes.
update-pxe-iso:
  #!/usr/bin/env bash
  set -euo pipefail

  : "${PXE_HTTP_ADMIN_HOST:?run inside the dev shell (config.env not sourced)}"

  MIRROR="https://enterprise.proxmox.com/iso"
  PXE_IMG_DIR="$PROJECT_PATH/infra_components/admin_infra/http-files/proxmox-img"
  BOOT_IPXE="$PROJECT_PATH/infra_components/admin_infra/http-files/boot.ipxe"

  SUMS=$(curl -fsSL "$MIRROR/SHA256SUMS")
  ISO_NAME=$(grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' <<<"$SUMS" | sort -Vu | tail -1)
  EXPECTED_SHA=$(grep "  ${ISO_NAME}$" <<<"$SUMS" | awk '{print $1}')
  VERSION="${ISO_NAME#proxmox-ve_}"
  VERSION="${VERSION%.iso}"
  PREPARED_ISO="${ISO_NAME%.iso}-auto-from-http-url.iso"

  if [[ -f "$PXE_IMG_DIR/$PREPARED_ISO" ]]; then
    echo "Already up to date: $PREPARED_ISO"
    exit 0
  fi

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  echo "Downloading $ISO_NAME..."
  curl -fSL -o "$TMP_DIR/$ISO_NAME" "$MIRROR/$ISO_NAME"
  echo "$EXPECTED_SHA  $TMP_DIR/$ISO_NAME" | sha256sum -c -

  rm -f "$PXE_IMG_DIR"/proxmox-ve_*-auto-from-http-url.iso "$PXE_IMG_DIR/vmlinuz" "$PXE_IMG_DIR/initrd.img"
  proxmox-auto-install-assistant prepare-iso \
    --fetch-from http \
    --url "http://${PXE_HTTP_ADMIN_HOST}/answer" \
    --pxe \
    --output "$PXE_IMG_DIR" \
    "$TMP_DIR/$ISO_NAME"
  rm -f "$PXE_IMG_DIR/.cd-info.tmp"

  sed -i \
    -e "s|proxmox-img/proxmox-ve_[^ ]*-auto-from-http-url\.iso|proxmox-img/${PREPARED_ISO}|" \
    -e "s|^menu Welcome to Proxmox VE .*|menu Welcome to Proxmox VE ${VERSION}|" \
    "$BOOT_IPXE"

  echo "PXE artifacts updated to Proxmox VE $VERSION"

# Add ansible, terraform ; layer1 ... recipes
