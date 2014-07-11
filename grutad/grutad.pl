#!/usr/bin/perl

my $PROTO_VERSION = '1.0';
my $SERVER_VERSION = '0.0';

use strict;
use warnings;

use File::Temp;

use Gruta;
use Gruta::Source::DBI;
use Gruta::Source::FS;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Renderer::Text;

sub arg
{
	if (@ARGV) {
		return shift(@ARGV);
	}

	usage();
}


sub new_source
{
	my $src_str = shift;
	my $src;

	if ($src_str =~ /^dbi:/) {
		$src = Gruta::Source::DBI->new( string => $src_str );
	}
	else {
		$src = Gruta::Source::FS->new( path => $src_str );
	}

	return $src;
}


sub init
{
	my $src = new_source(arg());
	my $g	= Gruta->new(
		source => $src,
		renderers	=> [
			Gruta::Renderer::Grutatxt->new(),
			Gruta::Renderer::HTML->new(),
			Gruta::Renderer::HTML->new( valid_tags => undef ),
			Gruta::Renderer::Text->new(),
		]
	);

	return $g;
}


sub usage
{
    print "grutad.pl - Grutad server in Perl\n\n";

    print "Usage:\n";
    print "grutad {src}\n\n";

    print "Where {src} is a Gruta source spec. Examples:\n\n";
    print " * /var/www/site_dir/var (FS type)\n";
    print " * dbi:SQLite:/var/www/site_dir/var/gruta.db (Perl DBI type)\n";

    exit 1;
}


sub write_obj
{
    my $c = shift;
    my $h = shift;
    my $e = shift;

    my $o = $c->{o};

    if ($h) {
        print $o "OK Object follows\n";

        foreach my $k (keys(%{$h})) {
            my $v = $h->{$k} || '';

            if (ref(\$v) eq 'SCALAR') {
                $v =~ s/\n/\\n/g;

                print $o $k, "\n";
                print $o $v, "\n";
            }
        }

        print $o ".\n";
    }
    else {
        print $o "ERROR ", $e, "\n";
    }
}


sub write_array
{
    my $c   = shift;
    my @l   = @_;
    my $o   = $c->{o};

    print $o "OK List follows\n";

    foreach my $e (@l) {
        my $t = ref($e);

        if ($t eq 'ARRAY') {
            print $o join(":", @{$e}), "\n";
        }
        else {
            print $o $e, "\n";
        }
    }
    print $o ".\n";
}


sub read_obj
{
    my $c = shift;
    my %h = ();

    my $i = $c->{i};
    my $o = $c->{o};

    print $o "OK Ready to receive object\n";

    while (my $k = <$i>) {
        chomp($k);

        if ($k eq '.') {
            last;
        }

        my $v = <$i> || '';
        chomp($v);
        $v =~ s/\\n/\n/g;

        $h{$k} = $v;
    }

    return %h;
}


sub write_result
{
    my $c = shift;
    my $e = shift;
    my $m = shift || 'Stored';

    my $o = $c->{o};

    if (!$e) {
        print $o "OK $m\n";
    }
    else {
        $e =~ s/\n/\\n/g;
        print $o "ERROR $e\n";
    }
}


sub dialog
{
    my $c = shift;

    my $g = $c->{g};
    my $i = $c->{i};

    for (;;) {
        my $l = <$i>;
        chomp($l);

        if (!$l) {
            last;
        }

        my ($k, @args) = split(/ /, $l);

        if ($k eq 'bye') {
            last;
        }
        elsif ($k eq 'version') {
            write_obj($c, {
                proto_version   => $PROTO_VERSION,
                server_version  => $SERVER_VERSION,
                server_id       => 'grutad.pl'
                }
            );
        }
        elsif ($k eq 'topics') {
            write_array($c, $g->source->topics());
        }
        elsif ($k eq 'users') {
            write_array($c, $g->source->users());
        }
        elsif ($k eq 'tags') {
            write_array($c, $g->source->tags());
        }
        elsif ($k eq 'templates') {
            write_array($c, $g->source->templates());
        }
        elsif ($k eq 'pending_comments') {
            write_array($c, $g->source->pending_comments());
        }
        elsif ($k eq 'comments') {
            write_array($c, $g->source->comments($args[0]));
        }
        elsif ($k eq 'stories') {
            write_array($c, $g->source->stories($args[0]));
        }
        elsif ($k eq 'stories_top_ten') {
            write_array($c, $g->source->stories_top_ten($args[0] || 10));
        }
        elsif ($k eq 'story') {
            my $obj = $g->source->story($args[0], $args[1]);

            write_obj($c, $obj, "Story '$args[0]/$args[1]' not found");
        }
        elsif ($k eq 'topic') {
            my $obj = $g->source->topic($args[0]);

            write_obj($c, $obj, "Topic '$args[0]' not found");
        }
        elsif ($k eq 'user') {
            my $obj = $g->source->user($args[0]);

            write_obj($c, $obj, "User '$args[0]' not found");
        }
        elsif ($k eq 'template') {
            my $obj = $g->source->template($args[0]);

            write_obj($c, $obj, "Template '$args[0]' not found");
        }
        elsif ($k eq 'store_template') {
            my $t = Gruta::Data::Template->new(read_obj($c));

            eval { $g->source->insert_template($t) };

            write_result($c, $@);
        }
        elsif ($k eq 'store_story') {
            my %a = read_obj($c);
            my $o = Gruta::Data::Story->new(%a);

            eval {
                $g->render($o);
                $g->source->insert_story($o);
                $o->tags($a{tags});
            };

            write_result($c, $@, $o->get('id'));
        }
        elsif ($k eq 'story_set') {
            my %a = read_obj($c);

            if ($a{topics}) {
                $a{topics} = [split(/\s*,\s*/, $a{topics})];
            }
            if ($a{tags}) {
                $a{tags} = [split(/\s*,\s*/, $a{tags})];
            }

            my @r;

            eval { @r = $g->source->story_set(%a); };

            if ($@) {
                write_result($c, $@);
            }
            else {
                write_array($c, @r);
            }
        }
        else {
            print "ERROR '$k' command not found\n";
        }
    }
}

my $c = {"g" => init(), "i" => *STDIN, "o" => *STDOUT};

dialog($c);

exit 0;
