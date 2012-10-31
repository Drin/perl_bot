use strict;

use IRC::BasicBot;

use constant FREENODE_SRV  => 'irc.freenode.net';
use constant FREENODE_PORT => 6665;
use constant FREENODE_NICK => 'Navi-bot';

use constant PERL_IRC  => 'irc.perl.org';
use constant PERL_PORT => 6667;
use constant PERL_NICK => 'Zasz';

#print({*STDOUT} PERL_IRC . " " . PERL_PORT . " " . IRC_NICK . "\n");

sub main {
   my $bot = IRC::BasicBot->new(PERL_NICK);

   $bot->connect(PERL_IRC, PERL_PORT);

   while (1) {
      if (!$bot->is_connected(PERL_IRC)) {
         last;
      }
   }

   print ({*STDERR} "bot is dead, I'm out!\n");
}

main();
