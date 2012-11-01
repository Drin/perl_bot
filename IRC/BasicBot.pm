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
      $self->{irc_conn} = IRC::Conn->new($srv, $port);

      while ($self->{irc_conn}->is_connected()) {
         $self->default_handler($self->{irc_conn}->read());
      }
   };

   $self->{$srv} = threads->create($thread_work);
}

sub is_connected {
   my ($self, $srv) = @_;

   return $self->{$srv}->is_running();
}

sub default_handler {
   my ($self, $text) = @_;

   if ($text =~ m/found.*hostname/i) {
      my $nick = $self->{nick};
      $self->{irc_conn}->send({cmd => 'USER', msg => "$nick 0 * :aldrin"});
      $self->{irc_conn}->send({cmd => 'NICK', msg => "$nick"});
   }

   elsif ($text =~ m/:welcome/i) {
      for my $chan (@{$self->{channels}}) {
         $self->{irc_conn}->send({cmd => 'JOIN', msg => "$chan"});
      }
   }

   elsif ($text =~ m/$self->{nick}/i && $text =~ m/die/i) {
      $self->{irc_conn}->disconnect();
   }

   elsif ($text =~ m/^PING(.*)$/i) {
      $self->{irc_conn}->send({cmd => 'PONG', msg => "$1"});
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
