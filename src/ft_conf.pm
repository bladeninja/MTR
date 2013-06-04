use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK=qw(OMIT_DIRS KNOWNEXTN KNOWNMIME);
our @EXPORT=qw(OMIT_DIRS KNOWNEXTN KNOWNMIME);



###################### ALL YOUR CONFIGURATION GOES HERE ######################



our $OMIT_DIRS = 'patchd|editd|deploy';
our $KNOWNEXTN = '\.ksh|\.sh|\.pl';
our @KNOWNMIME = (
					'UNKNOWN',
					'application/x-sh',
					'application/x-ksh',
					'application/x-perl',
					'text/script');



################################ UNTIL HERE ##################################
1;
