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
}


isInteger() {
  flag=`[[ $1 == ?(-)+([0-9]) ]]`;
  return $flag;
}

function setup() {
	
	nodeIp="";
	IFS=' ' read -r -a iparray <<< `ip addr show | grep -Po 'inet \K[\d.]+'`	
	SUDO_CMD="";
	SPARK_DOWNLOAD_LINK="http://d3kbcqa49mib13.cloudfront.net/spark-2.1.0-bin-hadoop2.7.tgz";
	SPARK_DIR="/spark"
	current_user=$(whoami);
	

	#read nodes
	readarray nodes < nodes.txt
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

	

	 # set neo4j type and version
    while getopts "t:n" o; do
        case "$o" in
            #t)  type=$OPTARG;
            #    (( "$type" == "community" || "$type" == "enterprise")) && nodeType=$type;
            #    ;;
            #n)  nodeName=$OPTARG;
		#		;;
         #   *) usage;
          #      ;;
        esac
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
		$SUDO_CMD cat nodes.txt >> /etc/hosts 
	fi		
	
	#creating user if not exist	
	id -u spark &>/dev/null || sudo useradd -d /home/spark -m spark
	
	
	#create directory
	if  [ ! -e "$SPARK_DIR" ] ;  then
		$SUDO_CMD mkdir $SPARK_DIR
	fi		
	
	#givving access to sparl user
	$SUDO_CMD setfacl -m u:spark:rwx $SPARK_DIR	
	if ( [ ! "$current_user" = "root" ] ) then
		$SUDO_CMD `"setfacl -m u:$current_user:rwx $SPARK_DIR"`
	fi
	#entering the directory		
	
	#creating a new ssh key if it doesn't exist	
	$SUDO_CMD [ -e "/home/spark/.ssh/id_rsa.pub" ] || runuser -l spark -c 'ssh-keygen -t rsa -f "/home/spark/.ssh/id_rsa" -q -N ""'
	
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
		echo "export JAVA_HOME=/usr/lib/jsvm/$lastJdk;" >> /spark/spark/conf/spark-env.sh;
	fi
	
	[ -e spark/conf/slaves ] || rm  spark/conf/slaves
	index=0;
	for node in "${nodes[@]}"; do
		IFS=' ' read -r -a parts <<< $node
		nodename=$(echo -e "${parts[1]}" | tr -d '[:space:]');
		if [ ! $index -eq 0 ]; then
			echo "$nodename" >> spark/conf/slaves;
		fi
		let index=index+1 ;
	done
	
	cd $currentdir;
	
}


function usage (){
    read -r -d "" output << TXT
Usage: spark-man [command]

The commands are as follows:
 help                           outputs this document
 setup [option]		            create a new database instance
 sharekey      					Shares ssh key with master
 start 		                    startS master/slave on this node
 stop 		                    stops this node
 list                           lists the nodes in cluster                                
TXT
    echo "$output";
    exit 1;
}


function handleSlave(){
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
		