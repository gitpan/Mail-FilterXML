package Mail::FilterXML;

#(c)2000 Matthew MacKenzie <mattmk@cpan.org>

use strict;
use vars qw($VERSION);
use Mail::Audit;
use XML::Parser;



$VERSION = '0.1';


sub new {
	my $class = shift;
	my %args = @_; my $self = \%args;
	bless($self, $class);
	return $self;
}

## NOTE - 0.1 is the initial port of this script from being a script to being a module.
## I expect to make it a little bit smarter in future releases.

# Setup the filter structures.  Maybe in future versions these could be hidden in the object.

my @recip_ig = ();
my @subj_ig = ();
my %to_lists = ();
my %from_lists = ();
my %conf = ();



sub process {
	my $self = shift;
	my $rulesf = $self->{rules_file};
	$self->{message} = new Mail::Audit();


	# Parse rules from the XML File..

	my $xmlp = new XML::Parser(Handlers => {Start => \&Mail::FilterXML::filtFileStartEl });

	$xmlp->parsefile($self->{rules});
	

	# Run the filters.
	$self->recipIg();
	$self->subjIg();
	$self->fromLists();
	$self->toLists();
	$self->defaultFilter();
}

sub defaultFilter {
	my $self = shift;
	logger("INBOX", "DEFAULT");
	$self->{message}->accept();
}

sub filtFileStartEl {
	my ($p,$el,%att) = @_;
	if ($el =~ /Rule/i) {
		if ($att{type} =~ /from/i) {
			$from_lists{$att{content}} = $att{folder};
		}
		if ($att{type} =~ /to/i) {
                       	$to_lists{$att{content}} = $att{folder};
               	}
		if ($att{type} =~ /subj-ignore/i) {
			push(@subj_ig, $att{content});
               	}
		if ($att{type} =~ /recip-ignore/i) {
                       	push(@recip_ig, $att{content});
               	}
	}
	if ($el =~ /Config/i) {
		foreach my $k (keys %att) {
			$conf{$k} = $att{$k};
		}
	}	
}


sub toLists {
	my $self = shift;
	foreach my $key (keys %to_lists) {
		if ($self->{message}->to() =~ /$key/i or $self->{message}->cc() =~ /$key/i) {
                	$self->logger($to_lists{$key}, "TO-FILTER");
                	$self->{message}->accept("$conf{maildir}/".$to_lists{$key}.$conf{folder_suffix});
        	}
	}

}

sub fromLists {
	my $self = shift;
	foreach my $key (keys %from_lists) {
        	if ($self->{message}->from() =~ /$key/i) {
                	$self->logger($from_lists{$key}, "FROM-FILTER");
			$self->{message}->accept("$conf{maildir}/".$from_lists{$key}.$conf{folder_suffix});
        	}
	}
}

sub recipIg {
	my $self = shift;
	foreach my $r (@recip_ig) {
		if ($self->{message}->to() =~ /$r/ or $self->{message}->cc() =~ /$r/) {
			$self->logger("JUNK", "RECIP-IG");
			$self->{message}->accept($conf{maildir}."/".$conf{junkfolder}.$conf{folder_suffix});
		}
	}

}

sub subjIg {
	my $self = shift;
	foreach my $s (@subj_ig) {
        	if ($self->{message}->subject() =~ /$s/) {
			$self->logger("JUNK", "SUBJ-IG");
                	$self->{message}->accept($conf{maildir}."/".$conf{junkfolder}.$conf{folder_suffix});
        	}
	}
}



sub logger {
	my ($self, $folder, $filter) = @_;
	open(LOG, ">>$conf{logfile}");
	flock(LOG,2);	
	my $from = $self->{message}->from();
	my $subj = $self->{message}->subject();
	
	chomp($from);
	chomp($subj);
	my $time = scalar(localtime());
	print LOG "$time> $from : $subj -> $folder ($filter)\n";
	close(LOG);
}
1;

__END__
=head1 NAME

Mail::FilterXML - Filter email based on a rules file written in XML.

=head1 SYNOPSIS

  use Mail::FilterXML;
  my $filter = new MailFilter(rules => "/home/matt/mail_rules.xml");
  $filter->process();

=head1 DESCRIPTION

This module builds upon Mail::Audit by Simon Cozens.  Mail::Audit is a module for constructing 
filters, Mail::FilterXML is a filter of sorts.  FilterXML is just made up of some logic for 
processing an email message, and is controlled by the contents of a rules file, so if I wanted to
block a particular sender, I could just add an element to my rules file, like:

<Rule type="from" content="microsoft.com" folder="Trash" />

The content attribute can contain perl regexps, such as *\.microsoft\.*$, etceteras.

=head1 FUTURE

I will be adding new "types" of rules, and the ability to reject or altogether ignore messages,
as possible in Mail::Audit.  Any feedback or patches are welcome.

=head1 AUTHOR

Matthew MacKenzie <mattmk@cpan.org>

=head1 COPYRIGHT

(c)2000 Matthew MacKenzie.  You may use/copy this under the same terms as Perl.

=head1 SEE ALSO

perl(1), Mail::Audit

=cut
