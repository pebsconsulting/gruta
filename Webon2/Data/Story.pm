package Webon2::Data::Story;

use base 'Webon2::Data::BASE';

sub fields { return qw(id topic_id title date userid format hits ctime content); }

1;
