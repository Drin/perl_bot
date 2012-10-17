use strict;

use IRC::Server;

my $IRC_SRV = IRC::Server->new();

#use constant PERL_IRC  => 'irc.perl.org';
use constant PERL_IRC  => 'chat.freenode.net';
use constant PERL_PORT => 6665;
use constant IRC_NICK  => 'drin';

#print({*STDOUT} PERL_IRC . " " . PERL_PORT . " " . IRC_NICK . "\n");

$IRC_SRV->connect(PERL_IRC, PERL_PORT, IRC_NICK);

while(1) {
   sleep(5);
}
