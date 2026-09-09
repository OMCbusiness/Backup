#!/bin/bash
set -o pipefail

if [ "$(date +%Y%m%d)" -ge "20260911" ]; then
    echo "Este script de instalación ha caducado."
    echo "Descarga uno nuevo desde tu Cloud Panel."
    exit 1
fi

acronis_repo="https://cloudpanel.ionos.com/download"
acronis_file="Backup_Agent_for_Linux_x86_64.bin"

echo "== Preparando dependencias de kernel para el módulo de Acronis =="

if which zypper >/dev/null 2>&1; then
    zypper refresh -fdb >/dev/null
    zypper -n in kernel-default kernel-source kernel-default-devel gcc make perl rpm dkms >/dev/null

elif which apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null
    apt-get -y install linux-image-$(uname -r) linux-headers-$(uname -r) gcc make perl rpm dkms >/dev/null

elif which dnf >/dev/null 2>&1; then
    # Rama que faltaba: AlmaLinux / RHEL / Rocky usan dnf, no zypper ni apt-get.
    dnf -y install "kernel-devel-$(uname -r)" "kernel-headers-$(uname -r)" gcc make perl rpm-build elfutils-libelf-devel dkms >/dev/null
    if [ $? -ne 0 ]; then
        echo "AVISO: no se pudo instalar kernel-devel para $(uname -r)."
        echo "Es probable que ese paquete ya no esté en los repos porque el kernel en ejecución"
        echo "quedó desfasado. Actualiza kernel+kernel-devel y REINICIA antes de continuar:"
        echo "    dnf -y update kernel kernel-devel kernel-headers && reboot"
        exit 1
    fi

elif which yum >/dev/null 2>&1; then
    yum -y install "kernel-devel-$(uname -r)" "kernel-headers-$(uname -r)" gcc make perl rpm-build elfutils-libelf-devel dkms >/dev/null
fi

curl -sf "${acronis_repo}/${acronis_file}" -o "/tmp/${acronis_file}" || { echo "Descarga fallida"; exit 1; }
bash "/tmp/${acronis_file}" --auto --token=0AB3-9F36-441A
install_status=$?
rm -f "/tmp/${acronis_file}"

echo "== Comprobando que el módulo de kernel de Acronis cargó correctamente =="
sleep 5
if ! lsmod | grep -qE 'snapapi|file_protector'; then
    echo "############################################################"
    echo "AVISO: el módulo de kernel de Acronis NO está cargado."
    echo "NO reinicies este servidor todavía. Revisa antes:"
    echo "  dkms status"
    echo "  journalctl -xe | grep -i acronis"
    echo "  mokutil --sb-state   (Secure Boot puede bloquear módulos sin firmar)"
    echo "############################################################"
fi

exit $install_status
