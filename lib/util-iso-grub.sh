#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

prepare_initcpio(){
    msg2 "Copying initcpio ..."
    local dest="$1"
    cp /etc/initcpio/hooks/artix* $dest/etc/initcpio/hooks
    cp /etc/initcpio/install/artix* $dest/etc/initcpio/install
    cp /etc/initcpio/artix_shutdown $dest/etc/initcpio
}

prepare_initramfs(){
    local mnt="$1"
    cp ${DATADIR}/mkinitcpio.conf $mnt/etc/mkinitcpio-artix.conf
    if [[ -n ${gpgkey} ]]; then
        user_run "gpg --export ${gpgkey} >${AT_USERCONFDIR}/gpgkey"
        exec 17<>${AT_USERCONFDIR}/gpgkey
    fi
    local _kernel=$(cat $mnt/usr/lib/modules/*/version)
    ARTIX_GNUPG_FD=${gpgkey:+17} chroot-run $mnt \
        /usr/bin/mkinitcpio -k ${_kernel} \
        -c /etc/mkinitcpio-artix.conf \
        -g /boot/initramfs.img

    if [[ -n ${gpgkey} ]]; then
        exec 17<&-
    fi
    if [[ -f ${AT_USERCONFDIR}/gpgkey ]]; then
        rm ${AT_USERCONFDIR}/gpgkey
    fi
}

prepare_boot_extras(){
    local src="$1" dest="$2"
#     cp $src/boot/intel-ucode.img $dest/intel_ucode.img
#     cp $src/usr/share/licenses/intel-ucode/LICENSE $dest/intel_ucode.LICENSE
    cp $src/boot/memtest86+/memtest.bin $dest/memtest
    cp $src/usr/share/licenses/common/GPL2/license.txt $dest/memtest.COPYING
}

configure_grub(){
    local conf="$1/boot/grub/kernels.cfg"
    sed -e "s|@iso_label@|${iso_label}|" -i $conf
}

prepare_grub(){
    local platform=i386-pc img='core.img' grub=$3/boot/grub efi=$3/efi/boot \
        lib=$1/usr/lib/grub prefix=/boot/grub theme=$2/usr/share/grub

    prepare_dir ${grub}/${platform}

    cp ${theme}/cfg/*.cfg ${grub}

    cp ${lib}/${platform}/* ${grub}/${platform}

    msg2 "Building %s ..." "${img}"

    grub-mkimage -d ${grub}/${platform} -o ${grub}/${platform}/${img} -O ${platform} -p ${prefix} biosdisk iso9660

    cat ${grub}/${platform}/cdboot.img ${grub}/${platform}/${img} > ${grub}/${platform}/eltorito.img

    platform=x86_64-efi
    img=bootx64.efi

    prepare_dir ${efi}
    prepare_dir ${grub}/${platform}

    cp ${lib}/${platform}/* ${grub}/${platform}

    msg2 "Building %s ..." "${img}"

    grub-mkimage -d ${grub}/${platform} -o ${efi}/${img} -O ${platform} -p ${prefix} iso9660

    prepare_dir ${grub}/themes
    cp -r ${theme}/themes/artix ${grub}/themes/
    cp -r ${theme}/{locales,tz} ${grub}

    msg2 "Creating %s ..." "unicode.pf2"
    grub-mkfont -o ${grub}/unicode.pf2 /usr/share/fonts/misc/unifont.bdf

    local size=4M mnt="${mnt_dir}/efiboot" efi_img="$3/efi.img"
    msg2 "Creating fat image of %s ..." "${size}"
    truncate -s ${size} "${efi_img}"
    mkfs.fat -n ARTIX_EFI "${efi_img}" &>/dev/null
    prepare_dir "${mnt}"
    mount_img "${efi_img}" "${mnt}"
    prepare_dir ${mnt}/efi/boot
    msg2 "Building %s ..." "${img}"
    grub-mkimage -d ${grub}/${platform} -o ${mnt}/efi/boot/${img} -O ${platform} -p ${prefix} iso9660
    umount_img "${mnt}"
}
