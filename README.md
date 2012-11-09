perl_bot
========

This is my IRC chat bot in perl.

In order to run it in the csc580 channel on freenode simply run PROD=true perl
zasz_driver.pl.

I was using TEST=true in order for the bot to go into a channel with just me
that I could test it in.

Notes:
This code requires the following perl modules:
   DBI
   DBD::mysql
   Carp

the other modules should all come default with perl (threads, Thread::Queue,
etc.).

Also, this code was developed for Perl 5.16. I'm not sure what versions it may
or may not be compatible with, though I suspect it should be compatible with
most versions (I believe my coding style is that of 5.8.8).

Also, internet connectivity is *required*. As is, this bot will connect to a
mysql server on my home computer (DNS ssh.eriqaugustine.com points to my home
router and 8906 is a port that goes to my mysql server), and I have not written
the bot in a way that if this fails it will still run.


Write-Up:
This bot was designed in such a way that I could always extend BasicBot to have
a particularly designed bot for some purpose. In particular, I have implemented
an IRC package. In this package, I currently have three files -- Conn.pm,
BasicBot.pm, and ZaszBot.pm. ZaszBot is the bot that I was working on for the
purposes of NLP (CSC 580). Each module is explained in detail below:

Conn.pm is meant to be a module for managing the connection to an IRC server.
This module makes available commands to connect to a server, check if the
connection is still alive, send a message on the connection, and returns
messages received from the connection.

BasicBot.pm is a basic bot. When it is initialized it is passed information for
connecting to an IRC server, some initial channels to join, and a nick for the
bot. The bot initiates a connection to the appropriate server via the Conn.pm
module, and when a response is received it attempts to join a default list of
channels. Beyond this it supplies only the absolute minimum functionality --
parse an incoming message, send a PONG message in response to a PING message,
die when told to, and establish the default message/event handler loop.

ZaszBot.pm is my NLP bot where all the magic (or lack thereof) happens. It
overrides the default_handler method in BasicBot.pm (which is just a stub
anyways) and calls learn, wiki_handler, and converse_handler. Each handler is
meant to handle different tyeps of behavior, and if the input is appropriate
the particular handler will prepare and send a response to the chatroom.

The learn method is for learning events and messages. The idea is that to
satisfy the angel personality, I must accumulate various events or "facts" to
report to everyone. Ideally these should be obvious, but for fun I was trying
to build up to complex and interesting facts. The initial approach is to
collect all of the data of everything that's happening. Ideally my bot would
message a user currently in the channel (I have been trying to develop for
multiple channels, but only tested for a single channel) and say something
along the lines of "HEY! LISTEN!" (Hence the 'Navi-bot' name) and "<so and so>
has <event description>". The specs for the angel personality insist on obvious
events, so it may be something like "P_Rainicorn-bot entered the channel 10
minutes ago!" Or, more interestingly, "P_Rainicorn-bot has messaged
Gustafo-bot 5 times! Boy, they must be good friends." Unfortunately I had not
been able to build up to randomly messaging users in the channel. An extra day
would have been all I needed to get this done but oh well. Additionally, by
logging the entire chat, I could mold the angel personality to essentially be
basic data-mining statistics such as "Boy, P_Rainicorn-bot has logged in 10
times in the last 20 minutes, what does he think we live in a barn?" or "Man
everyone's messages seem to always be only 15 words long. It seems no one knows
english particularly well..." This doesn't necesarily fit the Angel personality
but is significantly more interesting I think. As I want to record more things
or modify certain event/message learning processes, I can add or modify the
learn subroutines easily enough. And since the database connection is a mysql
connection to my home computer then no matter what bot is running they all have
access to a growing set of data.

My other plan, that did not manifest at all, was a plan to use POS tagging in
order to tag input with appropriate parts of speech. Then, by internalizing
verbs as subroutines (add it to the source code) and inputting subjects into
the methods as a parameter, I imagined being able to learn how to respond to
natural language in an interesting way. At the very least, the idea can be
described in this way:
   Person: "Hello Navi-bot! What has been happening today?"

   In this message, there are 2 sentences. Any sentence with a subject and no
   verb is almost certainly going to be a greeting (maybe not but I can work
   under this assumption in the naive case). So the first sentence can be
   ignored if there is extra input, or the response to both sentences can
   consist of a greeting (if a greeting has not already been said to the
   current conversant in the current conversation) and a follow-up response.
   The follow-up response, based on the 2nd input sentence, would be
   constructed by internalizing the verb "happening" and calling the subroutine
   "happen" (a stemmed form of the verb) with the subject or question word
   what. I'm not sure how much work it would have been to implement this, I
   believe dynamically expanding my code with internalized, stemmed verbs would
   not be too difficult in perl (I could even insert it into the database as a
   stored procedure or as perl code that when retrieved gets executed).
   Additionally, by passing the subject/question word to the subroutine
   (passing "what" to "happen") it is possible to appropriately narrow the
   search space of valid responses for "happenings" (which the "happen"
   subroutine would search for an appropriate "happening" given the context of
   the sentence). I ideally would have been able to construct the following
   response:

   Navi-bot: "Hello Person. P_Rainicorn-bot has joined the chat today!"

Despite these plans, I could not progress through the project fast enough to be
able to implement this idea. I look forward, however, to adding this
functionality onto my own recreational IRC bot.

In order to accomodate the Lab3 requirements, I had included a handler
"wiki_handler." This handler simply checks the input against basic regexes
which aim to extract the 'thing' that is being asked about. Additionally, if a
'what' regex is matched, then information is extracted from the appropriate
wiki page. If a 'when' regex is matched, then birthday information is extracted
from the appropriate wiki page. In some cases the regex is unable to isolate or
recognize inputs.

There were two major challenges for me during this project: Figuring out how to
appropriately handle a connection to an IRC server, and not having enough time
to be able to work on this large project in the short amount of time given. I
had attempted to start early on the project, but unfortunately some connection
issues delayed me. Particularly, these issues was simply that even though I
established a connection on which I received responses, I didn't get the
entirety of what should have been included in the response. Later I realized
that the fact that I was sleeping meant that I was not pulling packets off of
the wire fast enough or simply dropping them. By removing the sleep, my IRC
connection started working correctly. By the time I had a successful connection
to IRC established and was developing my model for interacting with the IRC
channel I was swamped by other class work, trying to do actual work, and other
things. Although, now that I think about it. I think it was also difficult to
determine any part of the chat bot that felt particularly "NLP-like". The
chatbot, for any sort of question-response was simple regexes. Clearly these
didn't work as well as one might like, but given the short time frame I didn't
want to even try incorporating more advanced features for handling input. I
really wanted to try the approach mentioned above, but clearly since that would
be an experimental approach that I thought of out of the blue, that would be
difficult to implement and verify.
