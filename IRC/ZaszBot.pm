package IRC::ZaszBot;

use parent 'IRC::BasicBot';

sub new {
   my ($class, $nick, $channels) = @_;
   my $self = $class->SUPER::new($nick, $channels);

   return $self;
}

1;
