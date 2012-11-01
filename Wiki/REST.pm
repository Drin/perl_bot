package Wiki::REST;

use strict;
use warnings;

use LWP;

sub new {
   my ($class) = @_;

   my $browser = LWP::UserAgent->new();
   $browser->cookie_jar({});

   my $self = {WIKI_BASE => q{http://en.wikipedia.org},
               WIKI_SEARCH => q{/wiki/Special:Search/},
               browser => $browser};

   return bless($self, $class);
}

sub query {
   my ($self, $http_method, $subject) = @_;

   my $url = $self->{WIKI_BASE}.$self->{WIKI_SEARCH}.$subject;

   if (my $response = $self->{browser}->$http_method($url, [], {})) {
      if ($response->is_success()) { return $response; }
   }

   return;
}

1;
