#! /bin/bash
##################################################
##             SaltStack Installer              ##
##                Version 1.2.0                 ##
##################################################
##               skyneo13@gmail.com             ##
## https://github.com/Skyneo/salt-installer.git ##
##################################################

# variables
confFile=salt.conf
gitFileJson=gitformula.json
gitFileJsonCustom=customGitFormula.json

titleMsg="mycompany SaltStack Installer"
configMsg="mycompany SaltStack Installer Configuration"

# default valuses
#Git link with project to Deploy
gitProject="http://git.mycompany.sk/monko/dsi-demo-project.git"

# repositories
el7repo="https://repo.saltstack.com/yum/redhat/salt-repo-latest-1.el7.noarch.rpm"
el6repo="https://repo.saltstack.com/yum/redhat/salt-repo-latest-1.el6.noarch.rpm"

#default Variables for downloading salt formulas from git
gitNameSpace="saltstack"
gitBasePath="http://git.mycompany.sk/"
gitSearchParam="salt-formula"

#global variables
envSalt=()
status="0"
saltBaseDir="/opt/salt"
fileRoot="/etc/salt/master.d/file_roots.conf"

#Salt install variables (no modifications required)
ssh_pass_is=$(yum list installed sshpass &>/dev/null && echo 1 || echo 0)
rsync_is=$(yum list installed rsync &>/dev/null && echo 1 || echo 0)
os_ver=$(grep "7" /etc/system-release | wc -l)

# functions
saltWriteEnvStatus(){
  mkdir /opt/salt
  echo "SaltStack installed `date`" > /opt/salt/saltinstall.info
  echo "SaltStack version:" >> /opt/salt/saltinstall.info
  saltVersionsX="$(salt "*" cmd.run "salt-call --version"; echo x)"
  saltVersions="${saltVersionsX%x}"
  echo "$saltVersions" >> /opt/salt/saltinstall.info
  echo "saltMasterEnv=$saltMaster" > /opt/salt/saltenv.info
  echo "saltMinionsEnv=(${saltMinions[@]})" >> /opt/salt/saltenv.info
}
clearSaltCache(){
 {
 systemctl stop salt-master
 rm -rf /var/cache/salt/*
 systemctl start salt-master
 for i in "${saltMinions[@]}"
 do
   sshRun="/usr/bin/sshpass -p $ssh_pass ssh -y -T -o StrictHostKeyChecking=no root@$i"

$sshRun 'bash -s' <<'ENDSSH'
systemctl stop salt-minion
rm -rf /var/cache/salt/*
systemctl start salt-minion
ENDSSH

 done
 } | whiptail --ok-button Done --msgbox "Cache cleared on all hosts" 22 50
}
getFormulaListFromApi() {
source $confFile


if [ -s "$gitFileJsonCustom" ];
then
cp $gitFileJsonCustom $gitFileJson
else
curl -k -s "${BASE_PATH}api/v3/projects?private_token=$gitToken" \
| jq --compact-output ".[] |select(.namespace.name == \"$NAMESPACE\") | { "path": .path, "git": .http_url_to_repo ,"branch": .default_branch}" > "$gitFileJson"
fi

}

waitForMinions() {
  {
  	for ((i=0; i<=100; i+=5)); do
  		sleep 5
  		echo $i
  	done
  } | whiptail --gauge "Waiting for minions" 6 60 0
  salt-key -A -y
}
saltShowStatus() {
  saltKeysStatusX="$(salt-key; echo x)"
  saltKeysStatus="${saltKeysStatusX%x}"
  saltPingX="$(salt "*" test.ping; echo x)"
  saltPing="${saltPingX%x}"
  saltVersionsX="$(salt "*" cmd.run "salt-call --version"; echo x)"
  saltVersions="${saltVersionsX%x}"
  whiptail --ok-button Done --msgbox "Salt keys status:\n$saltKeysStatus \n************************\nSalt minions:\n$saltPing\n************************\nSalt version:\n$saltVersions\n" --scrolltext 22 50
}
# install salt stack on servers function ------------------------------------------------------------------------------
installSaltStackOnServers(){
  {
    echo XXX
    echo 15
    echo "Installing wget"
    yum install wget -y >> SaltInstall.log 2>&1
    sleep 1
    echo XXX

    echo XXX
    echo 35
    echo "Enabling EPEL repos"
    #enable epel repo
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -q >> SaltInstall.log 2>&1
    rpm -Uvh epel-release-latest-7*.rpm >> SaltInstall.log 2>&1
    rm epel-release-latest-7*.rpm >> SaltInstall.log 2>&1
    sleep 2
    echo XXX

    echo XXX
    echo 50
    echo "Installing jQuery"
    #install jq
    yum install jq -y >> SaltInstall.log 2>&1
    sleep 1
    echo XXX

    echo XXX
    echo 65
    echo "Installing sshpass"
    #install sshpass
    if [[ $ssh_pass_is == 0 ]]; then
    	if [[ $os_ver == 1 ]]; then
    	        yum -y localinstall sshpass/sshpass-1.05-5.el7.x86_64.rpm >> SaltInstall.log 2>&1
              echo $os_ver
    	else
            	yum -y localinstall sshpass/sshpass-1.05-1.el6.x86_64.rpm >> SaltInstall.log 2>&1
              echo $os_ver
    	fi
    fi
    sleep 1
    echo XXX

    echo XXX
    echo 90
    echo "Installing rsync"
    #install rsync
    if [[ $ssh_pass_is == 0 ]]; then
    	yum -y install rsync >> SaltInstall.log 2>&1
      echo $ssh_pass_is
    fi
    sleep 1
    echo XXX

    echo XXX
    echo 100
    echo "All packages installed"
    echo XXX

    sleep 3
  } | whiptail --gauge "Setting enviroment and installing prerequisities. Please wait:" 6 80 0
  # ***** saltmaster *********************************************************************************************************************
  #Install salt master
  {
  server_ip=$saltMaster
  sshRun="/usr/bin/sshpass -p $ssh_pass ssh -y -T -o StrictHostKeyChecking=no root@$server_ip"

    echo XXX
    echo 5
    echo "Updating system. This will take a while....."
      #$sshRun yum update >> SaltInstall.log
    sleep 5
    echo XXX

    echo XXX
    echo 35
    echo "Instaling SaltStack repo"
      if [[ $os_ver == 1 ]]; then
        $sshRun yum -y install $el7repo >> SaltInstall.log 2>&1
        echo "$os_ver"  >> SaltInstall.log
      else
        $sshRun yum -y install $el6repo >> SaltInstall.log 2>&1
        echo "$os_ver"  >> SaltInstall.log
      fi
    sleep 2
    echo XXX

    echo XXX
    echo 45
    echo "Configuring firewall"
      if [[ $os_ver == 1 ]]; then
        $sshRun firewall-cmd --add-port=4505-4506/tcp --permanent
        $sshRun firewall-cmd --reload
        echo "$os_ver"
      else
        $sshRun lokkit -p 4505:tcp -p 4506:tcp
        echo "$os_ver"
      fi
    sleep 2
    echo XXX

    echo XXX
    echo 55
    echo "Installing files"
      $sshRun yum -y install salt-master >> SaltInstall.log 2>&1
      sleep 2
    echo XXX

    echo XXX
    echo 75
    echo "Generating key for master"
      /usr/bin/sshpass -p $ssh_pass ssh -y -T -o StrictHostKeyChecking=no root@$server_ip 'sed -i -e "/hash_type:/c\hash_type: sha256" /etc/salt/master'
    sleep 2
    echo XXX

    echo XXX
    echo 75
    echo "Creating service and starting Salt master "
      if [[ $os_ver == 1 ]]; then
        $sshRun systemctl enable salt-master.service
        $sshRun systemctl restart salt-master.service
    echo "$os_ver"
      else
        $sshRun chkconfig salt-master on
        $sshRun service salt-master restart
    echo "$os_ver"
      fi
    sleep 2
    echo XXX

    echo XXX
    echo 100
    echo "Salt master installed on $server_ip"
    echo "`date` Salt master installed on $server_ip" >> SaltInstall.log 2>&1
    echo XXX

    sleep 3
  # Install salt-master end
  } | whiptail --gauge "Instaling Salt master on server $saltMaster" 6 80 0
  # ***** minions *********************************************************************************************************************
    for i in "${saltMinions[@]}"
    do
      server_ip=$i
      {
      server_ip=$i
      sshRun="/usr/bin/sshpass -p $ssh_pass ssh -y -T -o StrictHostKeyChecking=no root@$server_ip"
      echo XXX
      echo 5
      echo "Installing rsync"
        /usr/bin/sshpass -p $ssh_pass ssh -y -o StrictHostKeyChecking=no root@$server_ip yum -y install rsync  >> SaltInstall.log 2>&1
      sleep 2
      echo XXX

      echo XXX
      echo 10
      echo "Updating system. This will take a while....."
#        $sshRun yum update
      sleep 5
      echo XXX

      echo XXX
      echo 40
      echo "Instaling SaltStack repo"
        if [[ $os_ver == 1 ]]; then
          $sshRun yum -y install $el7repo >> SaltInstall.log 2>&1
          echo "$os_ver" >> SaltInstall.log
        else
          $sshRun yum -y install $el6repo >> SaltInstall.log 2>&1
          echo "$os_ver" >> SaltInstall.log
        fi
      sleep 2
      echo XXX

      echo XXX
      echo 50
      echo "Installing files"
        $sshRun yum -y install salt-minion >> SaltInstall.log 2>&1
        sleep 2
      echo XXX

      echo XXX
      echo 65
      echo "Generating key for minion"
        $sshRun 'sed -i -e "/hash_type:/c\hash_type: sha256" /etc/salt/minion'
      sleep 2
      echo XXX

      echo XXX
      echo 75
      echo "Configuring Salt minion "
$sshRun ARG1=$saltMaster ARG2=$i 'bash -s' <<'ENDSSH'
echo "id: $ARG2" > /etc/salt/minion.d/minion.conf
echo "master: $ARG1" >> /etc/salt/minion.d/minion.conf
ENDSSH
      sleep 2
      echo XXX

      echo XXX
      echo 80
      echo "Creating service and starting Salt minion "
        if [[ $os_ver == 1 ]]; then
          $sshRun systemctl enable salt-minion.service
          $sshRun systemctl restart salt-minion.service
      echo "$os_ver"
        else
          $sshRun chkconfig salt-minion on
          $sshRun service salt-minion restart
      echo "$os_ver"
        fi
      sleep 2
      echo XXX

      echo XXX
      echo 100
      echo "Salt minion installed on $server_ip"
      echo "`date` Salt minion installed on $server_ip" >> SaltInstall.log 2>&1
      echo XXX

      sleep 3
    } | whiptail --gauge "Installing Salt minion on server $i" 6 80 0
    done
}

# create salt envireoment function ---------------------------------------------------------------------------------
createSaltEnviroment() {
 {
echo XXX
echo 5
echo "Creating conf files"
echo "`date` Creating conf files" >> SaltInstall.log
echo XXX

echo "pillar_roots:" > /etc/salt/master.d/pillar_roots.conf
echo "file_roots:" > /etc/salt/master.d/file_roots.conf

createSaltDirs() {
  echo "Creating $1"
  envToCreate=`echo "$1" | awk '{print tolower($0)}'`
  echo "Creating $envToCreate"
  mkdir -v -p /opt/salt/$envToCreate/states
  mkdir -v -p /opt/salt/$envToCreate/pillars
  mkdir -v -p /opt/salt/$envToCreate/formulas
  mkdir -v -p /opt/salt/$envToCreate/artifacts/files

  echo "  $envToCreate:" >> /etc/salt/master.d/pillar_roots.conf
  echo "    - /opt/salt/$envToCreate/pillars" >> /etc/salt/master.d/pillar_roots.conf

  echo "  $envToCreate:" >> /etc/salt/master.d/file_roots.conf
  echo "    - /opt/salt/$envToCreate/states" >> /etc/salt/master.d/file_roots.conf
  echo "    - /opt/salt/$envToCreate/artifacts" >> /etc/salt/master.d/file_roots.conf

}
sleep 1

echo XXX
echo 25
echo "Creating directories"
echo XXX

for e in "${saltEnvs[@]}"
do
  createSaltDirs $e
done

sleep 1

echo XXX
echo 80
echo "Making symlinks and aliases"
echo XXX

ln -s /etc/salt /opt/salt/conf >> SaltInstall.log 2>&1
ln -s /var/log/salt /opt/salt/logs >> SaltInstall.log 2>&1

sleep 1

if grep "saltlog" ~/.bashrc > /dev/null
then
  echo "Aliases already there"
else
  echo "alias saltlog='cd /var/log/salt'" >> ~/.bashrc
  echo "alias saltconf='cd /etc/salt'" >> ~/.bashrc
fi

echo XXX
echo 100
echo "All done"
echo XXX

source ~/.bashrc

sleep 2

  } | whiptail --gauge "Creating SalStack directory structure and configuring master server. Please wait:" 6 80 0
}

# downaload project function -----------------------------------------------------------
downloadProject() {
  {

if [ -s "$confFile" ]; then
source $confFile
fi

SPLITED=`echo $1 | cut -d'/' -f5 `
projectName=`echo $SPLITED | cut -d'.' -f1`
#echo "$1 // ${saltEnvs[@]}" > project.info
  echo XXX
  echo 5
  echo "Cloning $1 ( $1 )"
  echo XXX
  git clone "$1" --quiet
  sleep 1
  echo XXX
  echo "Distributing project $projectName"
  echo XXX
  sleep 1
  if [ -s "$projectName/envs.list" ]
  then
    source $projectName/envs.list
    lineNumber=${#saltEnvs[@]}
    z=$((70 / lineNumber))
    $bar=30

    for e in "${saltEnvs[@]}"
    do

      envLow=`echo "$e" | awk '{print tolower($0)}'`
      bar=$(expr $bar + $z)

cat <<EOF
XXX
$bar
Distributing to $e ($saltBaseDir/$envLow)...
XXX
EOF

#echo "$projectName // $saltBaseDir  //  $envLow" >> project.info
      cp -vr $projectName/pillars/* $saltBaseDir/$envLow/pillars
      cp -vr $projectName/states/* $saltBaseDir/$envLow/states
      cp -r $projectName/artifacts/* $saltBaseDir/$envLow/artifacts

      sleep 1
    done
  else
    lineNumber=${#saltEnvs[@]}
    z=$((70 / lineNumber))
    bar=30

    for e in "${saltEnvs[@]}"
    do
      envLow=`echo "$e" | awk '{print tolower($0)}'`
      bar=$(expr $bar + $z)
cat <<EOF
XXX
$bar
Distributing to $e ($saltBaseDir/$envLow)...
XXX
EOF

#echo "$projectName // $saltBaseDir  //  $envLow" > project.info

      cp -vr $projectName/pillars/* $saltBaseDir/$envLow/pillars
      cp -vr $projectName/states/* $saltBaseDir/$envLow/states
      cp -r $projectName/artifacts/* $saltBaseDir/$envLow/artifacts

      sleep 1
    done
  fi
  rm -rf ./$projectName
  service salt-master restart >> SaltInstall.log 2>&1
  echo XXX
  echo 100
  echo "All done"
  echo XXX
  sleep 2
  } | whiptail --gauge "Downloading deployment project:" 6 80 0
}

# dowload formulas -------------------------------
getFormulasFromGit(){
  {

  echo XXX
  echo 5
  echo "Getting formula list from Git"
  echo XXX

  getFormulaListFromApi

  sleep 1
  bar=5

  for e in "${saltEnvs[@]}"
  do
  envLow=`echo "$e" | awk '{print tolower($0)}'`

  lineNumber=${#saltEnvs[@]}
  z=$((95 / lineNumber))
  bar=$(expr $bar + $z)
  echo XXX
  echo $bar
  echo XXX

  #formulaNumbers=`wc -l < $gitFileJson`
  #echo $formulaNumbers

  while read repo; do

    gitFormulaName=$(echo "$repo" | jq -r ".path")
    gitFormulaUrl=$(echo "$repo" | jq -r ".git")

    httpsTrue=`echo $gitFormulaUrl | cut -d':' -f1 `
    gitFormulaUrlHttps=`echo "$gitFormulaUrl" | sed 's/./&smonko:valIno12@/8'`

    lineToMatch="  $envLow:"

  if [ "$httpsTrue" == "https" ]; then
  gitFormulaUrlDownload=$gitFormulaUrlHttps
  else
  gitFormulaUrlDownload=$gitFormulaUrl
  fi

  if [[ ${FORMULA_LIST[@]} ]]; then
    if [[ " ${FORMULA_LIST[*]} " == *" $gitFormulaName "* ]]; then
      if [ -d "$saltBaseDir/$envLow/formulas/$gitFormulaName" ]; then
        echo XXX
        echo "Pulling $gitFormulaName ( $gitFormulaUrl ) to $saltBaseDir/$envLow/formulas/$gitFormulaName"
        echo XXX
        cd $saltBaseDir/$envLow/formulas/$gitFormulaName && git pull --quiet && cd -
      else
        echo XXX
        echo "Cloning $gitFormulaName ( $gitFormulaUrl ) to $saltBaseDir/$envLow/formulas/$gitFormulaName"
        echo XXX
        git clone $gitFormulaUrlDownload $saltBaseDir/$envLow/formulas/$gitFormulaName --quiet
        newFormula="    - /opt/salt/$envLow/formulas/$gitFormulaName"
        sed -i -e "/^$lineToMatch$/a"$'\\\n'"$newFormula"$'\n' "$fileRoot"
      fi
    fi
  else
    if [[ "$gitFormulaName" == *"$PROJECT_SEARCH_PARAM"* ]]; then
      if [ -d "$saltBaseDir/$envLow/formulas/$gitFormulaName" ]; then
        echo XXX
        echo "Pulling $gitFormulaName ( $gitFormulaUrl ) to $saltBaseDir/$envLow/formulas/$gitFormulaName"
        echo XXX
        cd $saltBaseDir/$envLow/formulas/$gitFormulaName && git pull --quiet && cd -
      else
        echo XXX
        echo "Cloning $gitFormulaName ( $gitFormulaUrl ) to $saltBaseDir/$envLow/formulas/$gitFormulaName"
        echo XXX
        git clone $gitFormulaUrlDownload $saltBaseDir/$envLow/formulas/$gitFormulaName --quiet
        newFormula="    - /opt/salt/$envLow/formulas/$gitFormulaName"
        sed -i -e "/^$lineToMatch$/a"$'\\\n'"$newFormula"$'\n' "$fileRoot"
      fi
    fi
  fi

  done < "$gitFileJson"

  done
  service salt-master restart >> SaltInstall.log 2>&1
  echo XXX
  echo 100
  echo "All done"
  echo XXX
  sleep 2

  } | whiptail --gauge "Downloading formulas from GIT:" 6 80 0
}

restartInstaller() {
installer=`basename "$0"`
bash $installer 1
exit
}

configVerifyShow() {
if [ -s "$confFile" ]
then
  source $confFile
  minions=${saltMinions[@]}
  envs=${saltEnvs[@]}

  whiptail --title "${titleMsg}" --msgbox "Setting for current SaltStack installation: \n
  SSH Password: $ssh_pass

  GIT Username: $gitUser
  GIT token: $gitToken
  GIT Project URL: $gitProject

  GIT Formulas: Download from ($BASE_PATH) in ($NAMESPACE) namespace with search parameter ($PROJECT_SEARCH_PARAM)

  SALT Master host: $saltMaster
  SALT Minion host/s: $minions

  ENVIROMENTS To create: $envs


  If this is incorrect run Configuration again" --ok-button Done 0 0
else
  whiptail --title "${titleMsg}" --msgbox "Configuration file $confFile doesn't exist. Run Configuration first" 0 0
fi
}

#if [ "$rerun" -eq 1 ]; then
if [ -n "$1" ]; then
 # do nothing :D
 echo "" > /dev/null
else
whiptail --msgbox "        Welcome to\n${titleMsg}" 0 0
fi

# main code

while [ "$status" -eq 0 ]
do

choice=$(whiptail --title "${titleMsg}" --menu "Select action" 16 120 8 \
        "Configure" "configure all variables for installation" \
        "Install" "select type of installation" \
        "Utilities" "few utilities to manage Salt installation" \
        "Config check" "verify installation settings" \
        "Salt status" "display state of existing SaltStack installation" \
        "Help" "SaltStack installation for dummies" 3>&2 2>&1 1>&3)

# Change to lower case and remove spaces.
option=$(echo $choice | tr '[:upper:]' '[:lower:]' | sed 's/ //g')

  case "${option}" in
# ************ configure *******************************************************************************************************************
    configure)
    if [ -s "$confFile" ]
    then
      whiptail --title "${configMsg}" --yesno "Configuration file (${confFile}) already exist. Overwrite?" 8 78
      exitstatus=$?
      if [ $exitstatus = 1 ]; then
        restartInstaller
      fi
    fi
      SSHPASS=$(whiptail --passwordbox "Enter password for host ssh" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "#Password for connecting to all salthosts" > $confFile
        echo -e "ssh_pass=\"$SSHPASS\"" >> $confFile
      else
        restartInstaller
      fi
      GITUSER=$(whiptail --inputbox "Git user" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "\n" >> $confFile
        echo -e "#Settings for connection to Git" >> $confFile
        echo -e "gitUser=\"$GITUSER\"" >> $confFile
      else
        restartInstaller
      fi
      GITTOKEN=$(whiptail --passwordbox "Git access token" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "gitToken=\"$GITTOKEN\"" >> $confFile
      else
        restartInstaller
      fi
      GITPROJECT=$(whiptail --inputbox "Git deployment project URL" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "\n" >> $confFile
        echo -e "#Git link with project to Deploy" >> $confFile
        echo -e "gitProject=\"$GITPROJECT\"" >> $confFile
      else
        restartInstaller
      fi
      GITNAMESPACE=$(whiptail --inputbox "Git formulas namespace (default: ${gitNameSpace})" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "\n" >> $confFile
        echo -e "#Variables for downloading salt formulas from git" >> $confFile
        if [ -n "$GITNAMESPACE" ]; then
          echo -e "NAMESPACE=\"$GITNAMESPACE\"" >> $confFile
        else
          echo -e "NAMESPACE=\"$gitNameSpace\"" >> $confFile
        fi
      else
        restartInstaller
      fi
      GITBASE=$(whiptail --inputbox "Git formulas base URL (default: ${gitBasePath})" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        if [ -n "$GITBASE" ]; then
          echo -e "BASE_PATH=\"$GITBASE\"" >> $confFile
        else
          echo -e "BASE_PATH=\"$gitBasePath\"" >> $confFile
        fi
      else
        restartInstaller
      fi
      GITSEARCH=$(whiptail --inputbox "Git formula filter (default: ${gitSearchParam})" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        if [ -n "$GITSEARCH" ]; then
          echo -e "PROJECT_SEARCH_PARAM=\"$GITSEARCH\"" >> $confFile
        else
          echo -e "PROJECT_SEARCH_PARAM=\"$gitSearchParam\"" >> $confFile
        fi
      else
        restartInstaller
      fi
      SALTMASTER=$(whiptail --inputbox "Salt master host (IP,Hostname) (* only 1 master supported atm)" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "\n" >> $confFile
        echo -e "#Salt host (only 1 master supported atm)" >> $confFile
        echo -e "saltMaster=\"$SALTMASTER\"" >> $confFile
      else
        restartInstaller
      fi
      SALTMINIONS=$(whiptail --inputbox "Salt minions hosts (IP,Hostname) (multiple host separate by 'space') " 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo -e "\n" >> $confFile
        echo -e "saltMinions=($SALTMINIONS)" >> $confFile
      else
        restartInstaller
      fi
      whiptail --title "${configMsg}" --checklist --separate-output "Select enviroments to create (if noneselected DEV is default)" 20 78 8 \
      "DEV" "" on \
      "TEST" "" off \
      "PILOT" "" off \
      "PROD" "" off 2>results

      while read choice
      do
              case $choice in
                      DEV) envSalt=("${envSalt[@]}" "DEV")
                      ;;
                      TEST) envSalt=("${envSalt[@]}" "TEST")
                      ;;
                      PILOT) envSalt=("${envSalt[@]}" "PILOT")
                      ;;
      		            PROD) envSalt=("${envSalt[@]}" "PROD")
      		            ;;
                      *) restartInstaller
                      ;;
              esac
      done < results

      #echo ${envSalt[@]}

      if [[ ${envSalt[@]} ]]; then
        echo -e "\n" >> $confFile
        echo -e "#Salt envs to create" >> $confFile
        echo -e "saltEnvs=(${envSalt[@]})" >> $confFile
      else
        echo -e "\n" >> $confFile
        echo -e "#Salt envs to create" >> $confFile
        echo -e "saltEnvs=(DEV)" >> $confFile
      fi
      whiptail --msgbox "Configuration DONE. ${confFile} created." 0 0
      configVerifyShow
    ;;
# ************ configure *******************************************************************************************************************
# ************ install *********************************************************************************************************************
    install)
      statusInstall=0
      if [ -s /opt/salt/saltinstall.info ]
      then
        saltInstalledDate=`cat /opt/salt/saltinstall.info`
        whiptail --msgbox "SaltStack is already installed on this server. Be aware!\n\n$saltInstalledDate" --scrolltext 0 0
      fi
      while [ "$statusInstall" -eq 0 ]
      do
      choice=$(whiptail --title "${titleMsg}" --menu "Select type of installation" 16 120 5 \
              "Full installation" "install all on master and minions, download formulas and project" \
              "Software only" "install prerequisities and salt packages on master and minions" \
              "Software and enviroment" "install all on master and minions, create enviroments" 3>&2 2>&1 1>&3)
      # Change to lower case and remove spaces.
      option=$(echo $choice | tr '[:upper:]' '[:lower:]' | sed 's/ //g')

          case "${option}" in
          fullinstallation)
            if [ -s "$confFile" ]
            then
              source $confFile
              # will install prerequisities and software using funciton
              installSaltStackOnServers
              # now give some time for minions to get up
              waitForMinions
              # crete enviroment structure
              createSaltEnviroment
              # downaload project
              downloadProject $gitProject
              # download formulas
              getFormulasFromGit
              # make stamp that salt is installed
              saltWriteEnvStatus
              saltShowStatus
            else
              whiptail --msgbox "Configuration file $confFile doesn't exist. Run Configuration first" 0 0
            fi
          ;;

          softwareonly)
          #echo "SaltStack software only"
            if [ -s "$confFile" ]
            then
              source $confFile
              # will install prerequisities and software using funciton
              installSaltStackOnServers
              # now give some time for minions to get up
              waitForMinions
              # make stamp that salt is installed
              saltWriteEnvStatus
              saltShowStatus
            else
              whiptail --msgbox "Configuration file $confFile doesn't exist. Run Configuration first" 0 0
            fi
          ;;

          softwareandenviroment)
            #echo "SaltStack software and enviroment"
            if [ -s "$confFile" ]
            then
              source $confFile
              # will install prerequisities and software using funciton
              installSaltStackOnServers
              # now give some time for minions to get up
              waitForMinions
              # crete enviroment structure
              createSaltEnviroment
              # make stamp that salt is installed
              saltWriteEnvStatus
              saltShowStatus
            else
              whiptail --msgbox "Configuration file $confFile doesn't exist. Run Configuration first" 0 0
            fi
          ;;

          *) statusInstall=1
          ;;
        esac
      done
      ;;
# ************ install *********************************************************************************************************************
# ************ utilities *********************************************************************************************************************
    utilities)
      statusUtilities=0
      while [ "$statusUtilities" -eq 0 ]
      do
        choice=$(whiptail --title "${titleMsg}" --menu "Select utility to use" 16 120 5 \
                "Update formulas" "download current version of formulas from git" \
                "Deploy project" "download project and make it ready to deployment" \
                "Clear cache" "on all Salt hosts" 3>&2 2>&1 1>&3)
                # Change to lower case and remove spaces.
        option=$(echo $choice | tr '[:upper:]' '[:lower:]' | sed 's/ //g')

        case "${option}" in
          updateformulas)
            # download formulas
            getFormulasFromGit
          ;;
          deployproject)
            DEPLOYPROJECTURL=$(whiptail --inputbox "Git deployment project URL" 8 78 --title "${configMsg}" 3>&1 1>&2 2>&3)
            exitstatus=$?
            if [ $exitstatus = 0 ]; then
              # downaload project
              downloadProject $DEPLOYPROJECTURL
            else
              restartInstaller
            fi

          ;;
          clearcache)
            clearSaltCache
          ;;
          *) statusUtilities=1
          ;;
        esac
      done
    ;;
# ************ utilities *********************************************************************************************************************
# ************ config check ****************************************************************************************************************
    configcheck)
      configVerifyShow
    ;;
# ************ config check ****************************************************************************************************************
# ************ Salt status ****************************************************************************************************************
    saltstatus)
#      echo "Salt status"
      saltShowStatus
    ;;
# ************ Salt status ****************************************************************************************************************
# ************ Help ************************************************************************************************************************
    help)
      whiptail --msgbox "mycompany SaltStack Installer Guide

      * (Configure) Will run configuration wizzard for SaltStack installation and create $confFile
      * (Install) Will offer installation types:
                  + Full installation - install prerequisities, salt packages on master and minions, create enviroments and download project and formulas
                  + SaltStack software only - install prerequisities and salt packages on master and minions
                  + SaltStack software and enviroment - install prerequisities, salt packages on master and minions, create enviroments
      * (Utilities) Provide few utilities to manage Salt installation:
                  + Update formulas - will download current version of formulas from git
                  + Deploy project - will download project and make it ready to deployment
      * (Config check) Will display installation configuration, if Configure was used already or $congFile exist
      * (Salt status) Will show status of all Salt hosts in current installation" 0 0
    ;;
# ************ Help ************************************************************************************************************************
    *) status=1
          exit
    ;;
  esac
done
