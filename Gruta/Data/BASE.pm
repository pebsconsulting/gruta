package Gruta::Data::BASE;

sub new { my $class = shift; return bless({ @_ }, $class); }
sub get { my $self = shift; $self->{$_[0]} = $_[1] if scalar(@_) >= 2; $self->{$_[0]}; }

1;
