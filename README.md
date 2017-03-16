# spark-manager
A simple spark cluster manager

This scrit helps installing spark on multiple nodes. Ofcourse there are much more complete and reliable supporting a lot more things like Mesos. However, this can a very good start point for someone who wants to learn how to setup a spark cluster and get their hands on Spark. 

This is a underconstruction tool so some of the functionalities below may still not work.


## Usage: 

```
Usage: spark-man [command]

The commands are as follows:
 help                           		  Outputs this document
 install_req							  installs the required packages both for Spark and the script
 setup <setup-type> [option]		      Setup spark on one/multiple nodes. Setup-type can be either single or cluster. The setup creates a new user spark if it doesn't exist. It also requires sudo access
	-p) 								  This argument prompts user for a password for the new spark accounts in all nodes. If not specified the script will use a hard coded password which can be changed later by user
	-u)	<username>						  User can pass username to access node as argument. Otherwise, the default is to use spark	
	-d) <file address>	     			  This arguments allows user to pass address of the nodes.txt file
	-c)									  If used the script will also run install_req for all nodes
	-l)	<spark-download-link>			  This argument allows user to pass the link to download spark, otherwise, it will use a hard coded link					  
 addslave <slave-name>				      Adds a new slave to the cluster. Sould be used on master. If -s or -i are not used it will simply change configurations
	-s)									  Runs setup for the client node first (requires the password to exist in nodes.txt file)
	-c)									  If used the script will also run install_req for all nodes	
	-i)	<ip>							  If no nodes.txt exists , or node is not in nodes.txt with the specified name the user must pass ip address
	-u)	<username>						  User can pass username to access node as argument. Otherwise, the default is to use spark
	-p)									  User will promt for password, otherwise will look for password in nodes.txt file 
	-d) <file address>					  User can pass address for the nodes.txt file.  Otherwise, it will assume to be in the same directory as the script and named "nodes.txt"
 remslave	<slave-name>			      This works by only re-configuring the spark settings
	
					
	
```
