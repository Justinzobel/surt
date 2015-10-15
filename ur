#!/bin/bash
# Solus User Repo Tool by Justin Zobel (justin@solus-project.com)
# License GPL-2.0
# Version 0.3

# Colours
red="\e[31m"
white="\e[0m"
yellow="\e[93m"

#Functions
function actions {
  if [ $1 == "install" ] || [ $1 == "it" ];then install $package
    elif [ $1 == "upgrade" ] || [ $1 == "up" ]; then upgrade $package
    elif [ $1 == "search" ] || [ $1 == "sr" ]; then search $package
    elif [ $1 == "viewinfo" ] || [ $1 == "vi" ]; then viewpackage $package
    elif [ $1 == "remove" ] || [ $1 == "rm" ];then remove $package
    elif [ $1 == "update-repo" ] || [ $1 == "ur" ];then updaterepo $package
    elif [ $1 == "list-available" ] || [ $1 == "la" ]; then listpackages
    elif [ $1 == "list-installed" ] || [ $1 == "li" ]; then listinstalled
    else echo -e "${red}Error: ${white}Incorrect syntax.";printhelp
  fi
}

function addtoupgradelist {
  pkgname=$1
  release=$2
  version=$3
  oldrel=$4
  oldver=$5
  # Put package names in a list for it to process
  echo $pkgname >> /tmp/ur/doup
  # Create a CSV with package data in it
  echo $pkgname,$version,$release,$oldver,$oldrel >> /tmp/ur/uplist
}

function createpackagerfile {
  echo -e "${yellow}Notice: ${white}In order to build a package please enter the following:"
  mkdir -p ~/.solus
  touch ~/.solus/packager
  read -p "Full Name: " name
  read -p "Email Address: " email
  echo -e "[Packager]" >> ~/.solus/packager
  echo -e "Name=$name" >> ~/.solus/packager
  echo -e "Email=$email"  >> ~/.solus/packager
  echo -e "${yellow}Notice: ${white}Settings saved."
}

function install {
  if [[ $package == "" ]]
    then
      echo -e "${red}Error: ${white}No package name specified."
    else
      if [[ $(cat /usr/share/solus-user-repo/repo-index | grep $package | wc -l) -eq 0 ]];
        then
          echo -e "${red}Error: ${white}Download failed or invalid package name specified."
        else
          cd /tmp/ur
          echo -e "${yellow}Notice: ${white}Attempting template download, this should only take a moment."
          wget -q http://solus-us.tk/ur/$1.yml
          mv $1.yml package.yml
          echo -e "${yellow}Notice: ${white}Template found, building package."
          ypkg package.yml
          if [[ $(find . -type f -iname "*.eopkg" | wc -l) -eq 0 ]];then echo -e "${red}Error: ${white}Build failed"
            else
                echo -e "${yellow}Notice: ${white}Build of $package successful."
                read -p "Install to your system? (y/n) " -n 1 -r
                if [[ $REPLY =~ ^[Yy]$ ]]
                then
                  # Do the install via eopkg
                  echo ""
                  sudo eopkg it *.eopkg
                else
                  cp /tmp/ur/*.eopkg ~
                  echo ""
                  echo -e "${yellow}Notice: ${white}Install aborted, eopkg file(s) are in your home directory."
                fi
          # Tell DB installed
          if [[ $(grep $package /usr/share/solus-user-repo/database | wc -l) -eq 0 ]];then
            echo $package=1 >> /usr/share/solus-user-repo/database
          else
            sed -i 's/'"$package"'=0/'"$package"'=1/g' /usr/share/solus-user-repo/database
          fi
        fi
    fi
  fi
}

function listinstalled {
  if [[ -f /tmp/ur/installed ]];then rm /tmp/ur/installed;fi
  echo -e "${yellow}Notice: ${white}Installed packages:"
  # Check what packages are installed from the database
  while read p; do
      if [[ $(echo $p | cut -d= -f 2) == 1 ]];
        then 
          echo $(echo $p | cut -d= -f 1) >> /tmp/ur/installed
      fi
    done </usr/share/solus-user-repo/database
    # Check if any packages installed
    if [ ! -f /tmp/ur/installed ];
      then
        echo -e "${yellow}Notice: ${white}Database shows no packages installed."
      else
        cat /tmp/ur/installed
    fi
}

function listpackages {
  echo -e "${yellow}Notice: ${white}Listing available packages."
  cat /usr/share/solus-user-repo/repo-index | more
}

function printhelp {
  echo -e ""
  echo -e "${yellow}Usage:${white}"
  echo -e "ur install (it) - Install a package (specify name)."
  echo -e "ur list-available (la) - List packages available in the user repository."
  echo -e "ur list-installed (li) - List packages installed from the user repository."
  echo -e "ur remove (rm) - Remove an installed package (specify name)."
  echo -e "ur search (sr) - Search the user repository for a package (specify name)."
  echo -e "ur update-repo (ur) - Update repository information"
  echo -e "ur upgrade (up) - Upgrade a package (specify name) or all (no value specified)."
  echo -e "ur viewinfo (vi) - View information on a package in the repository (specify name)"
  echo -e ""
  echo -e "${yellow}Examples:${white}"
  echo -e "ur install dfc"
  echo -e "ur up pantheon-photos"
}

function remove {
  if [[ $package == "" ]];then echo -e "${red}Error: ${white}No package name specified."
    else
      if [[ $confirm == "-y" ]]
        then
          echo -e "${yellow}Notice: ${white}Removing $package from your system."
          sudo eopkg rm $package
          sed -i 's/'"$package"'=1/'"$package"'=0/g' /usr/share/solus-user-repo/database
        else
          echo -e "${yellow}Notice: ${white}Do you wish to remove $package?"
          read -p "Confirm (y/n) " -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
              then
                echo ""
                echo -e "${yellow}Notice: ${white}Removing $package from your system."
                sudo eopkg rm $package
                sed -i 's/'"$package"'=1/'"$package"'=0/g' /usr/share/solus-user-repo/database
            fi
      fi
  fi
}

function search {
  if [[ $package == "" ]];then echo -e "${red}Error: ${white}No search term provided."
  else
  echo -e "${yellow}Notice: ${white}Searching for $package."
    if [[ $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) -eq 0 ]];then echo -e "${red}Error: ${white}No results for $package."
      elif [[ $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) -gt 1 ]];then echo -e "${yellow}Notice: ${white}Found $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) items:";grep -i $package /usr/share/solus-user-repo/repo-index
      else echo -e "${yellow}Notice: ${white}Found 1 item:";grep -i $package /usr/share/solus-user-repo/repo-index
    fi
  fi
}

function updaterepo {
  wget -q http://solus-us.tk/ur/index -O /usr/share/solus-user-repo/repo-index
  echo Repository Database Updated.
}

function upgrade {
  # Check if we're upgrading all or one specific package, or all with skipyn
  if [[ $package == "-y" ]] || [[ $package == "" ]];then
    echo -e "${yellow}Notice: ${white}Checking what packages need upgrading."
    # Check what packages are installed
    while read p; do
      if [[ $(echo $p | cut -d= -f 2) == 1 ]];
        then 
          echo $(echo $p | cut -d= -f 1) >> /tmp/ur/upgrades
      fi
    done </usr/share/solus-user-repo/database
    # Check if anything found
    if [ -f /tmp/ur/upgrades ];
      then
        # Do release number checks against packages
        while read a; do
          cd /tmp/ur
          wget -q http://solus-us.tk/ur/$a.yml
          reporelease=$(cat $a.yml | grep release | cut -d: -f 2 | sed 's/ //g')
          repoversion=$(cat $a.yml | grep version | cut -d: -f 2 | sed 's/ //g')
          installedrelease=$(eopkg info $a | grep Name | cut -d: -f 4 | sed 's/ //g')
          installedversion=$(eopkg info $a | grep Name | cut -d: -f 3 | cut -d, -f 1 | sed 's/ //g')
          if [[ $reporelease -gt $installedrelease ]]
            then addtoupgradelist $a $reporelease $repoversion $installedrelease $installedversion
          fi
          echo 
        done </tmp/ur/upgrades
        echo -e "${yellow}Notice: ${white}Upgrade checks done."
        # Check if any were found that were higher version
        if [ -f /tmp/ur/doup ];
          then
            echo -e "${yellow}Notice: ${white}The following package(s) will be upgraded:"
            # Do a fancy upgrade list here
            while read m; do
              #do stuff to $m
              pkg=$(echo $m | cut -d, -f 1)
              ver=$(echo $m | cut -d, -f 2)
              rel=$(echo $m | cut -d, -f 3)
              oldver=$(echo $m | cut -d, -f 4)
              oldrel=$(echo $m | cut -d, -f 5)
              echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}$oldver ${yellow}Release: ${white}$oldrel to be upgraded to ${yellow}Version: ${white}$ver ${yellow}Release: ${white}$rel"
            done </tmp/ur/urlist
            # Check for skipyn
            if [[ $package == "-y" ]];then
              # Do the upgrades
              while read b; do
                installpackage $b
              done </tmp/ur/doup
            else
            read -p "Do you wish to proceed? (y/n) " -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
              # Do the upgrades
              while read b; do
                installpackage $b
              done </tmp/ur/doup
            fi
          fi
          else
            echo -e "${yellow}Notice: ${white}No packages need upgrading."
        fi
      else
        echo -e "${yellow}Notice: ${white}No packages need upgrading."
    fi
  else
    # Single package upgrade, package name specified
    cd /tmp/ur
    wget -q http://solus-us.tk/ur/$package.yml
    newversion=$(cat $package.yml | grep version | cut -d: -f 2 | sed 's/ //g')
    # Confirmation
    if [[ $skipyn == "1" ]];
      then installpackage $package
    else
      echo -e "${yellow}Notice: ${white}Package built."
      read -p "Do you wish to proceed? (y/n) " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]
          then
            installpackage $package
        fi
  fi
fi
}

function viewpackage {
  if [[ $package == "" ]]
    then
      echo -e "${red}Error: ${white}No package name supplied."
    else
      echo -e "${yellow}Notice: ${white}Getting package info for $package"
      cd /tmp/ur
      wget -q http://solus-us.tk/ur/$package.yml
      cat $package.yml
      echo -e ""
  fi
}

# Variables
package=$2
action=$1
confirm=$3

# Warning message
echo -e "${red}Warning:${white}"
echo -e "* All items in the Solus User Repo are used at your own risk."
echo -e "* Templates are created by Solus users and have NOT been tested."

# Confirm work dir exists, if not create
if [[ ! -d /tmp/ur ]]; then mkdir -p /tmp/ur
fi
# Remove any leftover files
rm -rf /tmp/ur/*

# YPKG File Checker
if [[ ! -d ~/.solus ]];then createpackagerfile
fi

# Check if repo index exists
if [[ ! -f /usr/share/solus-user-repo/repo-index ]];then echo -e "${yellow}Notice: ${white}Repository index not present, fetching.";updaterepo
fi

# Check if database exists if not create
if [[ ! -f /usr/share/solus-user-repo/database ]];then touch /usr/share/solus-user-repo/database
fi

# Check if we're skipping all y/n prompts
if [[ $confirm == "-y" ]];
  then skipyn=1
fi

if [[ $1 == "" ]];then printhelp
  else actions $1
fi
