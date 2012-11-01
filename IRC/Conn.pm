#!/usr/bin/perl
package IRC::Conn;

use strict;
use warnings;
use Carp;

use IO::Socket;
use IO::Select;

my $MAX_MSG_LEN = 450;

sub new {
   my ($class, $srv, $port, $proto) = @_;

   if (!$srv || !$port) {
      print({*STDERR} "Invalid connection request: $srv : $port\n");
      return;
   }

   $proto = $proto || 'tcp';

   my $self = {remote => $srv, port => $port, proto => $proto,
               channels => [], manager => IO::Select->new()};

   $self->{conn} = IO::Socket::INET->new(PeerAddr => $self->{remote},
                                         PeerPort => $self->{port},
                                         Proto    => $self->{proto})
   or croak("Unable to connect to IRC\n");

   $self->{manager}->add($self->{conn});

   return bless($self, $class);
}

sub disconnect {
   my ($self) = @_;

   $self->send({cmd => 'QUIT', msg => ":I must go now, OH WOE IS ME!"});
   close($self->{conn});
}

sub read {
   my ($self) = @_;
   my $msg = q{};

   for my $fh ($self->{manager}->can_read(1)) { $msg = <$fh>; }
   return $msg;
}

sub send {
   my ($self, $msg_info) = @_;
   my $target_list = q{};

   if ($msg_info->{targets}) {
      $target_list = join(q{,}, @{$msg_info->{targets}}).' ';
   }

   print({$self->{conn}} "$msg_info->{cmd} $target_list$msg_info->{msg}\n");
}

sub is_connected {
   my ($self) = @_;

   return $self->{conn}->connected();
}

1;
