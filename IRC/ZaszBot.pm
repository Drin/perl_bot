package IRC::ZaszBot;

use parent 'IRC::BasicBot';
use Wiki::REST;

sub new {
   my ($class, $nick, $channels) = @_;
   my $self = $class->SUPER::new($nick, $channels);

   $self->{wiki_conn} = Wiki::REST->new();

   return $self;
}

sub get_topic {
   my ($self, $text) = @_;

   my $what_regex = '(?:who|what) (?:is|are) (.*)[?]?';
   my $tell_regex = '(?:tell me about|describe) (.*)[.?]?';

   if ($text =~ m/$what_regex/i) {
      return $1;
   }
   elsif ($text =~ m/$tell_regex/i) {
      return $1;
   }

   return;
}

sub process {
   my ($self, $msg) = @_;

   if ($msg->{text} =~ m/$self->{nick}/i &&
      (my $topic = $self->get_topic($msg->{text}))) {
      my $wiki_res = $self->{wiki_conn}->query('get', $topic);

      while (!$wiki_res->is_success()) {
         $topic =~ s/^\w+//;
         $wiki_res = $self->{wiki_conn}->query('get', $topic);
      }

      my $content = $wiki_res->content;

      $content =~ s{<table>.*?</table>}{}g;

      while ($content =~ m{(?:</table>.*?)?
                           <p>(.*?)</p>
                           (?:.*?<table>)?}gisx) {
         my $wiki_info = $1;

         print({*STDERR} "info: '$wiki_info'\n");

         if ($wiki_info =~ m/<small>|^\d+/i) { next; }
         elsif ($wiki_info =~ m/help:searching/i) {
            $self->{irc_conn}->send({cmd => 'PRIVMSG',
                                     msg => q{:Sorry, I don't know.},
                                     targets => $self->{channels}});
            last;
         }
         elsif ($wiki_info =~ m/may refer to/i) {
            $self->{irc_conn}->send({cmd => 'PRIVMSG',
                                     msg => q{:It's tough to figure out...},
                                     targets => $self->{channels}});

            $self->{irc_conn}->send({cmd => 'PRIVMSG',
                                     msg => q{:Sorry, I'm not sure :(},
                                     targets => $self->{channels}});
            last;
         }

         $wiki_info =~ s/<.*?>|\[.*\]//g;
         my $num_sentences = 0;

         while ($wiki_info =~ m/[.]/g) { $num_sentences++; }

         if ($wiki_info =~ m/^((?:.*?[.]){0,$num_sentences})/) {
            $self->{irc_conn}->send({cmd => 'PRIVMSG',
                                     msg => ":$1",
                                     targets => $self->{channels}});
            last;
         }
      }
   }
}

1;
