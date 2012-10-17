#!/usr/bin/perl
package IRC::Conn;

use strict;
use warnings;

use IO::Socket; # qw{PF_INET SOCK_STREAM};

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
   my $self = {remote => $srv, port => $port, proto => $proto, addr => $addr};

   return bless($self, $class);
}

sub connect {
   my ($self) = @_;

   socket($self->{conn}, PF_INET, SOCK_STREAM, getprotobyname($self->{proto})) or die("socket: $!");
   connect($self->{conn}, $self->{addr}) or die("connect: $!");

   return;
}

sub disconnect {
   my ($self) = @_;

   close($self->{conn});
   return;
}

sub read {
   my ($self) = @_;
   my $fh = $self->{conn};
   my $msg = <$fh>;

   return $msg;
   #return;
}

sub send {
   my ($self, $msg) = @_;
   print ("sending message $msg\n");
   print({$self->{conn}} $msg);

   return;
}

1;
