# OVH coreos setup
This is an example config for an OVH baremetal machine setup.

I did many trials and errors to find the good config for OVH server, it was a good puzzle to solve.

Also i tried to understand [BYOLinux](https://help.ovhcloud.com/csm/en-dedicated-servers-bring-your-own-linux?id=kb_article_view&sysparm_article=KB0061610)/[BYOImage](https://help.ovhcloud.com/csm/en-dedicated-servers-bringyourownimage?id=kb_article_view&sysparm_article=KB0043281), but my knowlege of partition modification and interaction from an iso/raw file is almost non existant. 

So if someone who is smarter than me, have the solution, let me know i'll gladly take it and learn from it!

# Features
- Wireguard Server : To have private access to the server instead of using the public IP. [More Information](https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-configure-wireguard/)
- Firewall NFTable : Pre-defined rules on installation so it doesn't expose only required ports on first boot and then tweak later if needed.
- zincati : predefined maintenance schedule + auto-update setup for less manual maintenance. [More Information](https://docs.fedoraproject.org/en-US/fedora-coreos/auto-updates/)
- SSH hardening: With default settings it's fine, but i never settle for fine, so i added the following tweaks:
    - Dedicated group to have access to SSH to the server
    - Custom SSH port (need to tweak selinux after the first boot, since it's not the standard SSH port)
    - Disable root login

# Requirements
- Dedicated server at OVH
- Access to the kvm/ipmi interface
    - for my case i only had kvm (Java Applet) available since it was a Kimsufi server
        - i personally used [OpenWebStart](https://openwebstart.com/) and installed the java JRE and it works fine

# How To Setup
1. In the Dedicated Server panel in OVH select your new server
2. [Boot in rescue mode](https://help.ovhcloud.com/csm/en-ca-dedicated-servers-ovhcloud-rescue?id=kb_article_view&sysparm_article=KB0030995)
3. Boot the machine from the "Service status" panel
    1. At the "Status" section, Select the 3 dots icon
    2. click "Start"
4. SSH into the machine using the key you setup in the rescue menu (step 2.2.1b)
> [!NOTE]
> i personnaly went with cargo installation, but it came with some hurdles because of missing packages on debian that i had to install bit by bit.
5. Coreos-Installer installation

    1. Build from source 
        1. [Github](https://github.com/coreos/coreos-installer)
        2. [Getting started](https://github.com/coreos/coreos-installer/blob/main/docs/getting-started.md)
        3. Using cargo
            1. run `curl https://sh.rustup.rs -sSf | sh`
            2. press enter for default installation
            3. then run `cargo install coreos-installer`
                1. Each time it fails you need to install what is mentionned in the error (i'll try to redo an installation that will list the required packages soon)
            4. save the "coreos-installer" binary file it generated outside of the server (in case you need to reinstall coreos for some reason)
> [!NOTE]
> Don't take the disk ID with a `_1` at the end take the shortest name
6. ignition/butane file setup
    1. Take the [config.bu](/config.bu) example file and drop it in your text editor
    2. We need to replace the following placeholders (ordered from top to bottom of the file):
        1. `__username__` : Your Username
        2. `__password_hash__`: hash of your password (use `mkpasswd`) ([More Information](https://coreos.github.io/butane/examples/#using-password-authentication))
        3. `__public_key__` : your SSH public key for your `__username__`
        4. `__diskID__` : IDs of your disks (raid 1 with 2 disks in the example) ([More Information](https://coreos.github.io/butane/examples/#mirrored-boot-disk))
            1. example for nvme disks: `ls -l /dev/disk/by-id/ | grep '^.*nvme[[:digit:]][[:alpha:]][[:digit:]]$'`
                example for regular disks: `ls -l /dev/disk/by-id/ | grep '^.*sd[[:alpha:]]$'`
            2. Choose the one with the disk manufacturer name ex:
                intel: nvme-INTEL_SSDPE2MX450G7_CVPF...RGN
            3. Take note of the 2 disks IDs
            4. put those IDs in the follwing sections of the config.bu
                1. `boot_devices.mirror.devices` (line 25)
                2. `storage.disks.device` (line 29 and 35)
        5. `__Hostname__` : hostname for the server
        6. Wireguard setup (optional)
            1. `__server_local_wireguard_ip__`: the ip address the wireguard server will have with the subnet mask (ex: `10.10.10.1/24`)
            2. `__server_private_key__` : the generated server private key
            3. `__peer_public_key__` : the public ip of the peer
            4. `__peer_preshared_key__` : the preshared key for the peer
            5. `__peer_list_of_allowed_subnets__` : peer allowed subnets in the tunnel
    3. Convert the `config.bu` file into an ignition file (`config.ign`) using [butane converter biany](https://github.com/coreos/butane/releases)
        ex: `butane --strict --pretty .\config.bu > config.ign`
    4. Copy the file or file content of `config.ign` to the server via SSH

> [!IMPORTANT]
> Don't forget to change the disk at the end, if needed.

> [!NOTE]
> It can be any of the 2 disks it shouldn't change the installation process since we reconfigure coreos disks for a raid 1.
> CoreOS will move it self in the ram and rewrite the disk it was initially installed on. [More Information](https://docs.fedoraproject.org/en-US/fedora-coreos/storage/)

7. CoreOS Installation
    #_reconfiguring_the_root_filesystem)
    1. Execute the following command: `./coreos-installer install --stream "stable" --platform "metal" --ignition-file config.ign /dev/nvme0n1`
        2. wait until it's done
    2. In the OVH panel switch the rescue mode to local disk (Refer to step 2, if unsure)
        1. (Optional) use the IPMI/Java Applet to check the installation status of CoreOS
    3. reboot the server
8. Wait until it's done configuring the server and enjoy your public CoreOS server!

# Troubleshootings

## The installation of CoreOS failed
1. In IPMI/KVM console
2. Press enter to be in shell mode
3. Check the errors it produced in `journalctl`, it's usually self explanatory.
4. Adjust the `config.bu` to fix the issue if needed.
ex: i tried with luks to encrypt at rest with tpm2, but i didn't know the server didn't come with a tpm2 chip.

Unfortunatly, most of the time a reinstallation is the only solution, since the ignition file is only executed once.

## Reinstalling CoreOS
A good thing to know is to use `wipefs -af /dev/nvme0n1` to wipe each disks and reboot again to be sure to have clean disks and avoir the `device busy, unable to write` issue on installation.

## The installation of CoreOS was a success, but i can't SSH to it
### Custom SSH port is setup
> [!Important]
> You need to have setup the `__password_hash__` from the `config.bu` to be able to correct this.
> You also need to be in the wheel group or be able to install packages with sudo.

This happens because SELinux block the SSHD service from running due to having a non-standard port setup for it.

1. From IPMI/KVM console
2. Login to your setup user
3. Install the semanage python utility: `sudo rpm-ostree install policycoreutils-python-utils`
4. Reboot
5. Execute the following command to add the custom ssh port:
    ```sh
        sudo semanage port -a -t ssh_port_t -p tcp 2022 \
            || sudo semanage port -m -t ssh_port_t -p tcp 2022
        sudo systemctl restart sshd
    ```
6. Verify the port has been properly added to SELinux: `sudo semanage port -l | grep ssh_port_t`
7. Verify the SSHD service has successfully started: `sudo systemctl status sshd.service`
8. You should be able to access the server with the custom SSH port now!