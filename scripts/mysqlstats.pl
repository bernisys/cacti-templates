#!/usr/bin/perl

use strict;
#use warnings;
#use diagnostics;

$| = 1;

#### configuration part
my $CACTI_CONF_FILE = '####INSERT PATH TO CACTI INSTALLATION HERE####/cacti/include/config.php';
my $CMD_MYSQLADMIN = '/usr/bin/mysqladmin';
my $VERBOSE = 0;

#### read script parameter
my $which = $ARGV[0];

use DBI;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my $h_db = cacti_db_open();

my $output = '';

if ((!defined $which) or ($which eq 'boost')) {
  my ($poller_output, $poller_output_boost, $arch) = get_boost_counts($h_db);
  $output .= "PollerOutput:$poller_output PollerOutputBoost:$poller_output_boost PollerOutputBoostArch:$arch";
}

my @items;
if ((!defined $which) or ($which eq 'connections')) {
  push @items, 'Connections', 'Max_used_connections', 'Aborted_connects', 'Aborted_clients', 'Threads_connected';
}
if ((!defined $which) or ($which eq 'inno_mem')) {
  push @items, 'Innodb_mem_total', 'Innodb_mem_adaptive_hash', 'Innodb_mem_dictionary';
}
if ((!defined $which) or ($which eq 'inno_rows')) {
  push @items, 'Innodb_rows_deleted', 'Innodb_rows_inserted', 'Innodb_rows_read', 'Innodb_rows_updated';
}
if ((!defined $which) or ($which eq 'query')) {
  push @items, 'Queries', 'Slow_queries', 'Select_full_join';
}

if (@items) {
  my %stat = get_sqlstats($h_db);
  foreach my $item (@items) {
    (my $itemname = $item) =~ s/_//g;
    $output .= ' '.$itemname.':'.$stat{$item};
  }
}

$h_db->disconnect;

$output =~ s/^ //;
print $output;


sub cacti_config_get_db_params {
  my $file = shift;

  $file = $CACTI_CONF_FILE if (!defined $file);

  my %params;

  open(my $h_file, '<', $file);
  while (my $line = <$h_file>) {
    next if $line !~ /\$r?database/;
    next if $line =~ /^\s*#/;
    if ($line =~ /^\s*\$(r?)database_(\w+)\s+=\s+'?(.*?)'?;/)
    {
      $params{$1}{$2} = $3;
    }
  }
  return %params;
}

sub cacti_db_open {
  my $ref_params = shift;

  $ref_params = {cacti_config_get_db_params()}->{''} if (!defined $ref_params);
  
  my $handle = DBI->connect(
    "DBI:mysql:database=$ref_params->{'default'};host=$ref_params->{'hostname'};port=$ref_params->{'port'};mysql_connect_timeout=2",
    $ref_params->{'username'},
    $ref_params->{'password'}
  );

  return $handle;
}

sub get_boost_counts {
  my $h_db = shift;

  my $count_poller_output  = 0;
  my $count_poller_output_boost  = 0;
  my $count_poller_output_boost_arch  = 0;

  my $ref_data = execute_query($h_db, 'SELECT count(1) as count from poller_output', , 'count',);
  if (%{$ref_data}) {
    $count_poller_output  = (keys %{$ref_data})[0];
  }

  $ref_data = execute_query($h_db, 'SELECT count(1) as count from poller_output_boost', , 'count',);
  if (%{$ref_data}) {
    $count_poller_output_boost  = (keys %{$ref_data})[0];
  }

  $ref_data = execute_query($h_db, 'SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = "cacti" AND table_name like "poller_output%"', , 'table_name',);
  #print $h_debug Dumper($ref_data);
  my $arch_name = (grep(/arch/, keys %{$ref_data}))[0];
  if (defined $arch_name) {
    #print "counting arch $arch_name...\n";
    $ref_data = execute_query($h_db, 'SELECT count(1) as count from '.$arch_name, , 'count',);
    $count_poller_output_boost_arch  = (keys %{$ref_data})[0];
  }

  return ($count_poller_output, $count_poller_output_boost, $count_poller_output_boost_arch);
}

sub get_sql_vars {
  my $ref_data = execute_query($h_db, 'show variables', 'Variable_name');
}

sub execute_query {
  my $h_db = shift;
  my $query = shift;
  my $primary_key = shift;

  my $h_statement = $h_db->prepare($query);
  $h_statement->execute(@_);
  my $ref_data = $h_statement->fetchall_hashref($primary_key);
  $h_statement->finish;

  return $ref_data;
}

sub get_sqlstats {
  my $h_db = shift;
  
  my %stat = %{execute_query($h_db, 'SHOW STATUS', 'Variable_name')};
  foreach my $key (keys %stat) {
    $stat{$key} = $stat{$key}{'Value'};
  }

  return %stat;
}
