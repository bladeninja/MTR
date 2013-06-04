#!/usr/bin/perl
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use Cwd 'abs_path';
use File::Copy;
use File::Type;
use ft_conf;

my @configurations = ();
my $debug=0;
my $simulate=0;
my $recursive=0;
my $inquire=0;
my $prettytabs ="\t";
my @dirsList = ();
my @fileList = ();
my $FT = File::Type->new();

use constant {
	TRUE	=> 1,
	FALSE	=> 0,
	UNKNOWN	=> -1
};

sub isKnownFileType($){
	my ($path) = @_;
	my $filetype = $FT->checktype_filename($path);
	#print "$filetype\n";
	my $count = 0;
	foreach my $mime (@KNOWNMIME){
		return $count
			if ($filetype eq $mime);
		$count++;
	}
	return UNKNOWN
		if ($path =~ m/($KNOWNEXTN)$/);

	return FALSE;
}

sub parseConfigLine($){
	my ($text) = @_;
    my @fields  = ( );

    while ($text =~ m{
		# Either a quoted field: (with '' allowed inside)
		'					# field's opening quote; don't save this
		(					# now a field is either
			(?:     [^'"]	# non-quotes or
				|
				''			# adjacent quote pairs
				|
				::
			) *				# any number
		)
		':					# field's closing quote; unsaved

			# ...or...
			|

		# same as above, but without the :
 		'( (?:     [^'"] | '' | :: ) * )'  

			# ...or...
			| 

		# ...  some non-quote text:
		( [^'":] + ):
    }gx)
    {
      if (defined $1) {
          $field = $1;
      } elsif (defined $2){
          ($field = $2)	=~ s/''/'/g;
          #$field		=~ s/::/:/g;
      } elsif (defined $3){
          $field = $3;
	  }
      push @fields, $field;
    }
    return @fields;
}

sub processConfigFile($){
	my ($filepath) = @_;
	# readonly access
	open FILE, "<", $filepath
	    or die "Could not open file : $!";
	foreach $line (<FILE>){
		chomp($line);
		next if ($line =~ m/^(\s)*#.*/); # ignore comments
		next if ($line =~ m/^(\s)*$/);   # skip blank lines
		my @fields = parseConfigLine($line);
		push @configurations, \@fields;

format STDOUT_TOP =
Where Search                    Replace
------------------------------------------------------------------------------------
.
format STDOUT = 
@<<<< @<<<<<<<<<<<<<<<<<<<<<<<< @*
$fields[0],$fields[1],$fields[2]
.
		write if ($debug);
	}
	print "------------------------------------------------------------------------------------\n"
		if ($debug);
	#print Dumper(@configurations);
}

sub PromptYN($){
	my ($prompt) = @_;
	my $buf = ' ';
	select STDOUT;
	do{
		printf ("$prompt [Y/N]:");
		$|=1;
		sysread STDIN, $buf, 1;
	}while (! ($buf =~ m/[yYnN]+/) );
	return ($buf =~ m/[yY]+/)?1:0;
}

sub processFile($){
	my ($filepath) = @_;
	## check if the filetype is known.
	my $ftype = isKnownFileType($filepath);

	return $ftype if ( $ftype <= 0);
	print "$ftype";

	## done checking
	open FILE, "<", $filepath
		or die "Could not open file : $!";
	print "$prettytabs$filepath";
	my $lineno = 0;
	my @lines = <FILE>;
	my $dirty = 0;
	my @difflines= ();
	foreach $line (@lines){
		++$lineno;
		foreach $fields (@configurations){
			if (@$fields[0] == $lineno or @$fields[0] == '%'){
				my $oldl = $line;
				chomp($oldl);
				if ($line =~ s/@$fields[1]/@$fields[2]/g){
					my $newl = $line;
					chomp($newl);
					push (@difflines,"---$oldl\n+++$newl\n") if($debug or $simulate);
					$lines[$lineno-1] = $line;
					$dirty = 1;
				}
			}
		}
	}
	close(FILE);

	print (($dirty)?'*':'')."\n";
	if ($dirty and ($debug or $simulate)){
		foreach my $line (@difflines){
			print $line;
		}
		print "\n" if (! $inquire);
	}

	if ($dirty and $simulate == 0){
		my $doit = 1;
		($doit = PromptYN ('Do you want to make changes to this file ?')) if ($inquire);
		
		if ($doit){
			#write to file
			open NEWFILE, ">", $filepath.'.tmp'
				or die "Could not open file $filepath.'.tmp' for writing : $!";
			foreach my $line (@lines){
				print NEWFILE $line;
			}
			close (NEWFILE);
			move($filepath.'.tmp',$filepath);
		}
	}
	return $dirty;
}

sub processDir($) {
	my ($dirpath) = @_;
	print "in processDir [$dirpath]\n";

	opendir(DIR,$dirpath)
		or die "Cannot open directory";

	my @dirlist = grep(!/^\./,readdir(DIR));
	foreach $entry (@dirlist)
	{
		if ( -f $dirpath."/".$entry ){
			processFile($dirpath."/".$entry);
		}elsif (-d $dirpath."/".$entry and $recursive){
			## make it recursive from here.
			processDir($dirpath."/".$entry);
		}else{
			## either a directory and not recursive or not a file or directory
			
		}
	}
}

sub dir_file_option() {
	my ($args) = @_;
	if (-d $args->{name}){
		chop ( $args->{name} ) if ( $args->{name} =~ m/\/$/g );
		push (@dirsList,$args->{name});
	}elsif (-f $args->{name}){
		push (@fileList,$args->{name});
	}
}

sub parse_options () {
	my %kvp = ();
	GetOptions ( \%kvp ,
		'all',             # select all filetypes and extensions
		'conf=s',          # configuration file
		'dir=s',           # directory
		'help|?',          # Help
		'inquire',         # inquire for each file
		'man',             # Man
		'recursive',       # step recursively into all directories
		'simulate',        # simulate only, do not make real changes
		'verbose',         # debug the program
		'<>' => \&dir_file_option, # dirpath
	) or pod2usage(2);

	pod2usage(-exitstatus => 0, -verbose => 2) if $kvp{man};
	pod2usage(1) if $kvp{help};
	pod2usage(2) if ! defined $kvp{conf};

	push (@dirsList, $options{'dir'}) if ( defined $options{'dir'} );

	pod2usage(2) if ( $#fileList == 0 and $#dirsList == 0);

	return %kvp;
}


sub main() {
	%options = parse_options();

	$debug = 1 if (defined $options{'verbose'});
	$simulate = 1 if (defined $options{'simulate'});
	$recursive = 1 if (defined $options{'recursive'});
	$inquire = 1 if (defined $options{'inquire'});

	processConfigFile(abs_path($options{'conf'}));

	## process all directories
	foreach my $path (@dirsList){
		my $rpath = abs_path($path);
		processDir($rpath);
	}

	## Process all files
	foreach my $path (@fileList){
		my $rpath = abs_path($path);
		$prettytabs = '';
		processFile($rpath);
	}
}

main;

__END__

=head1 NAME

	mtreplace.pl - Run text replacement on all files in a directory

=head1 SYNOPSIS

  mtreplace.pl [options] [Files/Directories]
    Options:
      -all             selexr all files and directories for operations, does not ignore filetypes
      -conf            <required> configuration file for text replacement
      -dir             top level directory for operation
      -help            brief help message
      -inquire         prompt for any changes to files
      -man             full documentation
      -recursive       operate on all directories recursively
      -simulate        print change statements, but do not effect changes into files
      -verbose         print verbose messages on screen

=head1 OPTIONS

=over 8

=item B<-all>
    Select all files and directories for operations, do not ignore binary and compressed files

=item B<-conf>
    path of the configuration file, script will exit if this argument is not provided

=item B<-dir>
    Directory/Folder to perform listed operations, if no option is provided, the current is used instead

=item B<-help>
    Print a brief help message and exits.

=item B<-inquire>
    script runs in inquire mode, changes are made only on user input. The script prompts the user on every change

=item B<-man>
    Prints the manual page and exits.

=item B<-recursive>
    script runs in recursive mode, changes are made recursively on all sub directories

=item B<-simulate>
    script runs in simulated mode, all changes and filename are printed to screen. But no file changes are made

=item B<-verbose>
    script runs in verbose mode, all changes and filename are printed to screen

=back

=head1 DESCRIPTION

    mtreplace.pl will read the given configuration file and will replace text on all files in this directory. 
	
	All files that have been read will be printed, and files which have been changed will be indicated with a '*' after the filename

	How to run: ~/mtreplace.pl -c ~/replace.conf -h

=head1 CONFIGURATION

    The configuration file is essentially a colon(:) separated file in the format:
	<Where>:<Search>:<Replace>

=head2 Where

    describes to the script where in the file to look for the search string, % represents all lines, and a number indicates that particular line. All line numbers start at 1

=head2 Search

    The absolute string to search for in single-quotes example : '/usr/bin/ls'. You can use regex pattern here.

=head2 Replace

    Replacement string, this string will be replaced when the file is processed

=head3 Sample Configuration

	# comment here
	1:'^#!/bin/ksh -p':'ifelse(OS_NAME,[[[Linux]]],[[[#!/bin/ksh -p]]],[[[#!/usr/bin/ksh -p]]])'
	%:'/usr/bin/cp':'cp'
	
	%:'/usr/bin/mv':'mv'

=head3 Comments in Configuration

    All comments must start with a # and must be in a new line, it cannot be at the end of a configuration line

	empty lines are allowed in file

=cut



