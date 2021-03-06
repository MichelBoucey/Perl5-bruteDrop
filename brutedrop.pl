#!/usr/bin/perl

=pod

  Copyright (C) 2017 by Michel Boucey
  Released under BSD-3 license clause
  See LICENSE file

  https://github.com/MichelBoucey/Perl5-bruteDrop

=cut


use strict;
use warnings;
use MIME::Lite;


# brutedrop won't start if the both
# below white lists are empty :

# White list of IPv4 addresses
my @ipv4_addresses = ();

# White list of Unix users
my @users = ();


# bruteDrop log
my $log = '/var/log/brutedrop.log';

# Add an email address, or leave empty for no report
my $to = 'root';

# Path to iptables
my $iptables = '/usr/bin/iptables';

# Get log lines of failed SSH login attempts
my @failed = `journalctl --since "5 minutes ago" -u sshd --no-pager | grep Failed`;


if (@ipv4_addresses == 0 && @users == 0) {

    print "You have to add exceptions in brutedrop white lists.\n";

    exit;	

}


foreach (@failed) {

    if (/^(\D{3}\s\d{2}\s\d{2}:\d{2}:\d{2}).*?for\s(invalid user\s|)(.+)\sfrom\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {

        open LOG, ">>$log" or die "Opening $log failed\n";
     
        my $host = `hostname`;

        chop $host;

        my $subject;

        my $msg;

        if (grep(/^$3$/, @users)) {

            print LOG "[$1] Authorized user login failure ($3\@ssh)\n";

            if ($to) { $subject = "Authorized user $3\@$host just failed to login" }

        } elsif ( ! grep(/^$4$/, @ipv4_addresses) ) {

            if (system("$iptables -w -C INPUT -s $4 -j DROP 2> /dev/null")) {

                system("$iptables -w -A INPUT -s $4 -j DROP");

                print LOG "[$1] DROP $3\@$4\n";

                if ($to) { $subject = "$4 just dropped from $host ($3\@ssh)" }

            }

        }

        if ($to && $subject) {

            my $report =

	            MIME::Lite -> new (

                       From    => "bruteDrop\@$host",
                       To      => $to,
                       Subject => $subject,
                       Type    => "text/html",
                       Data    => ""

                    );

            $report -> send;

        }

    }

}
