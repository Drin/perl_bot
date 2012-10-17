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
   my $msg = q{};
   my $has_sent_info = 0;
   my $time_passed = 1;

   my $server_connect = sub {
      my $conn = IRC::Conn->new($name, $port);

      $SIG{'KILL'} = sub {
         $conn->disconnect();
         threads->exit();
      };

      print("connecting to server '$name'...\n");
      $conn->connect();

      while ($conn->{conn}) {
         sleep(2);
         $time_passed++;

         print("checking wire...\n");
         if ($msg = $conn->read()) {
            print $msg;
            $time_passed = 1;
         }

         if (!($time_passed % 5)) {
            if (!$has_sent_info) {
               print("setting USER\n");
               $conn->send("USER $nick 0 * :aldrin\n");

               $has_sent_info = 1;
            }
            elsif ($has_sent_info == 1) {
               print("setting nick to '$nick'\n");
               $conn->send("NICK $nick\n");
               
               $has_sent_info = 2;
            }

            else {
               print("ponging for no reason...\n");
               $conn->send("PONG $name\n");
            }
         }

=waitgoddamnit
         if ($msg =~ m/welcome/i) {

            sleep(2);

            print("joining channel 'tt'\n");
            $conn->send('JOIN #tt\n');
         }
=cut
      }
   };

   $mConnections->{$name} = threads->create($server_connect);
}

sub disconnect {
   my ($server) = @_;

   $mConnections->{$server}->kill('KILL')->join();
}

1;