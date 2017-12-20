#!/bin/bash
# ----------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ----------------------------------------------------------------------
# Name.......: setup_odsee.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2017.12.19
# Revision...: 
# Purpose....: Setup script for oracle environment to build docker OUD image 
# Notes......: OUD Base scripts are downloaded from github
# Reference..: --
# License....: CDDL 1.0 + GPL 2.0
# ----------------------------------------------------------------------
# Modified...: 
# see git revision history for more information on changes/updates
# TODO.......: 
# TODO parametize OUD DATA
# ----------------------------------------------------------------------

# Download URL for oud base package
OUDBASE_URL="https://github.com/oehrlis/oudbase/raw/master/build/oudbase_install.sh"
OUDBASE_PKG="oudbase_install.sh"
mkdir -p ${DOWNLOAD}
chmod 777 ${DOWNLOAD}

echo "--- Upgrade OS and install additional Packages ---------------------------------"
# update existing packages
yum upgrade -y

# install basic packages 
yum install -y unzip zip gzip tar hostname which procps-ng libstdc++.i686 glibc.i686 zlib.i686

# remove unwanted locales, the did come in with yum upgrade....
/usr/bin/localedef --list-archive | grep -v -i ^en | xargs /usr/bin/localedef --verbose --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive --verbose

echo "--- Setup Oracle OFA environment -----------------------------------------------"
echo " ORACLE_ROOT=${ORACLE_ROOT}"
echo " ORACLE_DATA=${ORACLE_DATA}"
echo " ORACLE_BASE=${ORACLE_BASE}"
echo ""
echo "--- Create groups for Oracle software"
# create oracle groups
groupadd --gid 1000 oinstall
groupadd --gid 1010 osdba
groupadd --gid 1020 osoper
groupadd --gid 1030 osbackupdba
groupadd --gid 1040 oskmdba
groupadd --gid 1050 osdgdba

echo "--- Create user oracle"
# create oracle user
useradd --create-home --gid oinstall --shell /bin/bash \
    --groups oinstall,osdba,osoper,osbackupdba,osdgdba,oskmdba \
    oracle

echo "--- Create OFA directory structure"
# create oracle directories
mkdir -v -p ${ORACLE_ROOT}

# create base directories
mkdir -v -p ${ORACLE_BASE}
mkdir -v -p ${ORACLE_BASE}/local
mkdir -v -p ${ORACLE_BASE}/product
mkdir -v -p ${ORACLE_DATA}
ln -s ${ORACLE_DATA}/scripts /docker-entrypoint-initdb.d

echo "--- Setup OUD base environment -------------------------------------------------"
# OUD Base package if it does not exist /tmp/download
if [ ! -e ${DOWNLOAD}/${OUDBASE_PKG} ]
then
    echo "--- Download OUD Base package from github "
    curl --cookie-jar ${DOWNLOAD}/cookie-jar.txt \
    --location-trusted ${OUDBASE_URL} -o ${DOWNLOAD}/${OUDBASE_PKG}
else
    echo "--- Use local copy of ${DOWNLOAD}/${OUDBASE_PKG}"
fi

echo "--- Install OUD Base scripts"
# Install OUD Base scripts
chmod 755 ${DOWNLOAD}/${OUDBASE_PKG}
${DOWNLOAD}/${OUDBASE_PKG} -v -b ${ORACLE_BASE} -d ${ORACLE_DATA}

# update profile
PROFILE="/home/oracle/.bash_profile"
echo '# Check OUD_BASE and load if necessary'             >>"${PROFILE}"
echo 'if [ "${OUD_BASE}" = "" ]; then'                    >>"${PROFILE}"
echo '  if [ -f "${HOME}/.OUD_BASE" ]; then'              >>"${PROFILE}"
echo '    . "${HOME}/.OUD_BASE"'                          >>"${PROFILE}"
echo '  else'                                             >>"${PROFILE}"
echo '    echo "ERROR: Could not load ${HOME}/.OUD_BASE"' >>"${PROFILE}"
echo '  fi'                                               >>"${PROFILE}"
echo 'fi'                                                 >>"${PROFILE}"
echo ''                                                   >>"${PROFILE}"
echo '# define an oudenv alias'                           >>"${PROFILE}"
echo 'alias oud=". $(find ${OUD_BASE} -name oudenv.sh)"'  >>"${PROFILE}"
echo ''                                                   >>"${PROFILE}"
echo '# source oud environment'                           >>"${PROFILE}"
echo '. $(find ${OUD_BASE} -name oudenv.sh)'              >>"${PROFILE}"

echo "--- Adjust permissions and remove temporary files ------------------------------"
# make sure that oracle and root has a OUD_BASE
cp /root/.OUD_BASE /home/oracle/.OUD_BASE
# adjust user and group permissions
mkdir -p ${ORACLE_BASE}/product/${ORACLE_HOME_NAME}
chmod a+xr ${ORACLE_ROOT} ${ORACLE_DATA} ${DOCKER_SCRIPTS} /home/oracle/.OUD_BASE
chown oracle:oinstall -R ${ORACLE_BASE} ${ORACLE_DATA} ${DOCKER_SCRIPTS}

# clean up
echo "--- Clean up yum cache and temporary download files ----------------------------"
yum clean all
rm -rf /var/cache/yum
rm -rf ${DOWNLOAD}/*
echo "=== Done runing $0 =================================="