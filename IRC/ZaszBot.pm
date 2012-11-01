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
   my $inquiry_regex = 'to (?:know|hear) more? about (.*)[.]?';

   $text =~ s/(?:the|an|a) //g;

   if ($text =~ m/$what_regex|$tell_regex|$inquiry_regex/i) {
      return $1 || $2 || $3;
   }

   return;
}

sub get_bday_topic {
   my ($self, $text) = @_;

   my $when_regex = 'when was (.*) born[?]?';
   my $what_regex = 'what (?:day )?(?:was|is) (?:the )?(?:birth.*? of )?(.*)(?:\'s .*?)?[?]?';

   if ($text && $text =~ m/$when_regex|$what_regex/i) {
      return $1 || $2;
   }

   return;
}

sub process {
   my ($self, $msg) = @_;

   my $search_topic = $self->get_topic($msg->{text});
   my $bday_topic   = $self->get_bday_topic($msg->{text});

   if ($msg->{text} =~ m/$self->{nick}/i && ($search_topic || $bday_topic)) {
      my $wiki_content = $self->{wiki_conn}->query('get',
                                                   ($search_topic || $bday_topic));

      if ($search_topic) {
         $wiki_content =~ s/(?:<table.*?>.*?)?<\/table>//sig;

         while ($wiki_content =~ m{<p>(.*?)</p>}sig) {
            if (!$self->get_info($1)) { next; }
            else { last; }
         }
      }
      elsif($bday_topic) {
         if ($wiki_content =~ m/$bday_topic.*?class="bday">(.*?)</si) {
            #if ($wiki_content =~ m/class="bday">(.*?)</s) {
            print({*STDERR} "reporting birthday..\n");
            $self->report_bday($bday_topic, $1);
         }
      }
   }
}

sub get_info {
   my ($self, $wiki_paragraph) = @_;

   if ($wiki_paragraph =~ m/<small>|^\d+/i) { return 0; }
   elsif ($wiki_paragraph =~ m/(?:may refer to|help:searching)/i) {
      print({*STDERR} "confusing page: $wiki_paragraph\n");

      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => q{:That information escapes me right now...},
                               targets => $self->{channels}});
      return 1;
   }

   $wiki_paragraph =~ s/(?:<.*?>)|(?:\[.*?\])//sg;

   while ($wiki_paragraph =~ m/((?:.*?[.]){2,4})/sg) {
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => ":$1",
                               targets => $self->{channels}});
   }

   return 1;
}

sub report_bday {
   my ($self, $subj, $date) = @_;

   print ({*STDERR} "bdate: $date\n");

   my @months = qw{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};

   if ($date =~ m/(\d{4})-(\d\d)-(\d\d)/) {
      my $month = $months[($2 - 1)];
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => ":$subj\'s birthday is $month $3, $1",
                               targets => $self->{channels}});
   }
}

1;
