#!/usr/bin/perl -w
package IRC::Server;

use strict;
use warnings;

use POSIX;
use threads;
use threads::shared;
use Thread::Queue;

use IRC::Conn;

my $mConnections = {};

sub new {
   my ($class) = @_;

   return bless({msg_queue => Thread::Queue->new()}, $class);
}

sub connect {
   my ($self, $name, $port, $nick) = @_;
   my $msg = q{};
   my $has_sent_info = 0;

   my $server_connect = sub {
      my $conn = IRC::Conn->new($name, $port);

      $SIG{'KILL'} = sub {
         $conn->disconnect();
         threads->exit();
      };

      $conn->connect();

      while ($conn->{conn}) {
         if ($msg = $conn->read()) {
            print ("$msg");

            if ($msg && !$has_sent_info) {
               $conn->send("USER $nick 0 * :aldrin\r\n");
               $conn->send("NICK $nick\r\n");

               $has_sent_info = 1;
            }
            if ($msg =~ m/^PING(.*)$/i) { $conn->send("PONG $1\r\n"); }
            elsif ($msg =~ m/:welcome/i) { $conn->send('JOIN #csc580\r\n'); }
         }
      }
   };

   $mConnections->{$name} = threads->create($server_connect);
}

sub disconnect {
   my ($server) = @_;

   $mConnections->{$server}->kill('KILL')->join();
}

1;
