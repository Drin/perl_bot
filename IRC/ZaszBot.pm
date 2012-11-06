package IRC::ZaszBot;

use parent 'IRC::BasicBot';
use Wiki::REST;

sub new {
   my ($class, $nick, $channels) = @_;
   my $self = $class->SUPER::new($nick, $channels);

   $self->{wiki_conn} = Wiki::REST->new();
   $self->{conversations} = {};
   $self->{patience} = 35;
   $self->{timer} = time;

   return $self;
}

sub default_handler {
   my ($self, $text) = @_;

   my ($did_something, $parsed_msg) = $self->SUPER::default_handler($text);

   if (!$did_something) {
      $self->converse_handler($parsed_msg);
      return 1;
   }

   return 0;
}

sub converse_handler {
   my ($self, $msg) = @_;

   if ($msg->{sender} && $msg->{sender} !~ m/^$self->{nick}$/ &&
       !$self->is_conversing($msg->{sender})) {
      $self->handle_response($self->greet_response($msg));
      return;
   }

   for my $converser (keys %{$self->{conversations}}) {
      my $converse_state = $self->get_converse_state($converser);

      if ($converse_state =~ m/inquire/) {
         $self->$converse_state($converser);
      }
      elsif ($converse_state =~ m/secondary|give_up/) {
         if ($msg->{text} && $msg->{text} =~ m/$self->{nick}/) {
            $self->{timer} = time;
            $self->$converse_state($converser, $msg);
         }
         elsif ((time - $self->{timer}) > $self->{patience}) {
            print({*STDERR} "I'm TOO IMPATIENT!\n");

            $self->{timer} = time;
            $self->$converse_state($converser);
         }
      }
   }
}

################################################################################
#
# Method for processing input; i.e. controller
#
################################################################################

sub process {
   my ($self, $msg) = @_;

   my $get_msg_type = 'get_'.$self->classify_msg($msg);
   my $response = $self->$get_msg_type($msg);

   if ($response->{type} =~ m/unknown/i) {
      return 0;
   }

   elsif ($msg->{text} =~ m/$self->{nick}/i && $response) {
      return $self->handle_response($response);
   }

   return 0;
}

sub handle_response {
   my ($self, $response) = @_;

   if ($response->{type} =~ m/lookup/) {
      my $wiki_content = $self->{wiki_conn}->query('get', $response->{content});
      return $self->report_content($response, $wiki_content);
   }

   elsif ($response->{type} =~ m/conversation/) {
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => ":$response->{content}",
                               targets => $self->{channels}});
      return 1;
   }

   return 0;
}

################################################################################
#
# Message handler subroutines
#
################################################################################

sub classify_msg {
   my ($self, $msg) = @_;

   if ($msg->{text} =~ m/birth|born/i) { return 'bday_topic'; }

   elsif ($msg->{text} =~ m/what (?:is|are)|tell me about/i) { return 'info_topic'; }

=cut
   elsif ($msg->{text} =~ m/$self->{nick}/ ||
          $msg->{channel} =~ m/$self->{nick}/) {
      return 'conversation';
   }
=cut
   
   return 'unknown';
}

sub get_info_topic {
   my ($self, $msg) = @_;
   my ($text, $content) = ($msg->{text}, q{});

   my $what_regex = '(?:who|what) (?:is|are) (.*)[?]?';
   my $tell_regex = '(?:tell me about|describe) (.*)[.?]?';
   my $inquiry_regex = 'to (?:know|hear) more? about (.*)[.]?';

   $text =~ s/(?:the|an|a) //g;

   if ($text =~ m/$what_regex|$tell_regex|$inquiry_regex/i) {
      $content = $1 || $2 || $3;
   }

   return {type => 'info_lookup', content => $content};
}

sub get_bday_topic {
   my ($self, $msg) = @_;
   my ($text, $content) = ($msg->{text}, q{});

   my $when_regex = 'when (?:was|is) (.*) (?:born|birth.*)[?]?';
   my $what_regex = '(?:what|when) (?:day )?(?:was|is) (?:the birth.*? of )?'.
                    '(.*) (?:birth.*|born)?[?]?';

   $text =~ s/[']s//g;

   if ($text && $text =~ m/$what_regex|$when_regex/i) {
      $content = $1 || $2;
      print({*STDERR} "content:$content\n");
   }

   return {type => 'bday_lookup', content => $content};
}

=cut
sub get_conversation {
   my ($self, $msg) = @_;
   my $content = q{};

   if ($self->is_conversing($msg->{sender})) {
      my $converse_state = $self->get_converse_state($msg->{sender});
      $self->$converse_state($msg);
   }
   else { return $self->greet_response($msg); }
}
=cut

sub get_unknown {
   my ($self, $msg) = @_;

   return {type => 'none', content => q{}};
}

################################################################################
#
# Conversational subroutines
#
################################################################################

sub is_conversing {
   my ($self, $converser) = @_;
   return $self->{conversations}->{$converser};
}

sub get_converse_state {
   my ($self, $converser) = @_;
   return $self->{conversations}->{$converser};
}

sub greet_response {
   my ($self, $msg) = @_;

   $self->{conversations}->{$msg->{sender}} = 'inquire';

   my @text_words = split(qr/ /, $msg->{text});

   if (scalar @text_words > 1) {
      $content = "$msg->{sender}: Hello to you too!";
   }
   else { $content = 'Hello'; }

   return {type => 'conversation', content => $content};
}

sub inquire_response {
   my ($self, $msg) = @_;
   my $content = "I'm good. It was nice talking to you!";
   return {type => 'conversation', content => $content};
}

sub init_greeting {
   my ($self, $converser) = @_;
   $self->{conversations}->{$converser} = 'secondary';
   $self->handle_response({type => 'conversation',
                           content => "$converser: Hey!"});
}

sub inquire {
   my ($self, $converser) = @_;
   $self->{conversations}->{$converser} = 'give_up';
   $self->handle_response({type => 'conversation',
                           content => "$converser: How are you?"});
}

sub secondary {
   my ($self, $converser, $msg) = @_;

   if ($msg && $msg->{text}) {
      $self->handle_response($self->inquire_response($msg));
      delete $self->{conversations}->{$converser};
      return;
   }
   else {
      $self->{conversations}->{$converser} = 'give_up';
      $self->handle_response({type => 'conversation',
                              content => "$converser: HEY! LISTEN!"});
   }
}

sub give_up {
   my ($self, $converser, $msg) = @_;

   if ($msg && $msg->{text}) {
      $self->handle_response($self->inquire_response($msg));
      return;
   }
   else {
      $self->handle_response({type => 'conversation',
                              content => "$converser: ...awkward"});
   }

   delete $self->{conversations}->{$converser};
}

################################################################################
#
# Informational reporting subroutines
#
################################################################################

sub report_content {
   my ($self, $topic, $wiki_content) = @_;

   if ($topic->{type} =~ m/info/) {
      $wiki_content =~ s/(?:<table.*?>.*?)?<\/table>//sig;

      while ($wiki_content =~ m{<p>(.*?)</p>}sig) {
         if (!$self->report_info($1)) { next; }
         else { last; }
      }

      return 1;
   }
   elsif($topic->{type} =~ m/bday/) {
      if ($wiki_content =~ m/class="fn">$topic->{content}<.*?class="bday">(.*?)</si) {
         $self->report_bday($topic->{content}, $1);
      }
      elsif ($wiki_content =~ m/class="bday">(.*?)</si) {
         $self->report_bday($topic->{content}, $1);
      }

      return 1;
   }

   return 0;
}

sub report_info {
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
