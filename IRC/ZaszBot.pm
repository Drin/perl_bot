package IRC::ZaszBot;

use parent 'IRC::BasicBot';
use Wiki::REST;

use DBI;

use constant DB => 'zasz';
use constant DB_HOST => 'ssh.eriqaugustine.com';
use constant DB_PORT => 8906;

use constant DB_USER => 'zasz';
use constant DB_PASS => 'Z4sZ';

sub new {
   my ($class, $nick, $channels) = @_;
   my $self = $class->SUPER::new($nick, $channels);

   $self->{wiki_conn} = Wiki::REST->new();
   $self->{conversations} = {};
   $self->{patience} = 35;
   $self->{timer} = time;

   return $self;
}

sub connect_brain {
   my ($self) = @_;

   my $db_connect = q{DBI:mysql:zasz}.q{;host=}.DB_HOST.q{;port=}.DB_PORT;
   $self->{brain} = DBI->connect($db_connect, 'zasz', 'Z4sZ') or
   die ("$1\n\n$DBI::errstr\n");

   return;
}

sub default_handler {
   my ($self, $text) = @_;

   my $parsed_msg = $self->SUPER::default_handler($text);

   if ($parsed_msg->{text}) {
      print({*STDERR} "parsed message:\n");
      for my $msg_key (keys %{$parsed_msg}) {
         print({*STDERR} "\t$msg_key => $parsed_msg->{$msg_key}\n");
      }
   }
   $self->learn($parsed_msg);

   $self->wiki_handler($parsed_msg);
   $self->converse_handler($parsed_msg);

   return $parsed_msg;
}

sub wiki_handler {
   my ($self, $msg) = @_;

   my $msg_type = $self->classify_msg($msg);
   my $response = $self->$msg_type($msg);

   if ($response && $response->{content}) {
      print({*STDERR} "response: $response->{content}\n");
   }

   if ($msg->{directed} && $response && $response->{content}) {
      return $self->handle_response($response);
   }
}

sub converse_handler {
   my ($self, $msg) = @_;

   if ($msg->{sender} && $msg->{sender} !~ m/^$self->{nick}$/ &&
       $msg->{directed} && !$self->is_conversing($msg->{sender})) {
      $self->handle_response($self->greet_response($msg));
      return;
   }

   for my $converser (keys %{$self->{conversations}}) {
      my $converse_state = $self->get_converse_state($converser);

      if ($converse_state =~ m/inquire/) {
         $self->$converse_state($converser);
      }
      elsif ($converse_state =~ m/secondary|give_up/) {
         if ($msg->{text} && $msg->{directed}) {
            $self->{timer} = time;
            $self->$converse_state($converser, $msg);
         }
         elsif ((time - $self->{timer}) > $self->{patience}) {
            $self->{timer} = time;
            $self->$converse_state($converser);
         }
      }
   }
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
                               targets => [$response->{channel}]});
   }
}

################################################################################
#
# Knowledge based subroutines for learning events and information
#
################################################################################

sub learn {
   my ($self, $msg) = @_;

   if ($msg->{type} =~ m/JOIN/) { $self->learn_user($msg->{sender}); }
   if ($msg->{type} =~ m/PRIVMSG/) { $self->learn_msg($msg); }
   if ($msg->{type}) { $self->learn_event($msg->{sender}, $msg->{type}); }

   return;
}

sub learn_msg {
   my ($self, $msg) = @_;

   my $sql_statement = $self->{brain}->prepare('
   INSERT INTO user_messages(sender_user_name, recipient_user_name,
                             message_text, message_time)
               values       (?, ?, ?, ?)
   ');

   $sql_statement->bind_param(1, $msg->{sender});
   $sql_statement->bind_param(2, $msg->{target});
   $sql_statement->bind_param(3, $msg->{text});
   $sql_statement->bind_param(4, $self->SUPER::get_current_time());
   $sql_statement->execute();

   return $self->{brain}->{executed};
}

sub learn_user {
   my ($self, $user) = @_;

   my $sql_statement = $self->{brain}->prepare('CALL add_user(?)');
   $sql_statement->bind_param(1, $user);
   $sql_statement->execute();

   return $self->{brain}->{executed};
}

sub learn_event {
   my ($self, $user, $type) = @_;

   my $sql_statement = $self->{brain}->prepare('
   INSERT INTO user_events(user_name, event_type, event_date) values (?, ?, ?)
   ');
   
   $sql_statement->bind_param(1, $user);
   $sql_statement->bind_param(2, $type);
   $sql_statement->bind_param(3, $self->SUPER::get_current_time());
   $sql_statement->execute();

   return $self->{brain}->{executed};
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
   
   return 'unknown_topic';
}

sub unknown_topic { return {type => 'none', content => q{}}; }

sub info_topic {
   my ($self, $msg) = @_;
   my ($text, $content) = ($msg->{text}, q{});

   my $what_regex = '(?:who|what) (?:is|are) (.*)[?]?';
   my $tell_regex = '(?:tell me about|describe) (.*)[.?]?';
   my $inquiry_regex = 'to (?:know|hear) more? about (.*)[.]?';

   $text =~ s/(?:the|an|a) //g;

   if ($text =~ m/$what_regex|$tell_regex|$inquiry_regex/i) {
      $content = $1 || $2 || $3;
   }

   $content =~ s/\W*$//;

   return {type => 'info_lookup', content => $content,
           channel => $msg->{channel}};
}

sub bday_topic {
   my ($self, $msg) = @_;
   my ($text, $content) = ($msg->{text}, q{});

   my $when_regex = 'when (?:was|is) (.*) (?:born|birth.*)[?]?';
   my $what_regex = '(?:what|when) (?:day )?(?:was|is) (?:the birth.*? of )?'.
                    '(.*) (?:birth.*|born)?[?]?';

   $text =~ s/[']s//g;

   if ($text && $text =~ m/$what_regex|$when_regex/i) {
      $content = $1 || $2;
   }

   return {type => 'bday_lookup', content => $content,
           channel => $msg->{channel}};
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

   if ($msg->{text} =~ m/h[ea]llo|how.*you|greet|hi|hey/) {
      $self->{conversations}->{$msg->{sender}} = 'inquire';

      my @text_words = split(qr/ /, $msg->{text});

      if (scalar @text_words > 2) {
         $content = "$msg->{sender}: Hello to you too!";
      }
      else { $content = "Hello $msg->{sender}"; }

      return {type => 'conversation', content => $content,
              channel => $msg->{channel}};
   }
}

sub inquire_response {
   my ($self, $msg) = @_;
   my $content = "I'm good. It was nice talking to you!";
   return {type => 'conversation', content => $content,
           channel => $msg->{channel}};
}

sub init_greeting {
   my ($self, $converser) = @_;
   $self->{conversations}->{$converser} = 'secondary';
   $self->handle_response({type    => 'conversation',
                           content => "$converser: Hey!",
                           channel => $msg->{channel}});
}

sub inquire {
   my ($self, $converser) = @_;
   $self->{conversations}->{$converser} = 'give_up';
   $self->handle_response({type    => 'conversation',
                           content => "$converser: How are you?",
                           channel => $msg->{channel}});
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
      $self->handle_response({type    => 'conversation',
                              content => "$converser: HEY! LISTEN!",
                              channel => $msg->{channel}});
   }
}

sub give_up {
   my ($self, $converser, $msg) = @_;

   if ($msg && $msg->{text}) {
      $self->handle_response($self->inquire_response($msg));
   }
   else {
      $self->handle_response({type    => 'conversation',
                              content => "$converser: ...awkward",
                              channel => $msg->{channel}});
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
         if (!$self->report_info($1, $topic->{channel})) { next; }
         else { last; }
      }
   }
   elsif($topic->{type} =~ m/bday/) {
      if ($wiki_content =~ m/class="fn">$topic->{content}<.*?class="bday">(.*?)</si) {
         $self->report_bday($topic->{content}, $topic->{channel}, $1);
      }
      elsif ($wiki_content =~ m/class="bday">(.*?)</si) {
         $self->report_bday($topic->{content}, $topic->{channel}, $1);
      }
   }
}

sub report_info {
   my ($self, $wiki_paragraph, $channel) = @_;

   if ($wiki_paragraph =~ m/<small>|^\d+/i) { return; }
   elsif ($wiki_paragraph =~ m/(?:may refer to|help:searching)/i) {
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => q{:That information escapes me right now...},
                               targets => [$channel]});
   }

   $wiki_paragraph =~ s/(?:<.*?>)|(?:\[.*?\])//sg;

   if ($wiki_paragraph =~ m/((?:.*?[.]){2,4})/sg) {
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => ":$1",
                               targets => [$channel]});
   }
}

sub report_bday {
   my ($self, $subj, $channel, $date) = @_;

   my @months = qw{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};

   if ($date =~ m/(\d{4})-(\d\d)-(\d\d)/) {
      my $month = $months[($2 - 1)];
      $self->{irc_conn}->send({cmd => 'PRIVMSG',
                               msg => ":$subj\'s birthday is $month $3, $1",
                               targets => [$channel]});
   }
}

1;
