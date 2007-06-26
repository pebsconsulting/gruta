package Webon2::Data::Topic;

sub new { my $class = shift; return bless({ @_ }, $class); }

sub source { $_[0]->{source}; }

1;
