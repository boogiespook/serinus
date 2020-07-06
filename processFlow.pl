#!/usr/bin/perl

##########################################################################
##
## Author: Chris Jenkins <chrisj@redhat.com>
## Version: 1.0
## Date: 2nd April 2020
##
## Updated: 23rd June 2020
##
## Pre-Reqs
## Ensure you have the XML::LibXML and Socket perl modules installed
## yum -y install "perl(XML::LibXML)" "perl(Net::DNS)"
##
## You also need vis-network.min.js in /var/www/html/tcpflow/js
## Can be downloaded from https://visjs.org/ but it's also copied across in generateReport.yml
##
## Notes
## When running then killing tcpflow on a remote machine, the report.xml
## file sometimes doesn't complete which causes XML parsing issues.  Hence
## the reason for my dirty hack to re-create the report file
##
## It currently create the HTML in /var/www/html/tcpflow so you'll need to create this if not already the
## Update: add yum install httpd; firewalld; enable port 80; enable & start httpd
## 
## Individual hosts are stored in /var/www/html/tcpflow/hosts/${hostname}

use XML::LibXML;
use Socket; 
use File::Basename;
# use strict;
# use warnings;

my $filename = $ARGV[0];
if (not defined $ARGV[0]) {
	print "Report filename not given as command line variable so using report.xml\n";
	$filename = 'report.xml';
}

my $workingDir = dirname($filename); 


## We need to parse the report file as (sometimes) it gets b0rked!
open(my $parsedReportFile,">",'parsed-' . $filename) or die "Could not open file parsed-" . $filename . " - $!";
print $parsedReportFile "<?xml version='1.0' encoding='UTF-8'?>\n";
print $parsedReportFile "<dfxml xmloutputversion='1.0'>\n";

open(my $reportFile,'<', $filename);
while (my $line = <$reportFile>) {
        if ($line =~ /<tcpflow | <host>/) {
            print $parsedReportFile $line;
        }
    }

close($reportFile);
print $parsedReportFile "</dfxml>";
close($parsedReportFile);


## Fudge the parsed file to be the new filename
$filename = 'parsed-' . $filename;

## Read the XML doc
my $dom = XML::LibXML->load_xml(location => $filename);

# print " - Parsed file: $filename \n";
my $fh = "";
my $allFiles = "N";
## Check if filename is all-tcpflow.xml
if ($filename eq "parsed-all-tcpflow.xml") {
  my $runningHost = "All Hosts";
  $allFiles = "Y";
#  print " - Running host: $runningHost \n"; 
  open($fh, '>', '/var/www/html/tcpflow/index.html')  or die "Could not open file [$!]";
} else {
  my $runningHost = $dom->findnodes('/dfxml/host');
  $allFiles = "N";
#  print " - Running host: $runningHost \n"; 
  open($fh, '>', '/var/www/html/tcpflow/hosts/tcpflow-' . $runningHost . '.html') or die "Could not open file [$!]"; 
}

my @nodes;
my @uniqueNodes;
my @uniqueEdges;
my @edges;
my @dstPorts;
my @uniquePorts;

## Create the HTML header
print $fh '<!doctype html>
<html>
<head>
  <title>Serinus Network Flow</title>
  <script type="text/javascript" src="js/vis-network.min.js"></script>
<link rel="stylesheet" href="css/style.css" type="text/css" />

</head>
<body>';
if ($allFiles eq "N") {
  print $fh "<h3>TCP Flow data for: " . $dom->findnodes('/dfxml/host') . "</h3>";
  } else {
  print $fh "<h3>TCP Flow data for all hosts</h3>";  
  }

print $fh '<div id="container">';

## Get Nodes & Edges
foreach my $flow ($dom->findnodes('/dfxml/tcpflow')) {

    my $srcIp = $flow->getAttribute('src_ipn') ;
	 push(@nodes,$srcIp);
    my $dstIp = $flow->getAttribute('dst_ipn') ;
	 push(@nodes,$dstIp);

    my $srcPort = $flow->getAttribute('srcport') ;
    my $dstPort = $flow->getAttribute('dstport') ;
    push(@dstPorts,$dstPort);
        
 my $str = "\{from: \'$srcIp\', to: \'$dstIp\', arrows: 'to', label: \'$dstPort/tcp\'\}";
 push(@edges,$str);
}

print $fh '<div class=rhs><label><h4>Select Servers</h4>';

# Sort unique nodes
my @nnodes = sort(@nodes);
@nodes = @nnodes;
foreach my $var ( @nodes ){
  if ( ! grep( /$var/, @uniqueNodes ) ){
 #print "Var: $var \n";   
print $fh '
      <div class="inputGroup">
    		<input id="' . $var . '" name="nodesFilter" value="' . $var . '" type="checkbox"/>
    		<label for="' . $var . '">' . $var . '</label>
      </div>
';
     push( @uniqueNodes, $var );
  }
}



print $fh '<h4>Select Ports</h4>';
    
# Sort unique ports
foreach my $var ( @dstPorts ){
  if ( ! grep( /$var/, @uniquePorts ) ){
print $fh '
      <div class="inputGroup">
    		<input id="' . $var . '" name="edgesFilter" value="' . $var . '/tcp" type="checkbox"/>
    		<label for="' . $var . '">' . $var . '</label>
      </div>

';
     push( @uniquePorts, $var );
  }
}

print $fh '</div><div id="mynetwork"></div>
<script type="text/javascript">

//    const nodeFilterSelector = document.getElementById(\'nodeFilterSelect\')
    const nodeFilters = document.getElementsByName(\'nodesFilter\')
    const edgeFilters = document.getElementsByName(\'edgesFilter\')


    function startNetwork(data) {
      const container = document.getElementById(\'mynetwork\')
      const options = {}
      new vis.Network(container, data, options)
    }
    
  // create an array with nodes';

print $fh "\n  var nodes = new vis.DataSet([\n";
foreach my $node (@uniqueNodes) {
  my $tmpName = gethostbyaddr(inet_aton( "$node"), AF_INET);
   if ($tmpName eq "") {
		$tmpName = "$node";   
   }
   $tmpColor = join "", map { unpack "H*", chr(rand(256)) } 1..3;
	print $fh "{ id: \'$node\', label: \'$node\', title: \'$tmpName\', color: '#" . $tmpColor . "'} , \n";
}
print $fh " ]);\n";

# Sort unique edges
foreach my $var ( @edges ){
  if ( ! grep( /$var/, @uniqueEdges ) ){
     push( @uniqueEdges, $var );
  }
}

print $fh "\n\n  var edges = new vis.DataSet([ \n";
foreach my $edges (@uniqueEdges) {
	print $fh $edges . ",\n";
}
print $fh " ]);\n";

print $fh '     
    let nodeFilterValue = \'\'

    const edgesFilterValues = {
      port: true,
      label: true
    }

    const nodesFilterValues = {
      label: true
    }

    const edgesFilter = (edge) => {
      return edgesFilterValues[edge.label]
    }

    const nodesFilter = (node) => {
      return nodesFilterValues[node.label]
//        return true
    }

//    const nodesFilter = (node) => {
//      if (nodeFilterValue === \'\') {
//       return true
//        }
//      }

    const nodesView = new vis.DataView(nodes, { filter: nodesFilter })
    const edgesView = new vis.DataView(edges, { filter: edgesFilter })

    edgeFilters.forEach(filter => filter.addEventListener(\'change\', (e) => {
      const { value, checked } = e.target
      edgesFilterValues[value] = checked
      edgesView.refresh()
    }))

    nodeFilters.forEach(filter => filter.addEventListener(\'change\', (e) => {
      const { value, checked } = e.target
      nodesFilterValues[value] = checked
      console.log(nodeFilters)
      nodesView.refresh()
    }))


    startNetwork({ nodes: nodesView, edges: edgesView })
</script>';

## If we doing all-reports, add links to all the hosts

# if ($allFiles eq "Y") {
#   print $fh "<div class=rhs><h3>Hosts</h3>";
#	$directory = '/var/www/html/tcpflow/hosts';
#   opendir (DIR, $directory) or die $!;
#    while (my $file = readdir(DIR)) {
#		next unless ($file =~ m/\.html$/);
#	   print $fh "<a href=hosts/" . $file . ">" . substr($file,8,-5) . "</a><br>";
#    }
#closedir(DIR);
# } else {
# print $fh "<div class=rhs><h3><a href=../index.html>Back</a></h3>"; 
# }

print $fh "</div>";



print $fh '
</body>
</html>';

close $fh;
# print "\n\nOutput file is tcpflow-" . $runningHost . ".html \n\n";
