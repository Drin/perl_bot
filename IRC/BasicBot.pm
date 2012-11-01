package IRC::BasicBot;

use strict;
use warnings;
use threads;

use IRC::Conn;

use Thread::Queue;

sub new {
   my ($class, $nick, $channels) = @_;

   my $self = {nick => $nick,
               channels => $channels,
               status => 'healthy'};

   return bless($self, $class);
}

sub connect {
   my ($self, $srv, $port) = @_;

   my $thread_work = sub {
      my $conn = IRC::Conn->new($srv, $port);

      while ($conn->{conn}->connected()) {
         $self->default_handler($conn, $conn->read());
      }
   };

   $self->{$srv} = threads->create($thread_work);
}

sub is_connected {
   my ($self, $srv) = @_;

   return $self->{$srv}->is_running();
}

sub default_handler {
   my ($self, $conn, $text) = @_;

   if ($text =~ m/found.*hostname/i) {
      $conn->send("USER $self->{nick} 0 * :aldrin");
      $conn->send("NICK $self->{nick}");
   }

   elsif ($text =~ m/:welcome/i) {
      for my $chan (@{$self->{channels}}) {
         $conn->send("JOIN $chan");
      }
   }

   elsif ($text =~ m/$self->{nick}/i && $text =~ m/die/i) {
      $conn->disconnect();
   }

   elsif ($text =~ m/^PING(.*)$/i) {
      $conn->send("PONG $1");
   }

   else { $self->process($self->parse_msg($text)); }
}

sub parse_msg {
   my ($self, $msg) = @_;
   my ($sender, $chan, $text);

   if ($ENV{DEBUG}) { print ({*STDERR} $msg); }

   if ($msg =~ m/^:(.*?)!.*PRIVMSG ([#]?.*?) :(.*)/) {
      ($sender, $chan, $text) = ($1, $2, $3);
   }

   return ({sender  => $sender,
            channel => $chan,
            text    => $text});
}

sub process {
   my ($self, $msg) = @_;

   if ($ENV{DEBUG} && $msg->{text}) {
      print({*STDERR} "processing message '$msg->{text}'\n".
                      "from '$msg->{sender}'\n".
                      "in channel '$msg->{channel}'\n");
   }
}

1;
