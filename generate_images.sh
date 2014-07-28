#generate image and add to glance
IMAGE=/root/windows-server-2012-r2.qcow2
FLOPPY=/root/Autounattend.vfd
VIRTIO_ISO=/root/windows-openstack-imaging-tools/virtio-win-0.1-81.iso
ISO=/root/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO

echo "creating FLOPPY" 
/root/windows-openstack-imaging-tools/create-autounattend-floppy.sh

KVM=/usr/libexec/qemu-kvm
if [ ! -f "$KVM" ]; then
    KVM=/usr/bin/kvm
fi
echo "creating disk!"
qemu-img create -f qcow2 -o preallocation=metadata $IMAGE 17G
echo "installing windows on disk!"
$KVM -m 2048 -smp 2 -cdrom $ISO -drive file=$VIRTIO_ISO,index=3,media=cdrom -fda $FLOPPY $IMAGE -boot d -vga std -k en-us -vnc :1
echo "adding image to Glance!"
NOW=$(date "+%F.%T")
IMAGEID=`glance image-create --name "winserverR2-"$NOW --disk-format raw --container-format bare --is-public true --file $IMAGE | grep -w id | awk '{print $4}'`
echo "Image added!"
echo $IMAGEID
echo $IMAGEID > /root/latest_image_id
rm -f $IMAGE
rm -f $FLOPPY
