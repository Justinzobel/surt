# SURT
Solus User Repository Tool

# Installation

* sudo wget https://raw.githubusercontent.com/Justinzobel/surt/master/ur -O /usr/bin/ur;sudo chmod +x /usr/bin/ur
* sudo mkdir /var/db/surt;sudo chmod ug+rw /var/db/surt

# To Do
* Dependency checking - check if it exists in UR, if it does, advise user and install that first, then proceed with normal install
* Bash completion of commands and package names
* Add a lock file to prevent simultaneous instances (in progress)
