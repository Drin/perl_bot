use strict;

use IRC::ZaszBot;
use Wiki::REST;

use constant FREENODE_SRV  => 'irc.freenode.net';
use constant FREENODE_PORT => 6665;
use constant FREENODE_NICK => 'Navi-bot';

use constant PERL_IRC  => 'irc.perl.org';
use constant PERL_PORT => 6667;
use constant PERL_NICK => 'Zasz';

sub main {
   my $zasz = IRC::ZaszBot->new(PERL_NICK, [q{#hive}]);

   $zasz->connect(PERL_IRC, PERL_PORT);

   while ($zasz->is_connected(PERL_IRC)) { }
}

main();
