title: Archlinux Hibernate
date: 2018-06-05
tags:
- arch
- linux
- hibernate
---


# 修改swap partition/file size

image_size的容量用于控制休眠的时候内存dump到swap的最大大小，设置成0不受大小限制

```
sudo tee /sys/power/image_size <<< 0
```

image_size重启后会被恢复，可以采用

```
su - root -c 'echo "w /sys/power/image_size - - - - 0" > /etc/tmpfiles.d/modify_power_image_size.conf'
```

# 修改grub2

在文件`/etc/grub.d/40_custom`添加下面内容

```
menuentry 'My Arch Linux' {
        load_video
        set gfxpayload=keep
        insmod gzio
        insmod part_gpt
        insmod xfs
        set root='hd0,gpt2'
        if [ x$feature_platform_search_hint = xy ]; then
          search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gpt2 --hint-efi=hd0,gpt2 --hint-baremetal=ahci0,gpt2  cda52f03-ea43-44dd-bf62-6defe65cc765
        else
          search --no-floppy --fs-uuid --set=root cda52f03-ea43-44dd-bf62-6defe65cc765
        fi
        echo    'Loading Linux linux ...'
        linux   /vmlinuz-linux root=UUID=412d830c-e11e-44b4-abb9-3b59f885b803 rw quiet resume=/dev/sda5
        echo    'Loading initial ramdisk ...'
        initrd  /initramfs-linux.img
}
```

其中增加了resume参数，该参数指定了swap所在分区，如果不清楚swap是哪个分区可以使用`lsblk`查看

将配置信息独立在40_custom的好处是不破坏其他默认配置文件和原有启动菜单

grub配置信息每台机器不一样，建议从`/boot/grub/grub.cfg`复制出对应的菜单进行修改

生成grub.cfg

```
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

# 修改mkinitcpio.conf

在`/etc/mkinitcpio.conf`的HOOKS中增加`resume`

```
HOOKS=(base udev autodetect modconf block resume filesystems keyboard fsck)
```

`resume`最好增加在`filesystems`前面

生成initramfs

```
sudo mkinitcpio -p linux
```

# 测试休眠

使用systemctl进入休眠

```
systemctl hibernate
```

命令执行后等待电脑关机，关机后使用电源键选择增加的grub菜单进行启动即可恢复原有环境

# 参考

[Power management/Suspend and hibernate](https://wiki.archlinux.org/index.php/Power_management/Suspend_and_hibernate#Hibernation)
[Linux GRUB2: How to resume from hibernation?](https://superuser.com/questions/383140/linux-grub2-how-to-resume-from-hibernation)
[Archlinux休眠设置](http://www.cnblogs.com/xiaozhang9/p/6443478.html)
