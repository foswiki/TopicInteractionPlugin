# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2010 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::TopicInteractionPlugin::UploadForm;

use strict;
use warnings;
use Foswiki::Func ();

###############################################################################
sub handle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $template = Foswiki::Func::readTemplate('uploadform');
  my $success = $params->{success} || '';
  my $error = $params->{error} || '';
  my $options = $params->{options} || 'on';
  my $autostart = $params->{autostart};

  my @metadata = ();
  if ($success) {
    $success =~ s/\n/ /g;
    $success =~ s/"/\\"/g;
    $success = "success: $success";
    push @metadata, $success;
  }
  if ($error) {
    $error =~ s/\n/ /g;
    $error =~ s/"/\\"/g;
    $error = "error: $error";
    push @metadata, $error;
  }

  my $metadata = '';
  if (@metadata) {
    $metadata = "{".join(', ', @metadata)."}";
  }

  my $context = Foswiki::Func::getContext();
  $context->{'TopicInteractionPlugin_options'} = 1 if $options eq 'on';
  $context->{'TopicInteractionPlugin_autostart'} = 1 if defined($autostart) && $autostart eq 'on';
  $context->{'TopicInteractionPlugin_noautostart'} = 1 if defined($autostart) && $autostart eq 'off';

  my $result = Foswiki::Func::expandTemplate('uploadform');
  $result =~ s/%metadata%/$metadata/g;

  undef $context->{'TopicInteractionPlugin_options'};
  undef $context->{'TopicInteractionPlugin_autostart'};
  undef $context->{'TopicInteractionPlugin_noautostart'};

  return $result;
}

1;
