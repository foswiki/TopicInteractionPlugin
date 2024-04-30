# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2024 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::WebDAVUrl;

use strict;
use warnings;

use POSIX ();

sub handle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleWEBDAVURL($theTopic, $theWeb)");
  my $url = $Foswiki::cfg{TopicInteractionPlugin}{WebDAVUrl} || 'webdav://$host/dav/$web/$topic/$attachment';

  my $host = Foswiki::Func::getUrlHost();
  $host =~ s/^https?:\/+//;

  my $thisTopic = $params->{topic} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;
  my $encName = urlEncode($info, 'name');

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($hisWeb, $thisTopic);

  $url =~ s/\$host/$host/g;
  $url =~ s/\$web/$thisWeb/g;
  $url =~ s/\$topic/$thisTopic/g;
  $url =~ s/\$attachment/$encName/g;


  my $result = '<a rel="nofollow" href="' . $url . '" ' . 'title="%MAKETEXT{"Edit this attachment" args="<nop>' . $info->{name} . '"}%">' . '%MAKETEXT{"edit"}%</a>';

  return $result;
}

1;

