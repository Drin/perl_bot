#!/usr/bin/perl -w
package IRC::Server;

use strict;
use warnings;

use POSIX;
use threads;
use threads::shared;
use Thread::Queue;

use IRC::Conn;

use constant IRC_EXE => 'ii';

my $mConnections = {};

sub new {
   my ($class) = @_;

   return bless({msg_queue => Thread::Queue->new()}, $class);
}

sub connect {
   my ($self, $name, $port, $nick) = @_;

   my $server_connect = sub {
      my $conn = IRC::Conn->new($name, $port);

      $SIG{'KILL'} = sub {
         $conn->disconnect();
         threads->exit();
      };

      print("connecting to server '$name'...\n");
      $conn->connect();
      print $conn->read();
      print $conn->read();
      print $conn->read();

      print("setting USER\n");
      $conn->send("USER $nick 0 * :Aldrin");

      print("setting nick to '$nick'\n");
      $conn->send("NICK $nick");
      print $conn->read();
      print $conn->read();

      sleep(2);
      print("joining channel 'tt'\n");
      $conn->send('JOIN #tt');

      while ($conn->{conn}) {
         print $conn->read();
      }
   };

   $mConnections->{$name} = threads->create($server_connect);
}

sub disconnect {
   my ($server) = @_;

   $mConnections->{$server}->kill('KILL')->join();
}

1;
