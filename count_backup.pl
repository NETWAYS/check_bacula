#!/usr/bin/perl
# 
# nagios: -epn
#
# ------------------------------------------------------------------------------
# check_bacula_count.pl - checks the size of Bacula backups 
# Copyright (C) 2005  NETWAYS GmbH, www.netways.de
# Author: NETWAYS GmbH <info@netways.de>
# Version: $Id: 90ffc4432e7ea3086cd5407b7538a22990148853 $
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
# $Id: 90ffc4432e7ea3086cd5407b7538a22990148853 $
# ------------------------------------------------------------------------------

use strict;
use POSIX;
use File::Basename;
use DBI;
use Getopt::Long;
use Pod::Usage;

# predeclared vars
use vars qw(
 $opt_help
 $opt_month
 $month1
 $month2
 $opt_pool
 $opt_cron
 $opt_warning
 $opt_critical
 $rc
 $sec
 $min
 $hour
 $mday
 $mon
 $opt_year
 $wday
 $yday
 $isdst
 $sql
);

# database credentials
my $host = "localhost";
my $db   = "bacula";
my $user = "bacula";
my $pass = "bacula";
my $pool = "Pool1";
my $rc   = 0;

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

# processing options
Getopt::Long::Configure('bundling');
GetOptions(
	"month=s"	=> \$opt_month,
	"year=s"	=> \$opt_year,
	"pool=s"	=> \$opt_pool,
	"h"			=> \$opt_help,
	"help"			=> \$opt_help,
	"cron"  	=> \$opt_cron,
	"warning=s"	=> \$opt_warning,
	"critical=s"	=> \$opt_critical,
	"w=s"		=> \$opt_warning,
	"c=s"		=> \$opt_critical,
  )
  || die "Try '$PROGNAME --help' for more information.\n";

# somebody wants help
if ($opt_help) {
        print_help(1);
} 

if ( ($opt_year && $opt_month) || $opt_cron ) {

	$opt_month = "0".$opt_month if ($opt_month =~ /^\d$/);
	
	if (defined $opt_cron) {
		($sec,$min,$hour,$mday,$mon,$opt_year,$wday,$yday,$isdst) = localtime(time - 24*60*60);
		if ($mon =~ /^\d$/) {
			$opt_month = "0" . ($mon + 1);
		} else {
			$opt_month = $mon + 1;
		}
		$opt_year += 1900;
	}
	
	$month1 = $opt_month;
	$month2 = $opt_month + 1;
	
	my $dsn = "DBI:mysql:database=$db;host=$host";
	my $dbh = DBI->connect("$dsn","$user","$pass") || die "Database connection not made: $DBI::errstr";
	
	$sql = qq{select Name from Pool};
	
	if (defined $opt_pool) {
		$sql = qq{select sum(JobBytes)/1024/1024/1024 from Job where PoolID IN (select PoolID from Pool where Name Like "$opt_pool") AND StartTime >= (select Date_Format(SchedTime, '%Y-%m-%d 00:00:00') AS Date FROM Job where PoolID IN (select PoolID from Pool where Name Like "$opt_pool") AND LEVEL = 'F' AND JobStatus = 'T' GROUP BY Date ORDER BY Date DESC LIMIT 1,1);};
		my $bytes = $dbh->selectrow_array($sql);
		unless ($bytes) {
			$sql = qq{select sum(JobBytes)/1024/1024/1024 from Job where PoolID IN (select PoolID from Pool where Name Like "$opt_pool");};
			$bytes = $dbh->selectrow_array($sql);
		}
	
		$sql = qq{select (MaxVols * MaxVolBytes / 1024 / 1024 / 1024) from Pool where Name = "$opt_pool";};
		my $poolsize = $dbh->selectrow_array($sql);
	
	
		$bytes =~ s/(\d+\.\d{2})\d*/$1/;
		$poolsize =~ s/(\d+\.\d{2})\d*/$1/;
	
	
		unless ($bytes) {
			$bytes = "0.00";
		}
	
		my $used_percentage = ($bytes * 100 / $poolsize);
		if ( $used_percentage > $opt_critical and defined $opt_critical) {
			print "CRITICAL - ";
			$rc = 'CRITICAL';;
		} elsif ( $used_percentage > $opt_warning and defined $opt_warning) {
			print "WARNING - ";
			$rc = 'WARNING';
		} else {
			print "OK - ";
		}
		printf("%.2f", $used_percentage);
		print "% used - ";
		print "Backupvolumen ";
		print "$bytes GB von $poolsize GB|";
		print "transferred=$bytes max=$poolsize\n";
	} else {
		my $pools = $dbh->selectall_arrayref($sql);
	
		foreach (@$pools) {
			$pool =  "@$_";
			$sql = qq{select sum(JobBytes)/1024/1024/1024 from Job where PoolID IN (select PoolID from Pool where Name Like "$pool") AND StartTime >= (select Date_Format(SchedTime, '%Y-%m-%d 00:00:00') AS Date FROM Job where PoolID IN (select PoolID from Pool where Name Like "$pool") AND LEVEL = 'F' AND JobStatus = 'T' GROUP BY Date ORDER BY Date DESC LIMIT 1,1);};
			my $bytes = $dbh->selectrow_array($sql);
			unless ($bytes) {
				$sql = qq{select sum(JobBytes)/1024/1024/1024 from Job where PoolID IN (select PoolID from Pool where Name Like "$pool");};
				$bytes = $dbh->selectrow_array($sql);
			}
		
			$bytes =~ s/(\d+\.\d{2})\d*/$1/;
	
			unless ($bytes) {
				$bytes = "0.00";
			}
			print "Backupvolumen $pool Monat $month1/$opt_year\n";
			print "=========================================\n";
			print "$bytes GB\n\n";
		}
	}
	
	$dbh->disconnect();
	exit $ERRORS{$rc};
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

__END__

=head1 NAME

check_bacula_count.pl - checks for Bacula pools for usage

=head1 SYNOPSIS

check_bacula_count.pl -h

check_bacula_count.pl 

check_bacula_count.pl --month <month to check> --year <year to check> | --cron
					  [ --pool <pool to check> ]
					  [ --warning <warning threshold in %> ]
					  [ --critical <critical threshold in %> ]

=head1 DESCRIPTION

B<check_bacula_count.pl> is checking for backup pool size in Bacula database

=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<--month>

month to check, in this case year is also required

=item B<--year>

year to check

=item B<--cron>

cron is the automated way to check for pool size periodicaly for the last month

=item B<--pool>

the pool name to check

=item B<-w | --warning>

warning threshold in %

=item B<-c | --critical>

warning threshold in %

=back

=cut

=head1 VERSION

$Id: 90ffc4432e7ea3086cd5407b7538a22990148853 $

=head1 AUTHOR

NETWAYS GmbH, 2009, http://www.netways.de.

Written by NETWAYS GmbH <info@netways.de>

Please report bugs at https://www.netways.org/projects/plugins
