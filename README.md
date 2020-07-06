# Serinus


This is just a quick README on using the various ansible playbooks and perl file to create network flow diagrams.

## Pre-Reqs
 -  The target hosts either need to have already tcpflow installed or are subscribed to the EPEL repo for them to be installed.
 - The HTML is created in /var/www/html/tcpflow on the localhost.  It is already assumed that the local host has httpd installed and running
 - The perl script requires 2 modules:
	 - XML::LibXML
	 - Net::DNS
 - These can be installed by running 
	 - `yum -y install "perl(XML::LibXML)" "perl(Net::DNS)"`
 - There are currently some hard wired links which need to be made dynamic.  For example, the perl script location is hard coded in generateReport.yml
 - PLEASE, PLEASE, PLEASE don't just run this on a production environment! It's not yet ready for live release and *could* cause all kinds of problems.  Try it out in a local lab setup first.
 
## Workflow
The current workflow is as follows:
 - Create an ansible inventory file of hosts to be analysed (either FQDN or IPs)
`
[serinus]
192.168.122.117
192.168.122.137
192.168.122.1
`
 - Run the tcpflow.yml (currently defaults to use all in inventory)
 - `ansible-playbook -i inventory tcpflow.yml`
 - This will do the following:
	 - Find all open ports of each host
	 - Create a tcpflow directory in /var/tmp
	 - Check if tcpflow is already running
	 - If not running, start it running
	 - If tcpflow running, stop it and fetch xml file from remote host to localhost

Once you have all the results in /var/tmp/ on you localhost, you can then run generateReport.yaml.  This will parse all the tcpflow-report-*
.xml files in /var/tmp then run the processFlow.pl script on each of them

`ansible-playbook -i inventory generateReport.yml`

## Output
  
You should then end up with the output files in /var/www/html/tcpflow

![Screenshot](https://github.com/boogiespook/serinus/blob/master/screenshot.png)

To see the results, visit: https://localhost/tcpflow

