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
      $self->connect_brain();

      while ($self->{irc_conn}->is_connected()) {
         $self->default_handler($self->{irc_conn}->read());
      }
   };

   $self->{$srv} = threads->create($thread_work);
}

sub connect_brain { return; }

sub is_connected {
   my ($self, $srv) = @_;

   return $self->{$srv}->is_running();
}

sub cleanup {
   my ($self, $srv) = @_;

   $self->{$srv}->join();
}

sub default_handler {
   my ($self, $text) = @_;

   my $parsed_msg = $self->parse_msg($text);

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

   elsif ($text =~ m/$self->{nick}.*die/i) {
      $self->{irc_conn}->disconnect();
   }

   elsif ($text =~ m/^PING(.*)$/i) {
      $self->{irc_conn}->send({cmd => 'PONG', msg => "$1"});
   }

   elsif ($parsed_msg->{command}) {
      $self->process_command($parsed_msg);
   }

   return $parsed_msg;
}

sub parse_msg {
   my ($self, $msg) = @_;
   my ($sender, $chan, $text, $target, $type, $command, $directed);

   if ($ENV{DEBUG}) { print ({*STDERR} $msg); }

   if ($msg =~ m/^:(.*?)!.*?([A-Z]+) ([#]?.*?)? ?:(.*)/) {
      ($sender, $type, $chan, $text) = ($1, $2, $3, $4);
   }

   if ($text) {
      if ($text =~ s/^(\w+)[:,]//) { $target = $1; }
      elsif ($chan =~ m/$self->{nick}/) { $target = $self->{nick}; }
      else { $target = q{}; }

      $command = $text =~ s/^%//;
      $text =~ s/^\W*//;
      $text =~ s/\r//;
   }

   if ($chan && $chan =~ m/$self->{nick}/) { $chan = $sender; }

   if ($target) { $directed = $target =~ m/$self->{nick}/; }
   else { $directed = 0; }

   return ({type     => $type,
            command  => $command,
            sender   => $sender,
            target   => $target,
            directed => $directed,
            channel  => $chan,
            text     => $text});
}

sub process_command {
   my ($self, $msg) = @_;

   if ($msg->{command} && $msg->{directed}) {
      if ($self->can("$msg->{text}")) {
         my $sub = $msg->{text};
         $self->$sub();
      }
   }

   return;
}

################################################################################
#
# Utility subroutines for interacting with the IRC channel
#
################################################################################

#TODO
sub get_users {
   my ($self, $channels) = @_;

   my $channel_str = join(q{,}, @{$channels || $self->{channels}});

   print({*STDERR} "getting users from channels $channel_str\n");

   $self->{irc_conn}->send({cmd => 'LIST', msg => "$channel_str"});

   return;
}

################################################################################
#
# Utility subroutines for miscellaneous reasons
#
################################################################################
sub get_current_time {
   my @time_fields = localtime;

   my $time = sprintf("%02d%02d%02d", @time_fields[2, 1, 0]);
   my $date = sprintf("%04d%02d%02d", $time_fields[5] + 1900,
                                      @time_fields[4, 3]);
   return "$date$time";
}

1;
