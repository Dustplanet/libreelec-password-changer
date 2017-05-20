#!/bin/sh
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                               #
#    Tested with openELEC v4.0.6, v4.2.1, v5.0.8 and v6.0.0     #
#    Tested with LibreELEC v7.90.002                            #
#                                                               #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# author: Tim "xGhOsTkiLLeRx" Brust
# license: MIT
# version: 0.4.11
# date: 05/20/2017
# description: replace (root) password of squashfs from openELEC or LibreELEC
# usage: ./openELEC [password] [device] [hash] [user]
# dependencies: ((python && pip && passlib) || mkpasswd), squashfs-tools
#
#
# THIS SCRIPT COMES WITH ZERO WARRANTY!
# I'M NOT RESPONSIBLE FOR ANY POTENTIAL DATA LOSS!
# ALWAYS CREATE BACKUPS!

# Configure colors, if available.
if [ -x /usr/bin/tput ] && tput setaf 1 >/dev/null 2>&1
  then
    reset="$(/usr/bin/tput sgr 0)"
    green="$(/usr/bin/tput bold)$(/usr/bin/tput setaf 2)"
    red="$(/usr/bin/tput bold)$(/usr/bin/tput setaf 1)"
    yellow="$(/usr/bin/tput bold)$(/usr/bin/tput setaf 3)"
  else
    reset=
    green=
    red=
    yellow=
fi

# Functions
cleanUp() {
  rm -rf /openelec
}

message() {
  printf "%b$reset\n" "$1"
}

unmount() {
  if [ "$mac" = false ]
    then
      umount /openelec/flash
    else
      diskutil unmountDisk /openelec/flash
  fi
}

checkCommand() {
  if [ "$?" != 0 ]
    then
      message "${red}The last command did not succeed. Aborting..."
      exit 2
  fi
}

cdFailed() {
  message "${red}The cd command failed. Aborting..."
  exit 1
}

# root check
if [ "$(id -u)" != 0 ]
  then
    message "${red}Please run this script as root"
    exit 1
fi

# Check if we are running on macOS
if [ "$(uname)" = "Darwin" ]
  then
    mac=true
  else
    mac=false
fi

# python check
if command -v "mkpasswd" > /dev/null 2>&1
  then
    mkpasswd=true
  else
    if ! command -v "python" > /dev/null 2>&1 || ! command -v "pip" > /dev/null 2>&1 || [ -z "$(pip show passlib)" ]
      then
        message "${red}Please install the package $yellow'python'$red, $yellow'pip'$red and $yellow'passlib'$red from https://passlib.readthedocs.io/en/stable/"
        exit 1
      else
        mkpasswd=false
    fi
fi

# mksquashfs check
if ! command -v "mksquashfs" > /dev/null 2>&1
  then
    if [ "$mac" = true ]
      then
        message "${red}Please install the package $yellow'squashfs'$red from Homebrew"
      else
        message "${red}Please install the package $yellow'squashfs-tools'$red to use mksquashfs"
    fi
    exit 1
fi

# Ask if we are using BerryBoot
message "${red}Are you using BerryBoot? (y/N) $reset"
read -r berryboot
case "$berryboot" in
  No|no|N|n|"")
    berryboot=false
    ;;
  *)
    berryboot=true
    ;;
esac

# Check for password
if [ -z "$1" ]
  then
    message "${yellow}No arguments given, please feed me input!\n"
    message "Please enter the password you want to use: "
    read -r passwd
  else
    passwd=$1
fi

# Check for device
if [ -z "$2" ]
  then
    message "Please specify the openELEC/LibreELEC device (e.g. sdb1 or disk2s1 for macOS): "
    read -r device
  else
    device=$2
fi

# Check for hash
if [ ! -z "$3" ]
  then
    hash=$3
  else
    hash="sha-512"
fi

# Check for user
if [ ! -z "$4" ]
  then
    user=$4
  else
    user="root"
fi

# Warning, better safe than sorry
message "${red}This script comes with zero warranty! Always backup your files! I'm not responsible for any data loss or damage!"

# Summary
message "${yellow}Will use the following password: $passwd"
message "${yellow}Will use the following device: $device \n"

# Check for permission
message "Are these information correct? (y/N) "
read -r continue
case "$continue" in
  No|no|N|n|"")
    message "${red}Aborting!"
    exit 1
    ;;
  *)
    message "${green}Let's rock!\n"
    ;;
esac

# Ask if we should remove old folders
message "Should a backup file be created in /openelec_backup ? (Y/n) "
read -r backup
case "$backup" in
  Yes|y|Y|yes|"")
    message "${yellow}Will make a backup of the current image!"
    backup=true
    ;;
  *)
    message "${green}Backup of current image will be skipped"
    remove=false
    ;;
esac

if [ ! -d /openelec_backup ]
  then
    mkdir /openelec_backup
fi

# Ask if we should remove old folders
message "Should the /openelec folders be removed after updating the password? (y/N) "
read -r remove
case "$remove" in
  No|no|N|n|"")
    message "${yellow}Old folders won't be removed!"
    remove=false
    ;;
  *)
    message "${green}Old folders will be removed"
    remove=true
    ;;
esac

# Remove folder
cd / || cdFailed
if [ -d /openelec ]
  then
    message "${yellow}Found existing /openelec folder"
    if [ "$remove" = true ]
      then
        message "${yellow}Removing..."
        cleanUp
        message "${green}Done"
      else
        message "${yellow}You specified that old folder should not be removed."
        message "${yellow}Please do this yourself now. Aborting..."
        exit 1
    fi
fi

# Setup
message "${yellow}Making folders..."
mkdir /openelec
cd /openelec || cdFailed
mkdir flash newsquashfs
message "${green}Done\n"

# mount and copy squashfs
message "${yellow}Mounting openELEC/LibreELEC squashfs system..."

if [ "$mac" = false ]
  then
    mount /dev/"$device" /openelec/flash
  else
    if [ "$berryboot" = true ]
      then
        mount -t fuse-ext2 /dev/"$device" /openelec/flash
      else
        diskutil unmountDisk /dev/"$device"
        mount -t msdos /dev/"$device" /openelec/flash
    fi
fi

checkCommand

# set default filename
filename="SYSTEM"

if [ "$berryboot" = true ]
  then
    message "Listing the available files:"
    ls /openelec/flash/images/
    message "Please specify the openELEC/LibreELEC file: "
    read -r filename
    # See if file exists
    if [ ! -f /openelec/flash/images/"$filename" ]
      then
        message "${red}Whoops, your $filename file is not there! Please check"
        message "${red}Leaving $device mounted!"
        exit 1
    fi
    dest=/openelec/flash/images/"$filename"
    unsquashfs -d /openelec/original /openelec/flash/images/"$filename"
  else
    # See if SYSTEM exists
    if [ ! -f /openelec/flash/"$filename" ]
      then
        message "${red}Whoops, your $filename file is not there! Please check"
        message "${red}Leaving $device mounted!"
        exit 1
    fi
    dest=/openelec/flash/"$filename"
    unsquashfs -d /openelec/original /openelec/flash/"$filename"
fi

checkCommand
message "${green}Done\n"

# Make a backup
message "${yellow}Making a backup..."
if [ "$backup" = true ]
  then
    # Unique pseudo timestamp
    date=$(date +"%Y%m%d-%T")
    cp "$dest" /openelec_backup/"$date"-"$filename"
fi

checkCommand
message "${green}Done\n"

# Create new password
message "${yellow}Generating a new password (SHA512, random salt)..."

if [ "$mkpasswd" = false ]
  then
    message "${yellow}Using python for password generation"
    shadow_password=$(python -c "from passlib.hash import sha512_crypt; print sha512_crypt.encrypt('$passwd')")
  else
    salt=$(head -30 /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    shadow_password=$(mkpasswd "$passwd" --salt="$salt" --method="$hash")
fi

checkCommand
message "${green}Done\n"

# Backup
message "${yellow}Making backup from /etc/shadow and replace password..."
cd /openelec/original/etc || cdFailed
mv shadow shadow.bak

# Replace second string for given user (default is root)
awk -v pw="$shadow_password" -F: 'BEGIN{OFS=":"}/'$user'/{gsub(/.*/,pw,$2)}1' shadow.bak > shadow
checkCommand
message "${green}Done\n"
# sed way
#sed -i.bak "/^$user:/ s/:[^:]*/:$shadow_password"

# Make new squashfs and unmount
message "${yellow}Making new squashfs, this might take a bit..."
mksquashfs /openelec/original/ /openelec/newsquashfs/"$filename"
checkCommand
message "${green}Done\n"

# Copy updated squashfs back
message "${yellow}Copying updated file back..."
cp /openelec/newsquashfs/"$filename" "$dest"

message "${green}Done\n"

# Clean
message "${yellow}Unmounting openelec flash and original again..."
unmount
if [ "$remove" = true ]
  then
    message "${yellow}Removing openelec folder again..."
    cleanUp
    message "${green}Done\n\n"
fi

message "${green}Your password was successfully updated. Please (unmount and) remove your device"

exit 0
