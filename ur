#!/bin/bash
# Solus User Repo Tool by Justin Zobel (justin@solus-project.com)
# License GPL-2.0
# Version 0.2

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
    else echo "Incorrect syntax.";printhelp
  fi
}

function createpackagerfile {
  echo "In order to build a package please enter the following:"
  mkdir -p ~/.solus
  touch ~/.solus/packager
  read -p "Full Name: " name
  read -p "Email Address: " email
  echo "[Packager]" >> ~/.solus/packager
  echo "Name=$name" >> ~/.solus/packager
  echo "Email=$email"  >> ~/.solus/packager
  echo "Settings saved."
}

function install {
  if [[ $(cat /usr/share/solus-user-repo/repo-index | grep $1 | wc -l) -eq 0 ]];
    then
      echo "Download failed or invalid package name specified."
    else
      cd /tmp/ur
      echo "Attempting template download, this should only take a moment."
      wget -q http://solus-us.tk/ur/$1.yml
      mv $1.yml package.yml
      echo "Building package."
      ypkg package.yml
      if [[ $(find . -type f -iname "*.eopkg" | wc -l) -eq 0 ]];then echo "Build failed"
        else
            read -p "Build successful, install $package? (y/n)" -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
              # Do the install via eopkg
              sudo eopkg it *.eopkg
            fi
          sudo eopkg it *.eopkg
      # Tell DB installed
      if [[ $(grep $package /usr/share/solus-user-repo/database | wc -l) -eq 0 ]];then
        echo $package=1 >> /usr/share/solus-user-repo/database
      else
        sed -i 's/'"$package"'=0/'"$package"'=1/g' /usr/share/solus-user-repo/database
      fi
    fi
fi
}

function listinstalled {
  rm /tmp/ur/installed
  echo "Installed packages:"
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
        echo "Database shows no packages installed."
      else
        cat /tmp/ur/installed
    fi
}

function listpackages {
  echo "Listing available packages."
  cat /usr/share/solus-user-repo/repo-index | more
}

function printhelp {
  echo ""
  echo Usage:
  echo "ur install (it) - Install a package (specify name)."
  echo "ur list-available (la) - List packages available in the user repository."
  echo "ur list-installed (li) - List packages installed from the user repository."
  echo "ur remove (rm) - Remove an installed package (specify name)."
  echo "ur search (sr) - Search the user repository for a package (specify name)."
  echo "ur update-repo (ur) - Update repository information"
  echo "ur upgrade (up) - Upgrade a package (specify name) or all (no value specified)."
  echo "ur viewinfo (vi) - View information on a package in the repository (specify name)"
  echo ""
  echo "Examples:"
  echo "ur install dfc"
  echo "ur up pantheon-photos"
}

function remove {
  if [[ $package == "" ]];then echo "No package name specified."
    else
      if [[ $confirm == "-y" ]]
        then
          echo "Removing $package from your system."
          sudo eopkg rm $package
          sed -i 's/'"$package"'=1/'"$package"'=0/g' /usr/share/solus-user-repo/database
        else
          read -p "Do you wish to remove $package? (y/n)" -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
              then
                echo "Removing $package from your system."
                sudo eopkg rm $package
                sed -i 's/'"$package"'=1/'"$package"'=0/g' /usr/share/solus-user-repo/database
            fi
      fi
  fi
}

function search {
  if [[ $package == "" ]];then echo "No search term provided."
  else
  echo "Searching for $package."
    if [[ $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) -eq 0 ]];then echo "No results for $package."
      elif [[ $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) -gt 1 ]];then echo "Found $(grep -i $package /usr/share/solus-user-repo/repo-index | wc -l) items:";grep -i $package /usr/share/solus-user-repo/repo-index
      else echo "Found 1 item:";grep -i $package /usr/share/solus-user-repo/repo-index
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
    echo "Checking what packages need upgrading."
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
        # Do version checks against packages
        while read a; do
          cd /tmp/ur
          wget -q http://solus-us.tk/ur/$a.yml
          newver=$(cat $a.yml | grep version | cut -d: -f 2 | sed 's/ //g')
          inver=$(eopkg info $a | grep Name | cut -d: -f 3 | cut -d, -f 1 | sed 's/ //g')
          if [[ $(vercomp $inver $newver) -eq 1 ]];then echo $a >> /tmp/ur/doup
          fi
          echo 
        done </tmp/ur/upgrades
        echo "Upgrade checks done."
        # Check if any were found that were higher version
        if [ -f /tmp/ur/doup ];
          then
            echo "The following packages will be upgraded:"
            cat /tmp/ur/doup | sort
            # Check for skipyn
            if [[ $package == "-y" ]];then
              # Do the upgrades
              while read b; do
                installpackage $b
              done </tmp/ur/doup
            else
            read -p "Do you wish to proceed? (y/n)" -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
              # Do the upgrades
              while read b; do
                installpackage $b
              done </tmp/ur/doup
            fi
          fi
          else
            echo "No packages need upgrading."
        fi
      else
        echo "No packages need upgrading."
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
      read -p "Do you wish to proceed? (y/n)" -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]
          then
            installpackage $package
        fi
  fi
fi
}

# Taken from http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format by Dennis Williamson http://stackoverflow.com/users/26428/dennis-williamson
function vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

function viewpackage {
  echo "Getting package info for $package"
  cd /tmp/ur
  wget -q http://solus-us.tk/ur/$package.yml
  cat $package.yml
  echo ""
}

# Warning message
echo -e "\e[31m*** \e[0mAll items in the Solus User Repo are used at your own risk. \e[31m***"
echo -e "\e[31m*** \e[0mTemplates are created by Solus users and have NOT been tested! \e[31m***\e[0m"

# Variables
package=$2
action=$1
confirm=$3

# Confirm work dir exists, if not create
if [[ ! -d /tmp/ur ]]; then mkdir -p /tmp/ur
fi
# Remove any leftover files
rm -rf /tmp/ur/*

# YPKG File Checker
if [[ ! -d ~/.solus ]];then createpackagerfile
fi

# Check if repo index exists
if [[ ! -f /usr/share/solus-user-repo/repo-index ]];then echo "Repository index not present, fetching.";updaterepo
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
