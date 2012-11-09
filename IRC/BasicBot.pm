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
               status => 'healthy',
               expect_handler => q{},
               user_list => {}};

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

   if ($parsed_msg && $parsed_msg->{text}) {
      my $text = $parsed_msg->{text};
      $text =~ s/\r//;
      print({*STDERR} "msg text: '$text'\n");
   }

   if (my $handle_method = $self->{expect_handler}) {
      $self->$handle_method($parsed_msg);
   }
   elsif ($text =~ m/look.*hostname/i) {
      $self->{irc_conn}->send({cmd => 'USER',
                               msg => "$self->{nick} 0 * :aldrin"});
      $self->{irc_conn}->send({cmd => 'NICK', msg => "$self->{nick}"});
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
   else { return {text => $msg}; }

   if ($text) {
      if ($text =~ s/^((?:\w|\-)+)[:,]//) { $target = $1; }
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

sub get_users {
   my ($self, $channels) = @_;

   my $channel_str = join(q{,}, @{$channels || $self->{channels}});

   $self->{irc_conn}->send({cmd => 'WHO', msg => "$channel_str"});
   $self->{expect_handler} = 'parse_users';

   return;
}

sub parse_users {
   my ($self, $msg) = @_;

   if ($msg && $msg->{text}) {
      if ($msg->{text} =~ m/End.*who/i) {
         $self->{expect_handler} = q{};

         print({*STDERR} "current user list:\n");
         for my $user (keys %{$self->{user_list}}) {
            print({*STDERR} "\t$user\n");
         }
      }
      if ($msg->{text} =~ m/[*] (.*?) H/) { $self->{user_list}->{$1} = 1; }
   }

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
