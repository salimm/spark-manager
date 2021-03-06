#!/bin/bash

if ([ "$EUID" -ne 0 ]) then 
	SUDO_CMD="sudo";
fi
	
function install_req {
	$SUDO_CMD apt-get install git -y;
	$SUDO_CMD apt-add-repository ppa:webupd8team/java -y;
	$SUDO_CMD apt-get update -y;
	$SUDO_CMD apt-get install oracle-java8-installer -y;
	$SUDO_CMD apt-get install oracle-java8-set-default ;
	$SUDO_CMD apt-get install maven gradle -y;
	$SUDO_CMD apt-get install sbt -y;
	$SUDO_CMD apt-get install vim -y;
	$SUDO_CMD apt-get install scala -y;
	$SUDO_CMD apt-get install openssh-server openssh-client;
	$SUDO_CMD apt-get install python-software-properties;
	$SUDO_CMD apt-get install sshpass -y;
}


isInteger() {
  flag=`[[ $1 == ?(-)+([0-9]) ]]`;
  return $flag;
}

function setupSingle(){

}

function setup() {
	
	nodeIp="";
	IFS=' ' read -r -a iparray <<< `ip addr show | grep -Po 'inet \K[\d.]+'`	
	SUDO_CMD="";
	SPARK_DOWNLOAD_LINK="http://d3kbcqa49mib13.cloudfront.net/spark-2.1.0-bin-hadoop2.7.tgz";
	SPARK_DIR="/spark"
	current_user=$(whoami);
	pass="test123456"
	nodesFile="nodes.txt"
	uname="spark"
	
	OPTIND=2;

	 # set params
    while getopts "pl:d:n:cu:" o; do
		case "$o" in
            p)  read -s pass;
                ;;
			l) SPARK_DOWNLOAD_LINK="$OPTARG";
                ;;
			d) SPARK_DIR="$OPTARG";
                ;;
			n) nodesFile="$OPTARG";
                ;;
			c) install_req;
                ;;
			u) uname="$OPTARG";
                ;;
            *) usage;
                ;;
        esac
    done

	#read nodes
	readarray nodes < nodesFile
	index=0;
	found=0;
	for node in "${nodes[@]}"; do
		IFS=' ' read -r -a parts <<< $node
		nip=$(echo -e "${parts[0]}" | tr -d '[:space:]')
		for tip in "${iparray[@]}"; do
			if ( [ "$nip" =  "$tip" ] ) then
				found=1;
				break;
			fi
        done
		if [ "$found" = "1" ]; then
			nodeIp=$nip;
			name=$(echo -e "${parts[1]}" | tr -d '[:space:]')
			if [ "$index" = "0" ]; then
				nodeType="master";
			else
				nodeType="slave";
			fi
			break;
		fi
		let index=index+1 ;
	done

	
		

	#checking if name is set
	if ( [[ -z  $name  ]] ||  [[  -z  $nodeType  ]] ) then
		usage;
		exit;
	fi

	echo "** setting up $nodeType on $name @ $nodeIp"
	
	# adding ip to /etc/hosts
	
	if  ! grep -q "#spark nodes"  /etc/hosts ; then                
		$SUDO_CMD echo "#spark nodes" >> /etc/hosts 
		$SUDO_CMD cat nodesFile >> /etc/hosts 
	fi		
	
	#creating user if not exist	
	$SUDO_CMD id -u spark &>/dev/null || ( $SUDO_CMD useradd -m -d /home/spark -s /bin/bash spark; echo -e "$pass\n$pass\n" | passwd spark )
	
	#create directory
	if  [ ! -e "$SPARK_DIR" ] ;  then
		$SUDO_CMD mkdir $SPARK_DIR
	fi		
	 
	#givving access to sparl user
	$SUDO_CMD chown -R spark $SPARK_DIR
	$SUDO_CMD chmod -R +rwx $SPARK_DIR
	if ( [ ! "$current_user" = "root" ] ) then
		$SUDO_CMD `"setfacl -m u:$current_user:rwx $SPARK_DIR"`
	fi
	#entering the directory		
	
	#creating a new ssh key if it doesn't exist	
	$SUDO_CMD [ -e "/home/spark/.ssh/id_rsa.pub" ] || runuser -l spark -c 'ssh-keygen -t rsa -f "/home/spark/.ssh/id_rsa" -q -N ""'
	
	if ([ "$nodeType" = "master" ]) then
		index=0;
		for node in "${nodes[@]}"; do
			IFS=' ' read -r -a parts <<< $node
			nip=$(echo -e "${parts[0]}" | tr -d '[:space:]');
			npass=$(echo -e "${parts[2]}" | tr -d '[:space:]');
			if [ ! $index -eq 0 ]; then
				cat /home/spark/.ssh/id_rsa.pub | sshpass -p "$npass" ssh spark@"$nip" 'cat >> .ssh/authorized_keys'
			fi
			let index=index+1 ;
		done
 	fi
	
	
	currentdir=$(pwd);
	#entering spark directory
	cd $SPARK_DIR		
	
	files=(/spark/spark*);	
	if ( [ ! "$files" = "/spark/spark*" ] ) then
		#echo "setup exists.. trying uninstalling first";
		#exit 1;
		echo "skipping download and extraction"
	else
		#downloading spark
		wget "$SPARK_DOWNLOAD_LINK";
		#extract file
		files=(spark*tgz);
		tgzfile=${files[0]};
		tar xzf $tgzfile;
		rm -R $tgzfile;
		files=(spark*);
		fullname=${files[0]};
		echo "$fullname" > version.txt
		mv "$fullname" spark
	fi
	
	
	
	#updating bashrc 	
	if  ! $SUDO_CMD grep -q "$export JAVA_HOME*"  /home/spark/.bashrc ; then                
		runuser -l spark -c 'lastJdk=$(ls /usr/lib/jvm/ | sort | tail -n1); echo "export JAVA_HOME=/usr/lib/jsvm/$lastJdk;" >> /home/spark/.bashrc;'
	fi
	if  ! $SUDO_CMD grep -q "$export SPARK_HOME*"  /home/spark/.bashrc ; then                
		runuser -l spark -c 'echo "export SPARK_HOME=/spark/spark;" >> /home/spark/.bashrc;'
		runuser -l spark -c 'echo "export PATH=$PATH:$SPARK_HOME/bin;" >> /home/spark/.bashrc;'		
	fi
	
	#update spark-env.sh
	cp spark/conf/spark-env.sh.template spark/conf/spark-env.sh
	if  ! $SUDO_CMD grep -q "$export JAVA_HOME*"  /spark/spark/conf/spark-env.sh ; then                
		lastJdk=$(ls /usr/lib/jvm/ | sort | tail -n1);
		echo "export JAVA_HOME=/usr/lib/jvm/$lastJdk;" >> /spark/spark/conf/spark-env.sh;
	fi
	
	[ -e "spark/conf/slaves" ] || rm  spark/conf/slaves
	index=0;
	for node in "${nodes[@]}"; do
		IFS=' ' read -r -a parts <<< $node
		nodename=$(echo -e "${parts[1]}" | tr -d '[:space:]');
		if [ ! $index -eq 0 ]; then
			if  ! grep -q "$nodename"  spark/conf/slaves ; then                
				echo "$nodename" >> spark/conf/slaves;
			fi
		fi
		let index=index+1 ;
	done
	
	cd $currentdir;
	
}


function usage (){
    read -r -d "" output << TXT
Usage: spark-man [command]

The commands are as follows:
 help                           		  Outputs this document
 install_req							  installs the required packages both for Spark and the script
 setup <setup-type> [option]		      Setup spark on one/multiple nodes. Setup-type can be either single or cluster. The setup creates a new user spark if it doesn't exist. It also requires sudo access
	-p) 								  This argument prompts user for a password for the new spark accounts in all nodes. If not specified the script will use a hard coded password which can be changed later by user
	-u)	<username>						  User can pass username to access node as argument. Otherwise, the default is to use spark	
	-n) <nodes file address>	     	  This arguments allows user to pass address of the nodes.txt file
	-c)									  If used the script will also run install_req for all nodes
	-l)	<spark-download-link>			  This argument allows user to pass the link to download spark, otherwise, it will use a hard coded link					  
	-d)	<spark setup directory>			  This argument allows user to pass spark setup rdirectory. If not used  the default (/spark) will be sued
 addslave <slave-name>				      Adds a new slave to the cluster. Sould be used on master. If -s or -i are not used it will simply change configurations
	-s)									  Runs setup for the client node first (requires the password to exist in nodes.txt file)
	-c)									  If used the script will also run install_req for all nodes	
	-i)	<ip>							  If no nodes.txt exists , or node is not in nodes.txt with the specified name the user must pass ip address
	-u)	<username>						  User can pass username to access node as argument. Otherwise, the default is to use spark
	-p)									  User will promt for password, otherwise will look for password in nodes.txt file 
	-n) <file address>					  User can pass address for the nodes.txt file.  Otherwise, it will assume to be in the same directory as the script and named "nodes.txt"
	-d)	<spark setup directory>			  This argument allows user to pass spark setup rdirectory. If not used  the default (/spark) will be sued	
 remslave	<slave-name>			      This works by only re-configuring the spark settings
	
	
TXT
    echo "$output";
    exit 1;
}


function addSlave(){
   echo "test";
   return 0;
}

function remSlave(){
   echo "test";
   return 0;
}

function displayList (){
	echo "test";
	return 0;
}



case "$1" in
	install_req)
			install_req;
		;;
	setup)
			setup "${@}";
		;;
	addSlave)
			addSlave "${@}";
		;;
	remSlave)
			remSlave "${@}";
		;;
		
	list)
			displayList "${@}";
		;;
		
	help)
			usage;
		;;
	*)
		usage;
		;;
esac
		