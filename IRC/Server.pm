#!/usr/bin/perl -w
package IRC::Server;

use strict;
use warnings;

use POSIX;
use threads;
use threads::shared;

use constant IRC_EXE => 'ii';

my $mConnections = {};

sub new {
   my ($class, $irc_dir) = @_;

   if (-d $irc_dir) {
      my $self = {dir => $irc_dir};
      return bless $self;
   }

   return;
}

sub connect {
   my ($self, $name, $port, $nick) = @_;

   my $server_connect = sub {
      my $srv_name = "-s $self->{name}";
      my $port     = "-p $self->{port}";
      my $login    = "-n $nick";

      $SIG{'KILL'} = sub { threads->exit(); };

      print("connecting to server '$self->{name}'...\n");
      system(IRC_EXE . " -s $server $port $login");
   }

   $mConnections->{$server} = threads->create($server_connect);
}

sub disconnect {
   my ($server) = @_;

   $mConnections->{$server}->kill('KILL')->detach();
}
