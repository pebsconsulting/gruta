#!/usr/bin/perl

#
# gruta - Hierarchical Notepad (+CGI)
#
# Copyright (C) 2001/2003	  Angel Ortega <angel@triptico.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# http://www.triptico.com
#
#

#
# adding a bookmark to Gruta using javascript
# -------------------------------------------
#
# Just add this to your bookmarks (your browser's, not Gruta):
#
# javascript:void(location.href='$URL/gruta.cgi?root=$BOOKMARK&parent=$BOOKMARK&cmd=add&url=' + location.href + '&subject=' + escape(document.title))
#
# Of course, substitute $BOOKMARK with your real Gruta branch for
# storing bookmarks.
# This small code works well in your Netscape or Mozilla's Personal Folder.
# It has not been tested on MS Internet Explorer, but probably also works.
#

use locale;
use POSIX qw (locale_h);

use Grutatxt;

$|++;

$VERSION="0.7.1 (".$Grutatxt::VERSION.")";

# the datafile
$datafile=$ARGV[0];

unless(-r $datafile)
{
	print "Content-type: text/html; charset=ISO-8859-1\n\n";
	print "<h1>Gruta</h1>\n";
	print "<pre>\n";
	print "Usage: gruta.cgi {datafile}\n";
	print "</pre>\n";

	exit(0);
}

# read only flag
$read_only=-w $datafile ? 0 : 1;

# set as root flag
$set_as_root=1;

# collapse/expand buttons flag
$collapse_buttons=1;

# lock timeout
$lock_timeout=15 * 60;

# the name of the root node
$root_name="Gruta";

# show url in element name
$show_url=1;

# raw HTML to be printed as root content, in all pages
$css="";
$header="";
$footer="";

# maximum POST size (0, none)
$max_post_size=0;

# disable admin flag
$disable_admin=0;

# use locking flag
$use_locking=1;

# command line
$cmd_line="";

# textarea size
$textarea_cols = 50;
$textarea_rows = 30;

#############################################################################

$request_uri='';

$grutatxt=new Grutatxt("header-offset" => 1,
		       "class-oddeven" => 0);

# parses CGI parameters
($cgi_params)=cgi_init();

# count of elements shown
$shown_elems=0;

# the lockfile
$lockfile=$datafile . ".lck";
$lockfile=~s/\//_/g;
$lockfile="/tmp/" . $lockfile;

# raw mode flag
$raw_mode=0;

# the database
%data=();

# color toggler
$color_tog=0;

# root element
$root=$cgi_params->{'root'};

# command
my @cmd=split('\0',$cgi_params->{'cmd'});
$cmd=lc(pop(@cmd));

# cgi
$cgi=$ENV{'REQUEST_URI'};
$cgi=~s/\?.*$//;

if($read_only)
{
	$cmd="" if $cmd eq "add" or $cmd eq "move" or $cmd eq "delete" or
	   $cmd eq "askdel" or $cmd eq "change" or $cmd eq "edit" or
	   $cmd eq "new" or $cmd eq "sync" or $cmd eq "store" or $cmd eq "merge";
}

if($disable_admin)
{
	$cmd="" if $cmd eq "admin" or $cmd eq "sync" or
		$cmd eq "store" or $cmd eq "merge";
}

# set date filter
if($cgi_params->{'date-filter'})
{
	if(($date_filter=$cgi_params->{'date-filter'}) eq "today")
	{
		$date_filter=make_date(time());
	}
}
else
{
	$date_filter="";
}


#############################################################################

%data=load_database($datafile);

read_config($data{'CONFIG'}->{'-content'});
$css=$data{'CONFIG.css'}->{'-content'} if $data{'CONFIG.css'};
$header=$data{'CONFIG.header'}->{'-content'} if $data{'CONFIG.header'};
$footer=$data{'CONFIG.footer'}->{'-content'} if $data{'CONFIG.footer'};

if($cmd eq "expand" and $collapse_buttons)
{
	my ($elem);

	if($elem=$data{$cgi_params->{'elem'}})
	{
		$elem->{'flags'}.="x" unless $elem->{'flags'} =~ /x/;
		save_database();
	}
}
elsif($cmd eq "collapse" and $collapse_buttons)
{
	my ($elem);

	if($elem=$data{$cgi_params->{'elem'}})
	{
		$elem->{'flags'} =~ s/x//;
		save_database();
	}
}
elsif($cmd eq "add")
{
	my ($elem);

	$elem={};

	$elem->{'-parent'}=$cgi_params->{'parent'} if $cgi_params->{'parent'};
	$elem->{'-basename'}=$cgi_params->{'basename'} if $cgi_params->{'basename'};
	$elem->{'subject'}=$cgi_params->{'subject'};
	$elem->{'url'}=$cgi_params->{'url'} if $cgi_params->{'url'};
	$elem->{'-content'}=$cgi_params->{'content'};
	$elem->{'owner'}=$ENV{'REMOTE_USER'} if $ENV{'REMOTE_USER'};
	$elem->{'date'}=$cgi_params->{'date'} if $cgi_params->{'date'};
	$elem->{'end-date'}=$cgi_params->{'end-date'} if $cgi_params->{'end-date'};
	$elem->{'repeat'}=$cgi_params->{'repeat'} if $cgi_params->{'repeat'};

	new_elem($elem);
	save_database();
}
elsif($cmd eq "move")
{
	my ($elem);

	if($elem=$data{$cgi_params->{'elem'}})
	{
		change_parent($elem,$cgi_params->{'parent'});
		save_database();
	}
}
elsif($cmd eq "delete")
{
	my ($elem);

	if($elem=$data{$cgi_params->{'elem'}})
	{
		destroy_elem($elem);
		save_database();
	}
}
elsif($cmd eq "change")
{
	my ($elem);

	$elem=$data{$cgi_params->{'elem'}};

	if($elem and $cgi_params->{'lockcode'} eq $elem->{'lock'})
	{
		$elem->{'subject'}=$cgi_params->{'subject'}
			if exists($cgi_params->{'subject'});

		$elem->{'url'}=$cgi_params->{'url'} if exists($cgi_params->{'url'});

		$elem->{'-content'}=$cgi_params->{'content'}
			if exists($cgi_params->{'content'});

		$elem->{'last-modifier'}=$ENV{'REMOTE_USER'} if $ENV{'REMOTE_USER'};
		$elem->{'owner'}=$elem->{'last-modifier'} unless $elem->{'owner'};

		$elem->{'date'}=$cgi_params->{'date'} if $cgi_params->{'date'};
		$elem->{'end-date'}=$cgi_params->{'end-date'} if $cgi_params->{'end-date'};
		$elem->{'repeat'}=$cgi_params->{'repeat'} if $cgi_params->{'repeat'};

		$elem->{'version'}++;
		update_elem($cgi_params->{'elem'},$elem);

		# if parent has changed, move it
		if($elem->{'-parent'} ne $cgi_params->{'parent'})
		{
			change_parent($elem,$cgi_params->{'parent'});
		}

		# now it's not locked
		delete($elem->{'lock'});
		delete($elem->{'locker'});

		save_database();
	}

	$date_filter="";
}
elsif($cmd eq "cancel")
{
	my ($elem);

	$elem=$data{$cgi_params->{'elem'}};

	if($elem and $cgi_params->{'lockcode'} eq $elem->{'lock'})
	{
		# now it's not locked
		delete($elem->{'lock'});
		delete($elem->{'locker'});

		save_database();
	}
}
elsif($cmd eq "raw")
{
	$cmd="";
	$raw_mode=1;
}


if($cmd eq "new" or $cmd eq "edit" or $cmd eq "askdel")
{
	my ($elem);

	$elem={};
	$elem=$data{$cgi_params->{'elem'}} if $cmd ne "new";

	cgi_edit_page($cmd,$elem);
}
elsif($cmd eq "dump")
{
	# dumps raw database
	print "Content-Type: application/octet-stream\n\n";

	if(open FILE, $datafile)
	{
		while(<FILE>) { print; }
		close FILE;
	}
}
elsif($cmd eq "admin")
{
	cgi_admin_page();
}
else
{
	if($cmd eq "store" or $cmd eq "sync" or $cmd eq "merge")
	{
		admin_command($cmd);
	}

	cgi_main_tree();
}

exit(0);


#######################
#      Main Tools
#######################

sub make_date
# builds a gruta date
{
	my ($t)=@_;

	my ($d,$m,$y)=(localtime($t))[3..5];
	return(sprintf("%04d%02d%02d",1900+$y,$m+1,$d));
}


sub test_date_filter
# test if element pass the date filter
{
	my ($elem,$rep)=@_;

	return(1) unless $date_filter;

	# false if end-date has passed
	if($elem->{'end-date'})
	{
		return(0) if $elem->{'end-date'} <= $date_filter;
	}

	$elem->{'repeat'} =~ /(\w)/;

	($rep)=$1;

	print "<!-- repeat mode: '$rep' -->\n";

	if($rep eq "y")
	{
		# year: month+day comparison
		return(1) if substr($elem->{'date'},4,4) eq
			substr($date_filter,4,4);
	}
	elsif($rep eq "m")
	{
		# month: day comparison
		return(1) if substr($elem->{'date'},6,2) eq
			     substr($date_filter,6,2);
	}
	else
	{
		# default: simple date comparison (d, or nothing)

		# if end-date is defined (and has arrived here,
		# so end-date haven't passed), return true

		if($elem->{'end-date'})
		{
			return(1) if $elem->{'date'} <= $date_filter;
		}
		else
		{
			# default: show only if date is the same
			return(1) if $elem->{'date'} == $date_filter;
		}
	}

	return(0);
}


sub load_database
# loads the hierarchical data file
{
	my ($df)=@_;
	my ($name,$content,$elem);
	my ($in_header,$key,$val);
	my (%d);

	%d=();

	open F, $df or return(%d);

	$elem={};
	$content="";
	$name=undef;
	$in_header=0;

	# read the shebang command line
	$cmd_line=<F>;
	chomp($cmd_line);

	while(<F>)
	{
		chomp;

		if($in_header)
		{
			if(/^$/)
			{
				$in_header=0;
			}
			else
			{
				($key,$val)=split(/:\s*/,$_,2);
				$elem->{$key}=$val;
			}
		}
		else
		{
			if(/^\%\%(.*)/)
			{
				my ($tmp)=$1;

				# flushes previous element
				if(defined($name))
				{
					$elem->{'-name'}=$name;
					$elem->{'-content'}=$content;
					if( $name =~ /(.*)\.([^\.]*)/ )
					{
						$elem->{'-parent'}=$1;
						$elem->{'-basename'}=$2;
					}
					else
					{
						$elem->{'-basename'}=$name;
					}

					$d{$name}=$elem;
					$content="";
					$elem={};
				}

				last if $tmp eq "EOF";

				# new element
				$name=$tmp;
				$in_header=1;
			}
			else
			{
				if($content)
				{
					$content=$content . "\n" . $_;
				}
				else
				{
					$content=$_;
				}
			}
		}
	}

	close F;

	return(%d);
}


sub save_database
# saves the hierarchical datafile
{
	my ($elem);

	for(;;)
	{
		my ($pid);

		last unless open L, $lockfile;

		$pid=<L>; chop($pid); close L;

		last unless kill 0, $pid;

		sleep 1;
	}

	# lock
	open L, ">$lockfile";
	print L "$$\n";
	close L;

	# open datafile
	open F, ">$datafile" or return(0);

	# print the shebang command line
	print F "$cmd_line\n";

	foreach my $i (sort(keys(%data)))
	{
		$elem=$data{$i};

		# saves the id
		print F "\n%%$i\n";

		# saves the header
		foreach my $k (sort(keys(%$elem)))
		{
			next if $k =~ /^-/;

			$elem->{$k} =~ s/\"/\'/g;

			print F "$k: $elem->{$k}\n" if $elem->{$k};
		}

		print F "\n";

		$elem->{'-content'} =~ s/\r//g;
		$elem->{'-content'} =~ s/\n$//;
		$elem->{'-content'} =~ s/\n\n\n/\n\n/g;

		# saves the content
		print F "$elem->{'-content'}\n" if $elem->{'-content'} ne "";
	}

	# final mark
	print F "%%EOF\n";

	close F;

	unlink $lockfile;
}


sub update_elem
# updates the element
{
	my ($name,$elem)=@_;

	$elem->{'mtime'}=localtime;

	# create a date, if none defined
	$elem->{'date'}=make_date(time()) unless($elem->{'date'});

	$data{$name}=$elem;
}


sub new_elem
# creates a new element
{
	my ($elem)=@_;
	my ($parent);

	# reject if has a parent and does not exist
	if(defined($elem->{'-parent'}))
	{
		$parent=$data{$elem->{'-parent'}} or return(0);
	}

	# if it has no name, we must provide one
	unless(defined($elem->{'-basename'}))
	{
		$elem->{'-basename'}="00001";
		for(;;)
		{
			if($elem->{'-parent'})
			{
				last unless $data{$elem->{'-parent'} . "."
				. $elem->{'-basename'}};
			}
			else
			{
				last unless $data{$elem->{'-basename'}};
			}

			$elem->{'-basename'}=
				sprintf("%05d",$elem->{'-basename'}+1);
		}
	}

	# compose a name
	if(defined($parent))
	{
		$elem->{'-name'}=$elem->{'-parent'} .
			"." . $elem->{'-basename'};
	}
	else
	{
		$elem->{'-name'}=$elem->{'-basename'};
	}

	# reject if already exists
	return(0) if exists($data{$elem->{'-name'}});

	# updates
	$elem->{'version'}=1;
	update_elem($elem->{'-name'},$elem);

	return(1);
}


sub destroy_elem
# destroys an element
{
	my ($elem)=@_;

	delete $data{$elem->{'-name'}};
}


sub seek_by_field
# locates an element by a field
{
	my ($key,$val)=@_;
	my ($elem);

	foreach my $i (sort(keys(%data)))
	{
		$elem=$data{$i};

		return($elem) if($elem->{$key} eq $val);
	}

	return(undef);
}


sub change_parent
# changes an element' parent and returns new name
{
	my ($elem,$new_parent)=@_;
	my ($old_name,$new_name);

	# deletes previous from database
	destroy_elem($elem);

	$old_name=$elem->{'-name'};

	delete($elem->{'-name'});
	delete($elem->{'-basename'});
	$elem->{'-parent'}=$new_parent;

	# creates a new element
	new_elem($elem);

	$new_name=$elem->{'-name'};

	# searchs recursively the database, changing
	# all children of this elem
	foreach my $i (sort(keys(%data)))
	{
		$elem=$data{$i};

		change_parent($elem,$new_name)
			if($elem->{'-parent'} eq $old_name);
	}
}


#
# CGI startup
#

sub cgi_init
{
	my ($q);

	use CGI qw(Vars);

	$q=Vars();
	return($q);
}


sub cgi_init_old
{
	my ($class)=@_;
	my (%cgi,%params);
	my ($f,$p,$key,$val);

	$cgi{'script-name'}=$ENV{'SCRIPT_NAME'};
	$cgi{'request-method'}=$ENV{'REQUEST_METHOD'};
	$cgi{'content-type'}=$ENV{'CONTENT_TYPE'};

	if($cgi{'request-method'} eq "GET")
	{
		$f=$ENV{'QUERY_STRING'};
	}
	else
	{
		# POST

		if($cgi{'content-type'} =~ /multipart\/form-data/)
		{
			my ($boundary,$in_header);

			if($cgi{'content-type'} =~ /boundary=([^\s]*)/)
			{
				$boundary=$1;
			}

			($key,$val)=(undef,undef);
			$in_header=0;

			while(<STDIN>)
			{
				chomp;
				s/\r$//;

				if($in_header)
				{
					if($_ eq "")
					{
						$in_header=0;
					}
					elsif(/name=\"([^\"]*)\"/)
					{
						$key=$1;
					}
				}
				else
				{
					if(/$boundary/)
					{
						$params{$key}=$val if $key;
						($key,$val)=(undef,undef);
						$in_header=1;
					}
					else
					{
						if(defined($val))
						{
							$val.="\n".$_;
						}
						else
						{
							$val=$_;
						}
					}
				}
			}
		}
		else
		{
			# test POST size limitation, if any
#			 bang("Too big query (max: $max_post_size)")
#				 if $max_post_size and
#				    $ENV{'CONTENT_LENGTH'} > $max_post_size;

			# application/x-www-url-encoded
			read(STDIN,$f,$ENV{'CONTENT_LENGTH'});
		}
	}

	foreach $p (split('&', $f))
	{
		if($p =~ /(.*)=(.*)/)
		{
			($key,$val)=($1,$2);

			$val =~ s/\+/ /g;
			$val =~ s/%(..)/pack('c',hex($1))/eg;

			$params{$key}=$val;
		}
	}

	$cgi{'params'}=\%params;
	$cgi{'cookie'}=$ENV{'HTTP_COOKIE'};

	return(\%params, \%cgi);
}


sub cgi_header
{
	my ($elem,$t);

	print "Content-type: text/html; charset=ISO-8859-1\n";
	print "X-Powered-By: Gruta $VERSION\n\n";

	print "<!-- Gruta $VERSION - Angel Ortega <angel\@triptico.com> -->\n\n";
	print "<!-- GATEWAY_INTERFACE: $ENV{'GATEWAY_INTERFACE'} -->\n";
	print "<!-- cmd: '$cmd' -->\n";
	print "<html><head><title>$root_name</title>\n";
	print "$css\n" if $css;
	print "<body bgcolor=white text=black>\n";

	# prints title
	print "<!-- title -->\n";

	if($root)
	{
		$elem=$data{$root};
		$t=$elem->{'subject'};
	}
	else
	{
		$t=$root_name;
	}

	$t.=" (".$date_filter.")" if $date_filter;

	if($raw_mode)
	{
		print "$t\n<br>\n";
		print "=" x length($t);
		print "\n<br>\n";
	}
	else
	{
		print "<table width=100%><tr><td class=title>";
		print "<h1>$t</h1>\n";
		print "</table>\n";
	}

	print "<br>\n";
}


sub cgi_main_content
# shows and element's contents
{
	my ($elem)=@_;

	if($elem->{'-content'} or $elem->{'url'})
	{
		my (@g);

		print "<blockquote>\n";

		@g=$grutatxt->process($elem->{'-content'});

		foreach my $l (@g)
		{
			print "$l\n";
		}

		print "</blockquote>\n";
	}
}


sub cgi_main_subtree
# shows a branch of the tree
{
	my ($r,$level)=@_;

	foreach my $i (sort(keys(%data)))
	{
		my ($elem,$n,$base,$class);

		$elem=$data{$i};

		next if $elem->{'-parent'} ne $r;

		next if $i eq "CONFIG" and $r ne $i;

		# filter by user
		if($cgi_params->{'user'})
		{
			next if $cgi_params->{'user'} ne $elem->{'owner'};
		}

		# filter by date
		next unless test_date_filter($elem);

		$shown_elems++;

		print "<a name='$i'></a>\n";

		$color_tog=not $color_tog;
		$class=$color_tog ? "odd" : "even";

		print "<tr class=$class valign=top><td class=$class width='80\%'>\n"
			unless $raw_mode;

		print "<table width='100\%'><tr valign=top><td>\n";

		print "<p>";
		if($level)
		{
			print "<code>\&nbsp;\&nbsp;\&nbsp;</code>" x $level;
		}

		if(not $raw_mode and $collapse_buttons)
		{
			# prints expand/collapse button
			if($elem->{'flags'} =~ /x/)
			{
				# is expanded: collapse
				print "<a href='$cgi?root=$root&elem=$i&cmd=collapse'>[-]</a> ";
			}
			else
			{
				# is collapsed: expand
				print "<a href='$cgi?root=$root&elem=$i&cmd=expand'>[+]</a> ";
			}
		}

		# prints subject with optional url
		if($elem->{'url'} and !$raw_mode)
		{
			print "<a href='$elem->{'url'}'>$elem->{'subject'}</a>";
			print " - <code class=url>$elem->{'url'}</code>" if $show_url;
		}
		else
		{
			print "$elem->{'subject'}";
		}

		if($raw_mode)
		{
			print "\n<br>\n";
			print "<code>\&nbsp;\&nbsp;\&nbsp;</code>" x $level if $level;
			print "-" x length($elem->{'subject'});
			print "\n<br>\n";
		}

		cgi_main_content($elem) if $elem->{'flags'} =~ /x/;

		print "\n";

		unless($raw_mode)
		{
			print "</td><td>";
			print "<p align=right><small>";

			if($set_as_root)
			{
				print "<a href='$cgi?root=$i'>Set&nbsp;as&nbsp;root</a>";
			}

			# toolbox, with links
			unless($read_only)
			{
				print "\&nbsp;| <a href='$cgi?cmd=new&root=$i'>New</a>\&nbsp;|\&nbsp;";

				if(time() - $elem->{'lock'} < $lock_timeout)
				{
					printf "<em>Locked for edition%s</em>",
						$elem->{'locker'} ? " by $elem->{'locker'}" : "";
				}
				else
				{
					print "<a href='$cgi?cmd=edit&elem=$i&root=$root'>Edit</a>\&nbsp;|\&nbsp;";
					print "<a href='$cgi?cmd=askdel&elem=$i&root=$root'>Del</a>";
				}
			}
			print "</small>\n";
		}

		print "</table>\n";

		# if expanded, travel deeper
		cgi_main_subtree($i,$level+1) if $elem->{'flags'} =~ /x/;
	}

}


sub cgi_main_tree
# shows the database as a tree
{
	my ($elem);

	cgi_header();

	print "$header\n<p>\n" if $header;

	unless($raw_mode)
	{
		# prints path
		print "<!-- path -->\n";
		print "<div class=path>\n";
		if($root)
		{
			my ($t);

			$t="";
			print "<a href='$cgi?root='>$root_name</a>" ;
			foreach my $i (split(/\./,$root))
			{
				$t= $t? $t.=".".$i : $i;

				$elem=$data{$t};

				if($t eq $root)
				{
					print " / $elem->{'subject'}";
				}
				else
				{
					print " / <a href='$cgi?root=$t'>$elem->{'subject'}</a>";
				}
			}
		}
		print "</div>\n";
	}

	print "<p><!-- root content -->\n";

	cgi_main_content($data{$root});

	# prints tree
	print "<!-- tree -->\n";
	print "<table class=oddeven width=100\% border=2>\n" unless $raw_mode;

	cgi_main_subtree($root,0);

	print "</table>\n" unless $raw_mode;
	print "<p>\n";

	print "<!-- elements shown: $shown_elems -->\n";
	print "<p>Total: $shown_elems\n" if $date_filter;

	# foot toolbox

	unless($raw_mode)
	{
		print "<!-- foot toolbox -->\n";
		print "<div class=foottoolbox>\n";
		print "<table width=100\%><tr><td align=left>";
		print "<a href='$cgi?cmd=edit&elem=$root&root=$root'>[Edit]</a> "
			if $root;
		print "<a href='$cgi?cmd=new&root=$root'>[New]</a> "
			unless $read_only;
		print "<a href='$cgi?root=CONFIG'>[Config]</a> "
			unless $read_only;
		print "<a href='$cgi?root=$root'>[Refresh]</a>\n";

		print "</td><td align=right>Gruta $VERSION</table>\n";
		print "</div>\n";
	}

	print "<!-- root footer content -->\n";

	print $footer;
}


sub cgi_edit_page
{
	my ($cmd,$elem)=@_;

	cgi_header();

	if($cmd eq "askdel" or $cmd eq "edit")
	{
		# abort if locked
		if(time() - $elem->{'lock'} < $lock_timeout)
		{
			print "<center><h2>Element locked</h2></center>\n";
			return;
		}
	}

	print "<!-- form -->\n";
	print "<form action=\"$cgi\" method=post>\n";

	printf "<input type=hidden name=cmd value=%s>\n",
		($cmd eq "edit" ? "change" : ($cmd eq "askdel" ? "delete" : "add"));

	print "<input type=hidden name=elem value=$cgi_params->{'elem'}>\n"
		if $cmd ne "new";

	print "<input type=hidden name=root value=$root>\n";

	printf "<center><h2>%s Element</h2>",
		($cmd eq "edit" ? "Edit" : ($cmd eq "askdel" ? "Delete" : "New"));

	printf "<input type=submit value='%s'>",
		$cmd eq "askdel" ? "Confirm Deletion" : "Save Changes";
	print "&nbsp;<input type=submit name=cmd value='Cancel'><p>\n";

	print "<table class=oddeven>\n";

	# subject
	print "<tr valign=top><td class=odd align=right>Subject";
	print "<td class=odd>";
	print "<input type=text size=50 maxlength=120 name=subject value=\"$elem->{'subject'}\">\n";

	# url
	print "<tr valign=top><td class=odd align=right>URL";
	print "<br><small>Optional</small><br>";
	print "<td class=odd>";
	print "<input type=text size=50 name=url value='$elem->{'url'}'>\n";

	# parent
	$elem->{'-parent'}=$root if $cmd eq "new";
	print "<tr valign=top><td class=odd align=right>Parent Node<br>";
	print "<td class=odd>";
	print "<select name=parent size=10>\n";
	printf "<option %s value=''>$root_name\n",
		$elem->{'-parent'} eq '' ? "selected" : "";

	foreach my $i (sort(keys(%data)))
	{
		my ($e,$p);

		$e=$data{$i};

		# create an indentation from $i
		$p=$i; $p =~ s/[^\.]//g; $p =~ s/\./\&nbsp;\&nbsp;\&nbsp;\&nbsp;/g;

		if($i =~ /^$root/)
		{
			printf "<option %s value=$i>$p$e->{'subject'}\n",
			$elem->{'-parent'} eq $i ? "selected" : ""
			if $i ne $cgi_params->{'elem'};
		}
	}

	print "</select>\n";

	# basename
	if($cmd eq "new")
	{
		print "<tr valign=top><td class=odd align=right>Internal Name";
		print "<br><small>Optional<br>Only letters allowed<br>If empty, a unique,<br>sequential number<br>will be used</small>";
		print "<td class=odd>";
		print "<input type=text size=16 name=basename value='$elem->{'-basename'}'>\n";
	}

	# content
	print "<tr valign=top><td class=odd align=right>Content<br>";
	print "<td class=odd>";
	print "<textarea name=content cols=$textarea_cols rows=$textarea_rows wrap=virtual>";
	print "$elem->{'-content'}";
	print "</textarea>\n";

	# datebook info
	print "<tr valign=top><td class=odd align=right>DateBook info<br>";
	print "<small>Only for entries to be<br>used as datebook entries</small>";
	print "<td class=odd>";
	print "Date: <input type=text maxlength=8 size=8 name=date value='$elem->{'date'}'><br>\n";
	print "End Date (empty if no end date): <input type=text maxlength=8 size=8 name=end-date value='$elem->{'end-date'}'><br>\n";
	print "Repeat period: ";
	print "<select name=repeat size=1>\n";
	printf "<option %s value=y>Yearly\n", $elem->{'repeat'} eq "y" ? "selected"  : "";
	printf "<option %s value=m>Monthly\n", $elem->{'repeat'} eq "m" ? "selected" : "";
	printf "<option %s value=''>Daily or None\n", $elem->{'repeat'} eq "" ? "selected" : "";
	print "</select>\n";

	# misc info
	print "<tr valign=top><td class=odd align=right>Misc. info\n";
	print "<td class=odd>Version: $elem->{'version'}<br>\n";
	print "Last modification time: $elem->{'mtime'}\n";

	print "</table>\n";

	printf "<br><input type=submit value='%s'>",
		$cmd eq "askdel" ? "Confirm Deletion" : "Save Changes";
	print "&nbsp;<input type=submit name=cmd value='Cancel'><p>\n";

	# if editing, locks the requested element to edit
	if($cmd ne "new" and $use_locking)
	{
		$elem->{'lock'}=time();
		$elem->{'locker'}=$ENV{'REMOTE_USER'} if $ENV{'REMOTE_USER'};

		print "<input type=hidden name=lockcode value=$elem->{'lock'}>\n";

		update_elem($cgi_params->{'elem'},$elem);
		save_database();
	}

	print "</form>\n";
}


sub cgi_admin_page
{
	cgi_header();

	print "<center><h2>Gruta External Maintenance</h2>\n";

	print "<!-- form -->\n";
	print "<form action=$cgi method=post ";
	print "enctype=multipart/form-data>\n";

	print "<input type=submit value='Send'><br><br>";

	print "<table class=oddeven border=2>\n";

	# file
	print "<tr valign=top><td class=odd align=right>Local file name";
	print "<td class=odd>";
	print "<input type=file name=file size=30>\n";

	# operation
	print "<tr valign=top><td class=even align=right>Operation";
	print "<td class=even>";
	print "<input type=radio name=cmd value=store>\n";
	print " <strong class=strong>Store</strong> - ";
	print "Overwrite all data on server, deleting entries not in file<br>\n";
	print "<input type=radio name=cmd value=sync checked>\n";
	print " <strong class=strong>Sync</strong> - ";
	print "Update and keep the latest entries<br>\n";
	print "<input type=radio name=cmd value=merge>\n";
	print " <strong class=strong>Merge</strong> - ";
	print "Store file on server, keeping entries not in file<br>\n";
	print "<input type=radio name=cmd value=dump>\n";
	print " <strong class=strong>Dump</strong> - ";
	print "Dumps current database<br>\n";

	print "</table>\n";

	print "</form>\n";

	print "</center>\n";
}


sub admin_command
{
	my ($cmd)=@_;
	my ($tmp,%ot);
	my ($cgi,$file);

	# dumps the file
	$tmp="/tmp/gruta".time();

	open O, ">$tmp" or return;

	$cgi=new CGI;
	$file=$cgi->param('file');

	while(<$file>)
	{
		print O $_;
	}

	close O;

	# loads it
	%ot=load_database($tmp);

	unlink $tmp;

	if($cmd eq "store")
	{
		%data=%ot;
		save_database();
	}
	elsif($cmd eq "sync")
	{
		# synchronization: all elements with a newer version
		# in %ot enters into %data
		foreach my $i (sort(keys(%ot)))
		{
			my ($elemd,$elemo);

			$elemd=$data{$i};
			$elemo=$ot{$i};

			if($elemd->{'version'} < $elemo->{'version'})
			{
				$data{$i}=$elemo;
			}
		}
		save_database();
	}
	elsif($cmd eq "merge")
	{
		# merging: all elements in %ot goes into %data,
		# overwriting the existing, but preserving the others
		foreach my $i (sort(keys(%ot)))
		{
			$data{$i}=$ot{$i};
		}
		save_database();
	}
}


###########################################################################

sub bang
# bangs an error
{
	my ($error)=@_;

	cgi_header();

	print "<center><h2>Fatal error: $error</h2></center>\n";

	exit(0);
}


sub read_config
# reads the config file
{
	my ($conf)=@_;

	foreach (split("\n",$conf))
	{
		next if /^#/;
		next if /^$/;

		my ($key,$value)=/^(\w*):\s+(.*)/;

		if($value =~ /<<EOF$/)
		{
			# read lines until a file containing ^EOF$
			$value="";
			while(<F>)
			{
				last if /^EOF$/;
				$value.=$_;
			}
		}

		if($key eq "disable_admin")
		{
			$disable_admin=$value;
		}
		elsif($key eq "use_locking")
		{
			$use_locking=$value;
		}
		elsif($key eq "set_as_root")
		{
			$set_as_root=$value;
		}
		elsif($key eq "root_name")
		{
			$root_name=$value;
		}
		elsif($key eq "show_url")
		{
			$show_url=$value;
		}
		elsif($key eq "lock_timeout")
		{
			$lock_timeout=$value;
		}
		elsif($key eq "max_post_size")
		{
			$max_post_size=$value;
		}
		elsif($key eq "collapse_buttons")
		{
			$collapse_buttons=$value;
		}
		elsif($key eq "locale")
		{
			setlocale(LC_ALL, $value);
		}
		elsif($key eq "textarea_cols")
		{
			$textarea_cols=$value;
		}
		elsif($key eq "textarea_rows")
		{
			$textarea_rows=$value;
		}
	}
}
