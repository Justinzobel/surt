#!/bin/bash
# Solus User Repo Tool by Justin Zobel (justin@solus-project.com)
# License GPL-2.0
# Version 0.4

# Notice and Errors Messages
error="\e[31mError:\e[0m "
notice="\e[93mNotice:\e[0m "
# Colours
red="\e[31m"
yellow="\e[93m"
white="\e[0m"

function do_fail() {
    echo -e "${error}$*"
    exit 1
}

function require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    do_fail "Must be root to use this function"
  fi
}

function addtoupgradelist {
  # Create a list of packages to pass to the upgrader
  pkgname=$1
  release=$2
  version=$3
  oldrel=$4
  oldver=$5
  # Put package names in a list for it to process
  echo $pkgname >> /tmp/ur/doup
  # Create a CSV with package data in it so we can output pretty info
  echo $pkgname,$version,$release,$oldver,$oldrel >> /tmp/ur/uplist
}

function createpackagerfile {
  # This just creates the ~/.solus/packager file so ypkg knows who is building.
  echo -e "${notice}In order to build a package please enter the following:"
  mkdir -p ~/.solus
  touch ~/.solus/packager
  read -p "Full Name: " name
  read -p "Email Address: " email
  echo -e "[Packager]" >> ~/.solus/packager
  echo -e "Name=$name" >> ~/.solus/packager
  echo -e "Email=$email"  >> ~/.solus/packager
  echo -e "${notice}Settings saved."
}

function do_install {
  cd /tmp/ur
  # Check if pkgname blank
  if [[ -z ${1} ]]
    then
      echo -e "${error}No package name specified."
    else
      # Check packagename is valid against our repo-index
      if [[ $(cat /var/db/surt/repo-index | grep ${package} | wc -l) -eq 0 ]];
        then
          echo -e "${error}Download failed or invalid package name specified."
        else
          # Attempt to get the package.yml from the server
          cd /tmp/ur
          echo -e "${notice}Attempting download of ${yellow}${package} ${white}template, this should only take a moment."
          wget -q http://solus-us.tk/ur/$1.yml
          if [[ ! -f $1.yml ]];then echo -e "${error}Download failed or invalid package name specified."
            else
              # Package.yml grabbed, build time.
              mv $1.yml package.yml
              echo -e "${notice}Template found, building package."
              ypkg package.yml
              # Find out if a build was successful
              if [[ $(find . -type f -iname "*.eopkg" | wc -l) -eq 0 ]];then echo -e "${error}Build failed"
                else
                  echo -e "${notice}Build of ${package} successful."
                  read -p "Install to your system? (y/n) " -n 1 -r
                  if [[ $REPLY =~ ^[Yy]$ ]]
                    then
                      # Do the install via eopkg
                      echo ""
                      sudo eopkg it *.eopkg
                      sudo mv *.eopkg /var/cache/eopkg/packages/
                      # Tell DB installed
                      if [[ $(grep ${package} /var/db/surt/database | wc -l) -eq 0 ]];then
                        echo ${package}=1 >> /var/db/surt/database
                      else
                        # Update DB from not-installed to installed
                        sed -i 's/'"${package}"'=0/'"${package}"'=1/g' /var/db/surt/database
                      fi
                    else
                      # Install aborted, move packages to cache.
                      echo ""
                      sudo mv *.eopkg /var/cache/eopkg/packages/
                      echo -e "${notice}Install aborted, eopkg file(s) for ${yellow}${package} ${white}are in ${yellow}/var/cache/eopkg/packages${white}."
                  fi
              fi
          fi
      fi
  fi
}

function do_listinstalled {
  if [[ -f /tmp/ur/installed ]];then rm /tmp/ur/installed;fi
  echo -e "${notice}Installed packages:"
  # Check what packages are installed from the database
  while read p; do
      if [[ $(echo $p | cut -d= -f 2) == 1 ]];
        then 
          echo $(echo $p | cut -d= -f 1) >> /tmp/ur/installed
      fi
    done </var/db/surt/database
    # Check if any packages installed
    if [ ! -f /tmp/ur/installed ];
      then
        echo -e "${notice}Database shows no packages installed."
      else
        echo -e "There are ${yellow}$(cat /tmp/ur/installed | wc -l) ${white}package(s) installed."
        while read p;do
          pkg=$(grep $p /var/db/surt/repo-index | cut -d, -f 1)
          ver=$(grep $p /var/db/surt/repo-index | cut -d, -f 2)
          rel=$(grep $p /var/db/surt/repo-index | cut -d, -f 3)
          echo -e ${yellow}Package: ${white}$pkg ${yellow}Version: ${white}${ver} ${yellow}Release: ${white}$rel
        done </tmp/ur/installed
    fi
}

function do_listavailable {
  # List packages that are available from the User Repo
  echo -e "${notice}Listing available packages."
  echo ""
  echo -e "There are ${yellow}$(cat /var/db/surt/repo-index | wc -l) ${white}packages available:"
  # Get name and version out
  while read p;do
    pkg=$(grep $p /var/db/surt/repo-index | cut -d, -f 1)
    ver=$(grep $p /var/db/surt/repo-index | cut -d, -f 2)
    rel=$(grep $p /var/db/surt/repo-index | cut -d, -f 3)
    echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}${ver} ${yellow}Release: ${white}$rel"
  done </var/db/surt/repo-index
}

function get_systemdevel {
  # Ensure system.devel installed and up to date.
  echo -e "${notice}Ensuring development tools are installed and up to date."
  sudo eopkg it -c system.devel -y
}

function print_usage {
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
  echo -e "ur viewyml (vy) - View the raw YML template of a package in the repository (specify name)"
  echo -e ""
  echo -e "${yellow}Examples:${white}"
  echo -e "ur install dfc"
  echo -e "ur up pantheon-photos"
}

function do_remove {
  # Check if pkgname is blank
  if [[ ${package} == "" ]];then echo -e "${error}No package name specified."
    else
      if [[ $confirm == "-y" ]]
        then
          # Remove package from system without y/n confirmation
          echo -e "${notice}Removing ${yellow}${package} ${white}from your system."
          sudo eopkg rm ${package}
          sed -i 's/'"${package}"'=1/'"${package}"'=0/g' /var/db/surt/database
        else
          # Get y/n confirmation
          echo -e "${notice}Do you wish to remove ${yellow}${package}${white}?"
          read -p "Confirm (y/n) " -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
              then
                # Do removel of package and update database
                echo ""
                echo -e "${notice}Removing ${yellow}${package} ${white}from your system."
                sudo eopkg rm ${package}
                sed -i 's/'"${package}"'=1/'"${package}"'=0/g' /var/db/surt/database
              else
                echo ""
                echo -e "${notice}Aborted removal of ${yellow}${package}${white}."
            fi
      fi
  fi
}

function do_search {
  # Check if search term provided
  if [[ ${package} == "" ]];
    then
      echo -e "${error}No search term provided."
    else
      echo -e "${notice}Searching for ${yellow}${package}${white}."
      if [[ $(grep -i ${package} /var/db/surt/repo-index | wc -l) -eq 0 ]]
        then
          echo -e "${error}No results for ${yellow}${package}${white}."
        elif [[ $(grep -i ${package} /var/db/surt/repo-index | wc -l) -gt 1 ]]
          then
            # Advise multiple items found
            echo -e "${notice}Found ${yellow}$(grep -i ${package} /var/db/surt/repo-index | wc -l) ${white}items:"
            grep -i ${package} /var/db/surt/repo-index > /tmp/ur/searchfound
            while read p;do
              pkg=$(echo $p | cut -d, -f 1)
              ver=$(echo $p | cut -d, -f 2)
              rel=$(echo $p | cut -d, -f 3)
              echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}${ver} ${yellow}Release: ${white}$rel"
            done </tmp/ur/searchfound
        else
          # Advise singular item found
          echo -e "${notice}Found ${yellow}1 ${white}item:"
          grep -i ${package} /var/db/surt/repo-index > /tmp/ur/searchfound
          while read p;do
            pkg=$(echo $p | cut -d, -f 1)
            ver=$(echo $p | cut -d, -f 2)
            rel=$(echo $p | cut -d, -f 3)
            echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}${ver} ${yellow}Release: ${white}$rel"
          done </tmp/ur/searchfound
      fi
  fi
}

function do_updaterepo {
  require_root
  # Update repo database from server to local disk.
  echo -e "${notice}Updating Repository..."
  if [[ ! -d "/var/db/surt" ]]; then
    mkdir -p "/var/db/surt" || do_fail "Unable to create /var/db/surt - check permissions"
  fi
  wget -q http://solus-us.tk/ur/index -O /var/db/surt/repo-index
  echo -e "${notice}Repository Updated."
}

function do_upgrade {
  # Firstly update the repo index so we have the right info
  do_updaterepo
  # Check if we're upgrading all or one specific package, or all with skipyn
  if [[ ${package} == "-y" ]] || [[ ${package} == "" ]]
    then upgrademultiple
    else upgradesingle
  fi
}

function upgrademultiple {
  # Get installed packages into /tmp/ur/installed
  grep "=1" /var/db/surt/database | sed 's/=1//g' > /tmp/ur/installed
  # Find if a new release is in repo and annoucce version diff
  while read $p;do
    newver=$(grep $p /var/db/surt/repo-index | cut -d, -f 2)
    newrel=$(grep $p /var/db/surt/repo-index | cut -d, -f 3)
    installedrelease=$(eopkg info $p | grep Name | cut -d: -f 4 | sed 's/ //g')
    installedversion=$(eopkg info $p | grep Name | cut -d: -f 3 | cut -d, -f 1 | sed 's/ //g')
    if [[ $newrel -gt $installedrelease ]]
      then
        echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}$oldver ${yellow}Release: ${white}$oldrel to be upgraded to ${yellow}Version: ${white}$ver ${yellow}Release: ${white}$rel"
        echo $p >> /tmp/ur/upgradethese
    fi
  done </tmp/ur/installed
  # Upgrade those suckers
  if [[ ! -f /tmp/ur/upgradethese ]]
    then
      echo -e "${notice}No packages found that require upgrade."
    else
      while read $p;do
        echo -e "${notice}Upgrading ${yellow}${p}"
        install $P
      done </tmp/ur/upgradethese
  fi
}

function upgradesingle {
  if [[ $(cat /var/db/surt/repo-index | grep ${package} | wc -l) -eq 0 ]]
    then
      echo -e "${error}}${package} not found."
    else
      newver=$(cat /var/db/surt/repo-index | grep ${package} | cut -d, -f 2)
      newrel=$(cat /var/db/surt/repo-index | grep ${package} | cut -d, -f 3)
      installedrelease=$(eopkg info ${package} | grep Name | cut -d: -f 4 | sed 's/ //g')
      installedversion=$(eopkg info ${package} | grep Name | cut -d: -f 3 | cut -d, -f 1 | sed 's/ //g')
      if [[ $installedrelease -ge $newrel ]]
        then
          echo -e "${notice}${package} is already up to date, no upgrade needed."
        else
          echo "${yellow}${package} ${white}will be updated to version ${yellow}$newver${white}, release number ${yellow}$newrel"
          install ${package}
      fi
  fi
}

function do_viewinfo {
  if [[ ${package} == "" ]]
    then
      echo -e "${error}No package name supplied."
    else
      if [[ $(cat /var/db/surt/repo-index | grep ${package} | wc -l) -eq 0 ]]
        then echo -e "${error}Package ${yellow}${package} ${white}not found in database."
      else
        echo -e "${notice}Getting package info for ${yellow}${package}${white}."
        cd /tmp/ur
        wget -q http://solus-us.tk/ur/${package}.yml
        if [[ -f ${package}.yml ]]
          then
            name=$(head -n1 ${package}.yml | grep name | cut -d: -f 2 | sed 's/ //g')
            version=$(head -n2 ${package}.yml | grep version | cut -d: -f 2 | sed 's/ //g')
            release=$(head -n3 ${package}.yml | grep release | cut -d: -f 2 | sed 's/ //g')
            summary=$(cat ${package}.yml | grep "summary   " | cut -d: -f 2 | sed 's/: //g')
            echo -e "${yellow}Name: ${white}$name"
            echo -e "${yellow}Version: ${white}$version"
            echo -e "${yellow}Release: ${white}$release"
            echo -e "${yellow}Summary:${white}$summary"
        fi
      fi
  fi
}

function do_viewyml {
  if [[ ${package} == "" ]]
    then
      echo -e "${error}No package name supplied."
    else
      if [[ $(cat /var/db/surt/repo-index | grep ${package} | wc -l) -eq 0 ]]
        then echo -e "${error}}Package ${yellow}${package} ${white}not found in database."
      else
        echo -e "${notice}Getting yml template for ${yellow}${package}${white}."
        cd /tmp/ur
        wget -q http://solus-us.tk/ur/${package}.yml
        if [[ -f ${package}.yml ]]
          then
            cat ${package}.yml
            echo ""
        fi
      fi
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
if [[ ! -f /var/db/surt/repo-index ]];then echo -e "${notice}Repository index not present, fetching.";do_updaterepo
fi

# Check if database exists if not create
if [[ ! -f /var/db/surt/database ]];then touch /var/db/surt/database
fi

arg="${1}"
shift
case "${arg}" in
    install|it)
        require_root
        get_systemdevel
        do_install $*
        ;;
    upgrade|up)
        require_root
        get_systemdevel
        do_upgrade $*
        ;;
    search|sr)
        do_search $*
        ;;
    viewinfo|vi)
        do_viewinfo $*
        ;;
    viewyml|vy)
        do_viewyml $*
        ;;
    remove|rm)
        require_root
        do_remove $*
        ;;
    update-repo|ur)
        do_updaterepo $*
        ;;
    list-available|la)
        do_listavailable $*
        ;;
    list-installed|li)
        do_listinstalled $*
        ;;
    *)
        print_usage
        ;;
esac
