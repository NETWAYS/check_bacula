#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# check_bacula.pl - checks the status of bacula
# Copyright (C) 2005  NETWAYS GmbH, www.netways.de
# Author: NETWAYS GmbH <info@netways.de>
# Version: $Id: ec31a70a082a410a68e991b1af185bcde76c4c99 $
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# $Id: ec31a70a082a410a68e991b1af185bcde76c4c99 $
# ------------------------------------------------------------------------------

# basic requirements
use strict;
use POSIX;
use File::Basename;
use DBI;
use Getopt::Long;
use Pod::Usage;

# predeclared vars
use vars qw(
  $opt_help
  $opt_usage
  $opt_host
  $opt_job
  $opt_critical
  $opt_warning
  $opt_hours
  $opt_dbhost
  $opt_dbname
  $opt_dbuser
  $opt_dbpass
  $out
  $sql
  $date_start
  $date_stop
  $state
  $hint
);

my $count           = 0;
my $jobfiles        = 0;
my $jobbytes        = 0;
my $joberrors       = 0;
my $jobmissingfiles = 0;

# predeclared subs
sub print_help;
sub get_now;
sub get_date;

# main values
my $PROGNAME = basename($0);
my $VERSION  = "0.0.1";

# NAGIOS states
my %ERRORS = (
	'UNKNOWN'  => '-1',
	'OK'       => '0',
	'WARNING'  => '1',
	'CRITICAL' => '2'
);

Getopt::Long::Configure('bundling');
GetOptions(
	"c=s"        => \$opt_critical,
	"critical=s" => \$opt_critical,
	"w=s"        => \$opt_warning,
	"warning=s"  => \$opt_warning,
	"hours=s"    => \$opt_hours,
	"H=s"        => \$opt_host,
	"host=s"     => \$opt_host,
	"j=s"        => \$opt_job,
	"job=s"      => \$opt_job,
	"dbhost=s"   => \$opt_dbhost,
	"db=s"       => \$opt_dbname,
	"dbuser=s"   => \$opt_dbuser,
	"dbpass=s"   => \$opt_dbpass,
	"h"          => \$opt_help,
	"help"       => \$opt_help,
	"usage"      => \$opt_usage,
  )
  || die "Try '$PROGNAME --help' for more information.\n";

# somebody wants help
if ($opt_help) {
	print_help(99);
} elsif ($opt_usage) {
	print_help(1);
}

if ( $opt_host && $opt_warning && $opt_critical ) {

	# setting up db connection
	my $dsn = "DBI:mysql:database=$opt_dbname;host=$opt_dbhost";
	my $dbh = DBI->connect( $dsn, $opt_dbuser, $opt_dbpass ) or die "Error connecting to: '$dsn': $DBI::errstr\n";

	# setting backup age
	if ($opt_hours) {
		$date_stop = get_date($opt_hours);
	} else {
		$date_stop = '1970-01-01 01:00:00';
	}
	$date_start = get_now();

	$opt_host .=  " ".$opt_job	if(defined $opt_job);

	$sql = "SELECT count(*) as 'count',sum(JobFiles),sum(JobBytes),sum(JobErrors),sum(JobMissingFiles) from Job where Name='" . 
	$opt_host."' and JobStatus='T' and EndTime <> '' and EndTime <= '".$date_start."' and EndTime >= '".$date_stop."';";

	# getting backups from db
	my $sth = $dbh->prepare($sql) or die "Error preparing statemment", $dbh->errstr;
	$sth->execute;

	# processing db results
	while ( my @row = $sth->fetchrow_array() ) {
		( $count, $jobfiles, $jobbytes, $joberrors, $jobmissingfiles ) = @row;
		$count           = 0 if ( !$count );
		$jobfiles        = 0 if ( !$jobfiles );
		$jobbytes        = 0 if ( !$jobbytes );
		$joberrors       = 0 if ( !$joberrors );
		$jobmissingfiles = 0 if ( !$jobmissingfiles );
	}

	$state = 'OK';
	$hint  = '';

	# checking results and setting error states
	if ( $count < $opt_warning )  { $state = 'WARNING' }
	if ( $count < $opt_critical ) { $state = 'CRITICAL' }

	if ( $state eq 'OK' ) {
		if ( $jobfiles == 0 || $jobbytes == 0 ) {
			# nothing backuped
			$hint  = " but no files nor bytes were backuped at all.";
			$state = 'WARNING';
		} elsif ( $jobfiles < $joberrors ) {
			# many errors
			$hint  = " but more errors than backuped files.";
			$state = 'WARNING';
		}
	}

	print "Bacula $state: Found $count successful jobs " . $hint
	  . "| jobs=" . $count
	  . " jobfiles=" . $jobfiles
	  . " jobbytes=" . $jobbytes
	  . " joberrors=" . $joberrors
	  . " jobmissingfiles=" . $jobmissingfiles . "\n";

	$dbh->disconnect();
	exit $ERRORS{$state};

} else {
	print_help(1);
}

# -------------------------
# THE SUBS:
# -------------------------

# print_help($level, $msg);
# prints some message and the POD DOC
sub print_help {
        my ( $level, $msg ) = @_;
        $level = 0 unless ($level);
        pod2usage(
                {
                        -message => $msg,
                        -verbose => $level
                }
        );

        exit( $ERRORS{UNKNOWN} );
}

sub get_now {
	my $now = defined $_[0] ? $_[0] : time;
	my $out = strftime( "%Y-%m-%d %X", localtime($now) );
	return ($out);
}

sub get_date {
	my $day = shift;
	my $now = defined $_[0] ? $_[0] : time;
	my $new = $now - ( ( 60 * 60 * 1 ) * $day );
	my $out = strftime( "%Y-%m-%d %X", localtime($new) );
	return ($out);
}

1;

__END__

=head1 NAME

check_bacula.pl - checks for backups per host in Bacula DB

=head1 SYNOPSIS

check_bacula.pl -h

check_bacula.pl --usage

check_bacula.pl	

		-H <backuped host> 
		-w <warning backup count> -c <critical backup count>
		--dbhost <database host> --db <database name> 
		--dbuser <database user> --dbpass <database password> 
		[ -j | --job <name of backup job> ] 
		[ --hours <maximal age of backup> ] 

=head1 DESCRIPTION

B<check_bacula.pl> is checking for backups per host in a specified timeframe, e.g. the last 24 hours.

=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<--usage>

Display the usage help

=item B<-H | --host>

The hostname of the backup host

=item B<-w | --warning>

The warning threshold, if number of backups found in db is smaller than this value state WARNING is returned 

=item B<-c> | --critical>

The critical threshold, if number of backups found in db is smaller than this value state CRITICAL is returned 

=item B<-j> | --job>

The backup job to search for in the database for the specified hostname

=item B<--dbhost>

Bacula database host

=item B<--db>

Bacula database name

=item B<--dbuser>

Bacula database user

=item B<--dbpass>

Bacula database password

=back

=cut

=head1 VERSION

$Id: ec31a70a082a410a68e991b1af185bcde76c4c99 $

=head1 AUTHOR

NETWAYS GmbH, 2009, http://www.netways.de.

Written by NETWAYS GmbH <info@netways.de>

Please report bugs through the contact of Nagios Exchange, http://www.nagiosexchange.org. 
