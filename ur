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
    rm /tmp/urlock
    exit 1
}

function do_notice {
    echo -e "${notice}$*"
}

function do_firstrun {
    do_notice "Checking required assets available."
    do_notice "Reticulating splines."
    do_notice "Checking pyyaml is installed."
    sudo eopkg it -y pyyaml
    # Check evobuild is there.
    if [[ $(eopkg lr | grep unstable | wc -l) -eq 0 ]]
      then
        do_notice "Installing evovbuild for stable repository."
        sudo evobuild init
        sudo evobuild update
      else
        do_notice "Installing evovbuild for unstable repository."
        sudo evobuild init -p unstable-x86_64
        sudo evobuild update -p unstable-x86_64
    fi
    # This just creates the ~/.solus/packager file so ypkg knows who is building.
    do_notice "In order to build packages please enter the following:"
    mkdir -p ~/.solus
    rm ~/.solus/packager
    touch ~/.solus/packager
    read -p "Full Name: " name
    read -p "Email Address: " email
    echo -e "[Packager]" >> ~/.solus/packager
    echo -e "Name=$name" >> ~/.solus/packager
    echo -e "Email=$email"  >> ~/.solus/packager
    do_notice "Settings saved."
    # Check current version
    do_upgradecheck
    if [[ -f /var/db/surt/firstrundone ]];then sudo rm /var/db/surt/firstrundone;fi
    echo "1" > sudo tee -a /var/db/surt/firstrundone
}

function do_upgradecheck {
    do_notice "Checking for new version of User Repsoitory Tool."
    cd /tmp/
    wget -q https://raw.githubusercontent.com/Justinzobel/surt/master/version
    installedversion=$(cat /var/db/surt/version)
    githubversion=$(cat version)
    if [[ $githubvresion -gt $installedversion ]]
        then
            do_notice "New version available, installing."
            sudo wget -q https://raw.githubusercontent.com/Justinzobel/surt/master/ur -O /usr/bin/ur
            sudo chmod +x /usr/bin/ur
            do_notice "Version $githubversion installed."
        else
            do_notice "Version check complete, no new version."
    fi
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

function do_install {
  cd /tmp/ur
  # Check if pkgname blank
  if [[ -z ${1} ]]
    then
      echo -e "${error}No package name specified."
    else
      # Update evobuild
      if [[ -f /var/lib/evobuild/images/main-x86_64.img ]];then sudo evobuild update
        elif [[ -f /var/lib/evobuild/images/main-x86_64.img ]];then sudo evobuild update -p unstable-x86_64
        else
          do_firstrun
      fi      
      # Check packagename is valid against our repo-index
      if [[ $(cat /var/db/surt/repo-index | grep ${package} | wc -l) -eq 0 ]];
        then
          echo -e "${error}Download failed or invalid package name specified."
        else
          # Attempt to get the package.yml from the server
          cd /tmp/ur
          do_notice "Attempting download of ${yellow}${package} ${white}template, this should only take a moment."
          wget -q http://solus-us.tk/ur/$1.yml
          if [[ ! -f $1.yml ]];then echo -e "${error}Download failed or invalid package name specified."
            else
              # Package.yml grabbed, build time.
              mv $1.yml package.yml
              do_notice "Template found, building package."
              if [[ $(inxi -r | grep unstable | wc -l) -eq 1 ]]
                then
                  sudo evobuild build package.yml -p unstable-x86_64
                else
                  sudo evobuild build package.yml
              fi
              # Find out if a build was successful
              if [[ $(find . -type f -iname "*.eopkg" | wc -l) -eq 0 ]];then echo -e "${error}Build failed"
                else
                  do_notice "Build of ${package} successful."
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
                      do_notice "Install aborted, eopkg file(s) for ${yellow}${package} ${white}are in ${yellow}/var/cache/eopkg/packages${white}."
                  fi
              fi
          fi
      fi
  fi
}

function do_listinstalled {
  if [[ -f /tmp/ur/installed ]];then rm /tmp/ur/installed;fi
  do_notice "Installed packages:"
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
        do_notice "Database shows no packages installed."
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
  do_notice "Listing available packages."
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

function print_usage {
  echo -e ""
  echo -e "${yellow}Usage:${white}"
  echo -e "ur first-run (fr) - Re-run the first-run wizard."
  echo -e "ur install (it) - Install a package (specify name)."
  echo -e "ur list-available (la) - List packages available in the user repository."
  echo -e "ur list-installed (li) - List packages installed from the user repository."
  echo -e "ur new-version (nv) - Upgrade to newer UR Tool if available."
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
          do_notice "Removing ${yellow}${package} ${white}from your system."
          sudo eopkg rm ${package}
          sed -i 's/'"${package}"'=1/'"${package}"'=0/g' /var/db/surt/database
        else
          # Get y/n confirmation
          do_notice "Do you wish to remove ${yellow}${package}${white}?"
          read -p "Confirm (y/n) " -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]
              then
                # Do removel of package and update database
                echo ""
                do_notice "Removing ${yellow}${package} ${white}from your system."
                sudo eopkg rm ${package}
                sed -i 's/'"${package}"'=1/'"${package}"'=0/g' /var/db/surt/database
              else
                echo ""
                do_notice "Aborted removal of ${yellow}${package}${white}."
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
      do_notice "Searching for ${yellow}${package}${white}."
      if [[ $(grep -i ${package} /var/db/surt/repo-index | wc -l) -eq 0 ]]
        then
          echo -e "${error}No results for ${yellow}${package}${white}."
        elif [[ $(grep -i ${package} /var/db/surt/repo-index | wc -l) -gt 1 ]]
          then
            # Advise multiple items found
            do_notice "Found ${yellow}$(grep -i ${package} /var/db/surt/repo-index | wc -l) ${white}items:"
            grep -i ${package} /var/db/surt/repo-index > /tmp/ur/searchfound
            while read p;do
              pkg=$(echo $p | cut -d, -f 1)
              ver=$(echo $p | cut -d, -f 2)
              rel=$(echo $p | cut -d, -f 3)
              echo -e "${yellow}Package: ${white}$pkg ${yellow}Version: ${white}${ver} ${yellow}Release: ${white}$rel"
            done </tmp/ur/searchfound
        else
          # Advise singular item found
          do_notice "Found ${yellow}1 ${white}item:"
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
  do_notice "Updating Repository..."
  if [[ ! -d "/var/db/surt" ]]; then
    mkdir -p "/var/db/surt" || do_fail "Unable to create /var/db/surt - check permissions"
  fi
  wget -q http://solus-us.tk/ur/index -O /var/db/surt/repo-index
  do_notice "Repository Updated."
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
      do_notice "No packages found that require upgrade."
    else
      while read $p;do
        do_notice "Upgrading ${yellow}${p}"
        install $p
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
          do_notice "${package} is already up to date, no upgrade needed."
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
        do_notice "Getting package info for ${yellow}${package}${white}."
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
        do_notice "Getting yml template for ${yellow}${package}${white}."
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

# Do lockfile check
if [[ -f /tmp/urlock ]]
  then
    do_fail User Repository Tool already running, only one instanace allowed.
  else
    touch /tmp/urlock
fi

# Check if repo index exists, if not, fetch
if [[ ! -f /var/db/surt/repo-index ]];then do_notice "Repository index not present, fetching.";do_updaterepo
fi

# Check if database exists, if not, create
if [[ ! -f /var/db/surt/database ]];then touch /var/db/surt/database
fi

# Check if this is first run or subsequent
if [[ ! $(cat /var/db/surt/firstrundone) -eq 1 ]];then do_firstrun;fi

arg="${1}"
shift
case "${arg}" in
    install|it)
        require_root
        do_install $*
        ;;
    upgrade|up)
        require_root
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
    first-run|fr)
        do_firstrun $*
        ;;
    new-version|nv)
        do_upgradecheck $*
        ;;
    *)
        print_usage
        ;;
esac

# Remove lock file
rm /tmp/urlock
