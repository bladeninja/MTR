#!/usr/bin/perl
use Module::Build;

use strict;

Module::Build->new(
  PL_files => 'mtreplace',
  license     => 'perl',
  requires => {
    'File::Type'  => 0.22
  },
  create_makefile_pl => 'traditional',
)->create_build_script;

