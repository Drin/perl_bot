package IRC::BasicBot;

use strict;
use warnings;
use threads;

use IRC::Conn;

use Thread::Queue;

sub new {
   my ($class, $nick) = @_;

   my $self = {nick => $nick, status => 'healthy'};

   return bless($self, $class);
}

sub default_handler {
   my ($self, $conn, $msg) = @_;

   print ({*STDERR} $msg);

   if ($msg =~ m/found.*hostname/i) {
      $conn->send("USER $self->{nick} 0 * :aldrin");
      $conn->send("NICK $self->{nick}");
   }

   elsif ($msg =~ m/:welcome/i) {
      $conn->send("JOIN #hive");
   }

   elsif ($msg =~ m/^PING(.*)$/i) { $conn->send("PONG $1"); }
}

sub connect {
   my ($self, $srv, $port) = @_;

   my $thread_work = sub {
      my $conn = IRC::Conn->new($srv, $port);
      $conn->connect();

      $SIG{KILL} = sub {
         $conn->disconnect();
         threads->exit();
      };

      while ($conn->{conn}) {

         if (my $msg = $conn->read()) {
            if ($msg =~ m/die/i) {
               $conn->disconnect($srv);
               last;
            }

            $self->default_handler($conn, $msg);
         }
      }

      print({*STDERR} "Thread work finished!\n");
   };

   $self->{$srv} = threads->create($thread_work);
}

sub disconnect {
   my ($self, $srv) = @_;

   if ($self->{$srv}) { $self->{$srv}->kill('KILL')->join(); }
   else { print({*STDERR} "unable to disconnect from '$srv'\n"); }

   return $self->{$srv}->is_running();
}

sub is_connected {
   my ($self, $srv) = @_;

   return $self->{$srv}->is_running();
}

1;