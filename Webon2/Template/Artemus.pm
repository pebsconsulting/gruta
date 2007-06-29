package Webon2::Template::Artemus;

use Artemus;

sub new {
	my $class	= shift;
	my %args	= shift;

	my $a = bless( {}, $class );

	$a->{artemus} = undef;
	$a->{path} = $args{path};

	return $a;
}


sub _init {
	my $self	= shift;

	my $data = $self->data();

	my %f = ();

	$f{'add'} = sub { $_[0] + $_[1]; };
	$f{'sub'} = sub { $_[0] - $_[1]; };
	$f{'gt'} = sub { $_[0] > $_[1]; };
	$f{'lt'} = sub { $_[0] < $_[1]; };

	$f{topic_part} = sub {
		my $topic_id	= shift;
		my $part	= shift;

		my $t = $data->topic($topic_id);
		return $t->get($part);
	};

	$f{story_part} = sub {
		my $topic_id	= shift;
		my $id		= shift;
		my $part	= shift;

		my $s = $data->story($topic_id, $id);
		return $s->get($part);
	};

	$f{loop_topics} = sub {
		my $template	= shift;
		my $sep		= shift;

		my @s =	map { my ($e, $s) = ($_, $template);
			$s =~ s/&/$e/g; $_ = $s;
			} $data->topics();

		return join($sep, @s);
	};

	$self->{unresolved} = [];

	$self->{artemus} = Artemus->new(
		'include-path'	=>	$self->{path},
		'funcs'		=>	\%f,
		'unresolved'	=>	$self->{unresolved}
	);
}


sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
		$self->_init();
	}

	return $self->{data};
}


sub armor {
	my $self	= shift;
	my $string	= shift;

	return $self->{artemus}->armor($string);
}

sub unarmor {
	my $self	= shift;
	my $string	= shift;

	return $self->{artemus}->unarmor($string);
}

sub process {
	my $self	= shift;
	my $template	= shift;

	return $self->{artemus}->process("{-$template}");
}

1;
