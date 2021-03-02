#!/usr/bin/perl

use strict;

my $LOGDIR="### PATH TO CACTI INSTALLATION ###/log/";

my %stats = (
  ''            => { 'DataSources' => 0, 'Hosts' => 0, 'HostsPerProcess' => 0, 'Processes' => 0, 'RRDsProcessed' => 0, 'Threads' => 0, 'Time' => 0, },
  'BOOST'       => { 'RRDUpdates' => 0, 'Time' => 0, },
  'DSSTATS'     => { 'Time' => 0, },
  'LOGMAINT'    => { 'LOGMAINTRetained' => 0, 'LOGMAINTTime' => 0, },
  'Reports'     => { 'Reports' => 0, 'Time' => 0, },
  'THOLD'       => { 'DownDevices' => 0, 'NewDownDevices' => 0, 'Tholds' => 0, 'Time' => 0, 'TotalDevices' => 0, },
  'THOLDDAEMON' => { 'Broken' => 0, 'Completed' => 0, 'DownDevices' => 0, 'InProcess' => 0, 'MaxProcesses' => 0, 'MaxRuntime' => 0, 'NewDownDevices' => 0,
                     'Processed' => 0, 'Running' => 0, 'TotalDevices' => 0, 'TotalTime' => 0, },
);

my %statslines;
open(my $h_log , '<', $LOGDIR.'/cacti.log') or die "Cant read cacti log\n";
foreach my $line (grep / - SYSTEM /, (<$h_log>))
{
        next if index($line, " - SYSTEM " < 0);
        if ($line =~ / - SYSTEM (.*?) *STATS: (.*)/)
        {
    my ($key, $value) = ($1, $2);
    $key =~ s/ //g; # remove spaces from names
                $statslines{$key} = $value;
        }
}
close($h_log);

my @result;
foreach my $type (keys %statslines)
{
        my $stats_line = $statslines{$type};
        foreach my $element (split(/ /, $stats_line))
        {
                next if $element !~ /:[0-9\.]+$/;
                my ($key, $value) = split(/:/, $element);
                $stats{$type}{$key} = $value;
        }
}

foreach my $type (sort keys %stats)
{
        foreach my $key (sort keys %{$stats{$type}})
        {
                print $type.$key.':'.$stats{$type}{$key}." ";
        }
}
