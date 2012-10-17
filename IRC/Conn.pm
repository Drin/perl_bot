#!/usr/bin/perl
package IRC::Conn;

use strict;
use warnings;

use IO::Socket; # qw{PF_INET SOCK_STREAM};
use IO::Select;

my %PROTOCOL_CONF = (
   tcp => [PF_INET, SOCK_STREAM],
);

sub get_proto_conf {
   my ($proto) = @_;

   return (@{$PROTOCOL_CONF{$proto}}, getprotobyname($proto));
}

sub new {
   my ($class, $srv, $port, $proto) = @_;

   if (!$srv || !$port) {
      print({*STDERR} "Invalid connection request: $srv : $port\n");
      return;
   }

   $proto = $proto || "tcp";

   my $addr = sockaddr_in($port, inet_aton($srv));
   my $self = {remote => $srv, port => $port, proto => $proto, addr => $addr,
               manager => IO::Select->new()};

   $self->{conn} = IO::Socket::INET->new(PeerAddr => $srv,
                                         PeerPort => $port,
                                         Proto    => $proto);

   return bless($self, $class);
}

sub connect {
   my ($self) = @_;

   #socket($self->{conn}, PF_INET, SOCK_STREAM, getprotobyname($self->{proto})) or die("socket: $!");
   #connect($self->{conn}, $self->{addr}) or die("connect: $!");

   $self->{manager}->add($self->{conn});

   return;
}

sub disconnect {
   my ($self) = @_;

   close($self->{conn});
   return;
}

sub read {
   my ($self) = @_;
   my $msg = q{};

   my @fh_list = $self->{manager}->can_read(1);

   if (scalar @fh_list > 0)  { print("got message!\n"); }
   else  { print("no message...\n"); }

   for my $fh (@fh_list) {
      $msg = <$fh>;
   }

   return $msg;
}

sub send {
   my ($self, $msg) = @_;
   print ("sending message $msg\n");
   print({$self->{conn}} $msg);

   return;
}

1;
