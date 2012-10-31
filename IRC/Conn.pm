#!/usr/bin/perl
package IRC::Conn;

use strict;
use warnings;
use Carp;

use IO::Socket;
use IO::Select;

sub new {
   my ($class, $srv, $port, $proto) = @_;

   if (!$srv || !$port) {
      print({*STDERR} "Invalid connection request: $srv : $port\n");
      return;
   }

   $proto = $proto || 'tcp';

   my $self = {remote => $srv, port => $port, proto => $proto,
               channels => [], manager => IO::Select->new()};

   return bless($self, $class);
}

sub connect {
   my ($self) = @_;

   $self->{conn} = IO::Socket::INET->new(PeerAddr => $self->{remote},
                                         PeerPort => $self->{port},
                                         Proto    => $self->{proto})
   or croak("Unable to connect to IRC\n");

   $self->{manager}->add($self->{conn});
}

sub disconnect {
   my ($self) = @_;

   $self->send("QUIT I must go now, OH WOE IS ME!");
   close($self->{conn});
}

sub read {
   my ($self) = @_;
   my $msg = q{};

   for my $fh ($self->{manager}->can_read(2)) { $msg = <$fh>; }
   return $msg;
}

sub send {
   my ($self, $msg) = @_;

   print({*STDERR} "$msg\n");
   print({$self->{conn}} "$msg\n");
}

1;
