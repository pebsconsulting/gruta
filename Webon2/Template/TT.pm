package Webon2::Template::TT;

use Template;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $t = bless( {}, $class );

	$t->{tt} = Template->new(
		'INCLUDE_PATH'	=>	$args{path},
		'INTERPOLATE'	=>	1,
		'TRIM'		=>	1
	) or die "TT: " . $Template::ERROR;

	return $t;
}


sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
	}

	return $self->{data};
}


#sub link_to_topic { return '{-l|TOPIC|' . $_[1] . '}'; }
#sub link_to_story { return '{-l|STORY|' . $_[1] . '|' . $_[2] . '}'; }
#sub armor { $_[0]->{artemus}->armor($_[1]); }
#sub unarmor { $_[0]->{artemus}->unarmor($_[1]); }

sub _tt_data {
	my $self	= shift;

	my $data = $self->data();
	my %f = ();

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

	$f{user_part} = sub {
		my $user_id	= shift;
		my $part	= shift;

		my $s = $data->user($user_id);
		return $s->get($part);
	};

	$f{user} = sub { return $data->user($_[0]); }

	$f{get} = sub { return $_[0]->get($_[1]); }

	$f{topics} = sub { return $data->topics(); };
	$f{users} = sub { return $data->users(); };
	$f{renderers} = sub { return sort(keys(%{$data->{renderers_h}})); }

	$f{story_loop_by_date} = sub {
		my $topic	= shift;
		my $num		= shift;
		my $offset	= shift;

		return $data->stories_by_date(
			$topic,
			num	=> $num,
			offset	=> $offset
		);
	};

	return \%f;
}


sub process {
	my $self	= shift;
	my $template	= shift;

	my $v = '';

	$self->{tt}->process($template, $self->_tt_data(), \$v)
		or die "TT: " . $Template:ERROR;

	return $v;
}

1;
